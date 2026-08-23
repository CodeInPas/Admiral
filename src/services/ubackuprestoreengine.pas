unit uBackupRestoreEngine;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils, SyncObjs, DB,
  ZConnection, ZDataset,
  uAppTypes, uDBTypes, uModelConnection, uDBDriverBase, uDBConnectionFactory,
  uModelSchemaObject;

type
  { Mode Operasi }
  TBackupRestoreMode = (brmBackup, brmRestore);

  { Opsi Cadangan (Backup) }
  TBackupOptions = record
    IncludeStructure: Boolean;
    IncludeData: Boolean;
    AddDropTable: Boolean;
    InsertBatchSize: Integer;
    FilePath: string;
  end;

  { Opsi Pemulihan (Restore) }
  TRestoreOptions = record
    ContinueOnError: Boolean;
    UseTransaction: Boolean;
    FilePath: string;
  end;

  { Event Progress & Selesai }
  TBREngineProgressEvent = procedure(
    Sender: TObject;
    const ACurrentTask: string;
    const AItemIndex, ATotalItems: Integer;
    const AProgressPercentage: Integer;
    const ADetailMessage: string
  ) of object;

  TBREngineCompleteEvent = procedure(
    Sender: TObject;
    const ASuccess: Boolean;
    const ATotalLinesOrRows: Int64;
    const AElapsedMS: Int64;
    const AErrorMessage: string
  ) of object;

  { Thread Eksekusi Backup & Restore }
  TBackupRestoreWorkerThread = class(TThread)
  private
    FProfile: TConnectionProfile;
    FDatabaseName: string;
    FMode: TBackupRestoreMode;
    FBackupOpts: TBackupOptions;
    FRestoreOpts: TRestoreOptions;
    FSelectedTables: TStringList;

    // State Progress
    FCurrentTask: string;
    FItemIndex: Integer;
    FTotalItems: Integer;
    FProgressPct: Integer;
    FDetailMsg: string;
    FTotalProcessed: Int64;

    FSuccess: Boolean;
    FErrorMessage: string;
    FElapsedMS: Int64;

    FOnProgress: TBREngineProgressEvent;
    FOnComplete: TBREngineCompleteEvent;

    procedure DoSyncProgress;
    procedure DoSyncComplete;
    function QuoteIdent(const AName: string; const ADriver: TDBDriverType): string;
    function FormatSQLValue(const AField: TField; const ADriver: TDBDriverType): string;
    function GenerateTableDDL(ADriver: TDBDriverBase; const ATableName: string): string;
    procedure ExecuteBackup(AConn: TZConnection; ADriver: TDBDriverBase);
    procedure ExecuteRestore(AConn: TZConnection);
  protected
    procedure Execute; override;
  public
    constructor CreateBackup(
      AProfile: TConnectionProfile;
      const ADBName: string;
      ATables: TStrings;
      const AOptions: TBackupOptions;
      AOnProg: TBREngineProgressEvent;
      AOnComp: TBREngineCompleteEvent
    );
    constructor CreateRestore(
      AProfile: TConnectionProfile;
      const ADBName: string;
      const AOptions: TRestoreOptions;
      AOnProg: TBREngineProgressEvent;
      AOnComp: TBREngineCompleteEvent
    );
    destructor Destroy; override;
    procedure CancelOperation;
  end;

implementation

{ TBackupRestoreWorkerThread }

constructor TBackupRestoreWorkerThread.CreateBackup(
  AProfile: TConnectionProfile;
  const ADBName: string;
  ATables: TStrings;
  const AOptions: TBackupOptions;
  AOnProg: TBREngineProgressEvent;
  AOnComp: TBREngineCompleteEvent
);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FMode := brmBackup;

  FProfile := TConnectionProfile.Create;
  FProfile.Assign(AProfile);
  FDatabaseName := ADBName;

  FSelectedTables := TStringList.Create;
  if Assigned(ATables) then
    FSelectedTables.Assign(ATables);

  FBackupOpts := AOptions;
  FOnProgress := AOnProg;
  FOnComplete := AOnComp;
end;

constructor TBackupRestoreWorkerThread.CreateRestore(
  AProfile: TConnectionProfile;
  const ADBName: string;
  const AOptions: TRestoreOptions;
  AOnProg: TBREngineProgressEvent;
  AOnComp: TBREngineCompleteEvent
);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FMode := brmRestore;

  FProfile := TConnectionProfile.Create;
  FProfile.Assign(AProfile);
  FDatabaseName := ADBName;

  FSelectedTables := TStringList.Create;
  FRestoreOpts := AOptions;
  FOnProgress := AOnProg;
  FOnComplete := AOnComp;
end;

destructor TBackupRestoreWorkerThread.Destroy;
begin
  FSelectedTables.Free;
  FProfile.Free;
  inherited Destroy;
end;

procedure TBackupRestoreWorkerThread.CancelOperation;
begin
  FOnProgress := nil;
  Terminate;
end;

procedure TBackupRestoreWorkerThread.DoSyncProgress;
begin
  if not Terminated and Assigned(FOnProgress) then
    FOnProgress(Self, FCurrentTask, FItemIndex, FTotalItems, FProgressPct, FDetailMsg);
end;

procedure TBackupRestoreWorkerThread.DoSyncComplete;
begin
  if Assigned(FOnComplete) then
    FOnComplete(Self, FSuccess, FTotalProcessed, FElapsedMS, FErrorMessage);
end;

function TBackupRestoreWorkerThread.QuoteIdent(const AName: string; const ADriver: TDBDriverType): string;
begin
  case ADriver of
    dtMySQL, dtMariaDB: Result := '`' + AName + '`';
    else Result := '"' + AName + '"';
  end;
end;

function TBackupRestoreWorkerThread.FormatSQLValue(const AField: TField; const ADriver: TDBDriverType): string;
var
  S: string;
begin
  if AField.IsNull then
    Exit('NULL');

  case AField.DataType of
    ftSmallint, ftInteger, ftWord, ftLargeint, ftAutoInc:
      Result := AField.AsString;

    ftFloat, ftCurrency, ftBCD, ftFMTBcd:
      Result := StringReplace(AField.AsString, ',', '.', [rfReplaceAll]);

    ftBoolean:
    begin
      if ADriver in [dtMySQL, dtMariaDB, dtSQLite] then
      begin
        if AField.AsBoolean then Result := '1' else Result := '0';
      end
      else
      begin
        if AField.AsBoolean then Result := 'TRUE' else Result := 'FALSE';
      end;
    end;

    ftDate:
      Result := Format('''%s''', [FormatDateTime('yyyy-mm-dd', AField.AsDateTime)]);

    ftDateTime, ftTimeStamp:
      Result := Format('''%s''', [FormatDateTime('yyyy-mm-dd hh:nn:ss', AField.AsDateTime)]);

    ftTime:
      Result := Format('''%s''', [FormatDateTime('hh:nn:ss', AField.AsDateTime)]);

    else
    begin
      S := AField.AsString;
      S := StringReplace(S, '''', '''''', [rfReplaceAll]);
      Result := '''' + S + '''';
    end;
  end;
end;

function TBackupRestoreWorkerThread.GenerateTableDDL(ADriver: TDBDriverBase; const ATableName: string): string;
var
  Cols: TSchemaColumnList;
  I: Integer;
  ColDef, PKs: string;
begin
  Cols := TSchemaColumnList.Create(True);
  try
    ADriver.ExtractColumns(FDatabaseName, '', ATableName, Cols);
    Result := Format('CREATE TABLE %s (' + LineEnding, [QuoteIdent(ATableName, FProfile.DriverType)]);
    PKs := '';

    for I := 0 to Cols.Count - 1 do
    begin
      ColDef := '  ' + QuoteIdent(Cols[I].Name, FProfile.DriverType) + ' ' + Cols[I].DataType;
      if Cols[I].Length > 0 then
        ColDef := ColDef + Format('(%d)', [Cols[I].Length]);

      if not Cols[I].IsNullable then
        ColDef := ColDef + ' NOT NULL';

      if Cols[I].IsPrimaryKey then
      begin
        if PKs <> '' then PKs := PKs + ', ';
        PKs := PKs + QuoteIdent(Cols[I].Name, FProfile.DriverType);
      end;

      if I < Cols.Count - 1 then
        ColDef := ColDef + ',';

      Result := Result + ColDef + LineEnding;
    end;

    if PKs <> '' then
      Result := Result + Format(',  PRIMARY KEY (%s)' + LineEnding, [PKs]);

    Result := Result + ');';
  finally
    Cols.Free;
  end;
end;

procedure TBackupRestoreWorkerThread.ExecuteBackup(AConn: TZConnection; ADriver: TDBDriverBase);
var
  OutStream: TFileStream;
  TblIdx, ColIdx, BatchCounter: Integer;
  TableName, DDL, ColList, ValList, InsertSQL: string;
  Qry: TZQuery;
  Cols: TSchemaColumnList;
  TotalRowsInTbl, CurrentRow: Int64;

  procedure WriteStr(const S: string);
  var
    Buffer: UTF8String;
  begin
    Buffer := S + LineEnding;
    if Length(Buffer) > 0 then
      OutStream.WriteBuffer(Buffer[1], Length(Buffer));
  end;

begin
  OutStream := TFileStream.Create(FBackupOpts.FilePath, fmCreate or fmShareDenyWrite);
  Cols := TSchemaColumnList.Create(True);
  Qry := TZQuery.Create(nil);
  Qry.Connection := AConn;
  try
    // Header File Dump
    WriteStr('-- ===================================================');
    WriteStr('-- SiAdmin SQL Database Dump');
    WriteStr(Format('-- Target Database : %s', [FDatabaseName]));
    WriteStr(Format('-- DBMS Engine     : %s', [FProfile.GetDisplayName]));
    WriteStr(Format('-- Generated at    : %s', [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)]));
    WriteStr('-- ===================================================');
    WriteStr('');

    FTotalItems := FSelectedTables.Count;
    FTotalProcessed := 0;

    for TblIdx := 0 to FSelectedTables.Count - 1 do
    begin
      if Terminated then Break;

      TableName := FSelectedTables[TblIdx];
      FCurrentTask := Format('Memproses tabel: %s', [TableName]);
      FItemIndex := TblIdx + 1;
      FProgressPct := Round(((TblIdx) / FTotalItems) * 100);
      FDetailMsg := 'Membaca metadata struktur...';
      Synchronize(@DoSyncProgress);

      WriteStr('-- --------------------------------------------------');
      WriteStr(Format('-- Table structure and data for `%s`', [TableName]));
      WriteStr('-- --------------------------------------------------');

      // 1. Ekspor Struktur DDL
      if FBackupOpts.IncludeStructure then
      begin
        if FBackupOpts.AddDropTable then
          WriteStr(Format('DROP TABLE IF EXISTS %s;', [QuoteIdent(TableName, FProfile.DriverType)]));

        DDL := GenerateTableDDL(ADriver, TableName);
        if Trim(DDL) <> '' then
        begin
          WriteStr(Trim(DDL));
          WriteStr('');
        end;
      end;

      // 2. Ekspor Baris Data
      if FBackupOpts.IncludeData then
      begin
        Cols.Clear;
        ADriver.ExtractColumns(FDatabaseName, '', TableName, Cols);

        ColList := '';
        for ColIdx := 0 to Cols.Count - 1 do
        begin
          if ColIdx > 0 then ColList := ColList + ', ';
          ColList := ColList + QuoteIdent(Cols[ColIdx].Name, FProfile.DriverType);
        end;

        Qry.SQL.Text := Format('SELECT * FROM %s;', [QuoteIdent(TableName, FProfile.DriverType)]);
        Qry.Open;

        TotalRowsInTbl := Qry.RecordCount;
        CurrentRow := 0;
        BatchCounter := 0;

        while not Qry.EOF do
        begin
          if Terminated then Break;

          ValList := '';
          for ColIdx := 0 to Qry.FieldCount - 1 do
          begin
            if ColIdx > 0 then ValList := ValList + ', ';
            ValList := ValList + FormatSQLValue(Qry.Fields[ColIdx], FProfile.DriverType);
          end;

          InsertSQL := Format('INSERT INTO %s (%s) VALUES (%s);', [
            QuoteIdent(TableName, FProfile.DriverType),
            ColList,
            ValList
          ]);

          WriteStr(InsertSQL);

          Inc(CurrentRow);
          Inc(FTotalProcessed);
          Inc(BatchCounter);

          if (BatchCounter >= FBackupOpts.InsertBatchSize) or (CurrentRow = TotalRowsInTbl) then
          begin
            BatchCounter := 0;
            FDetailMsg := Format('Mengekspor baris data (%d / %d)...', [CurrentRow, TotalRowsInTbl]);
            Synchronize(@DoSyncProgress);
          end;

          Qry.Next;
        end;
        Qry.Close;
        WriteStr('');
      end;
    end;

    WriteStr('-- Dump selesai.');
  finally
    Qry.Free;
    Cols.Free;
    OutStream.Free;
  end;
end;

procedure TBackupRestoreWorkerThread.ExecuteRestore(AConn: TZConnection);
var
  Lines: TStringList;
  SQLBuffer, CurrentLine, TrimmedLine: string;
  TotalLines, LineCounter: Int64;
  I: Integer;
begin
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FRestoreOpts.FilePath);
    TotalLines := Lines.Count;
    if TotalLines = 0 then TotalLines := 1;

    SQLBuffer := '';
    LineCounter := 0;
    FTotalProcessed := 0;

    if FRestoreOpts.UseTransaction then
      AConn.AutoCommit := False;

    for I := 0 to Lines.Count - 1 do
    begin
      if Terminated then Break;

      CurrentLine := Lines[I];
      Inc(LineCounter);
      TrimmedLine := Trim(CurrentLine);

      if (TrimmedLine = '') or StartsStr('--', TrimmedLine) or StartsStr('/*', TrimmedLine) then
        Continue;

      SQLBuffer := SQLBuffer + CurrentLine + LineEnding;

      if EndsStr(';', TrimmedLine) then
      begin
        try
          AConn.ExecuteDirect(SQLBuffer);
          Inc(FTotalProcessed);
        except
          on E: Exception do
          begin
            if not FRestoreOpts.ContinueOnError then
              raise Exception.CreateFmt('Error di baris %d: %s%sQuery: %s', [LineCounter, E.Message, LineEnding, SQLBuffer]);
          end;
        end;

        SQLBuffer := '';

        if (LineCounter mod 100 = 0) or (LineCounter = TotalLines) then
        begin
          FCurrentTask := 'Mengeksekusi perintah SQL Dump...';
          FItemIndex := LineCounter;
          FTotalItems := TotalLines;
          FProgressPct := Round((LineCounter / TotalLines) * 100);
          FDetailMsg := Format('Memproses baris %d dari %d (%d statement selesai)...', [LineCounter, TotalLines, FTotalProcessed]);
          Synchronize(@DoSyncProgress);
        end;
      end;
    end;

    if FRestoreOpts.UseTransaction then
      AConn.Commit;
  finally
    Lines.Free;
  end;
end;

procedure TBackupRestoreWorkerThread.Execute;
var
  Conn: TZConnection;
  Driver: TDBDriverBase;
  StartTime: QWord;
begin
  StartTime := GetTickCount64;
  Conn := nil;
  Driver := nil;
  FSuccess := False;
  FErrorMessage := '';

  try
    try
      Conn := TZConnection.Create(nil);
      case FProfile.DriverType of
        dtMySQL: Conn.Protocol := 'mysql';
        dtMariaDB: Conn.Protocol := 'mariadb';
        dtPostgreSQL: Conn.Protocol := 'postgresql';
        dtFirebird: Conn.Protocol := 'firebird';
        dtSQLite: Conn.Protocol := 'sqlite';
      end;

      Conn.HostName := FProfile.Host;
      Conn.Port := FProfile.Port;
      if FDatabaseName <> '' then
        Conn.Database := FDatabaseName
      else
        Conn.Database := FProfile.DatabaseName;

      Conn.User := FProfile.Username;
      Conn.Password := FProfile.Password;
      Conn.AutoCommit := True;
      Conn.Connect;

      Driver := TDBConnectionFactory.CreateDriver(FProfile);

      if FMode = brmBackup then
        ExecuteBackup(Conn, Driver)
      else
        ExecuteRestore(Conn);

      FSuccess := not Terminated;
    except
      on E: Exception do
      begin
        FSuccess := False;
        FErrorMessage := E.Message;
        if Assigned(Conn) and Conn.Connected and not Conn.AutoCommit then
          Conn.Rollback;
      end;
    end;
  finally
    if Assigned(Driver) then Driver.Free;
    if Assigned(Conn) then Conn.Free;
    FElapsedMS := GetTickCount64 - StartTime;
    Synchronize(@DoSyncComplete);
  end;
end;

end.
