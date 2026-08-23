unit uDataTransferEngine;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils, SyncObjs, DB,
  ZConnection, ZDataset,
  uAppTypes, uDBTypes, uModelConnection, uDBDriverBase, uDBConnectionFactory,
  uModelSchemaObject;

type
  { Opsi Migrasi Data }
  TDataTransferOptions = record
    CreateTableIfNotExists: Boolean;
    TruncateTargetTable: Boolean;
    TransferData: Boolean;
    BatchSize: Integer;
    ContinueOnError: Boolean;
  end;

  { Event Notifikasi Progress }
  TTransferProgressEvent = procedure(
    Sender: TObject;
    const ACurrentTable: string;
    const ATableIndex, ATotalTables: Integer;
    const ARowsCopied, ATotalRows: Int64;
    const AStatusMessage: string
  ) of object;

  TTransferCompleteEvent = procedure(
    Sender: TObject;
    const ASuccess: Boolean;
    const ATotalCopied: Int64;
    const AElapsedMS: Int64;
    const AErrorMsg: string
  ) of object;

  { Thread Pekerja Transfer Data }
  TDataTransferWorkerThread = class(TThread)
  private
    FSourceProfile: TConnectionProfile;
    FTargetProfile: TConnectionProfile;
    FSourceTables: TStringList;
    FOptions: TDataTransferOptions;

    FCurrentTable: string;
    FTableIdx: Integer;
    FTotalTables: Integer;
    FRowsCopied: Int64;
    FTotalRows: Int64;
    FGrandTotalCopied: Int64;
    FStatusMsg: string;

    FSuccess: Boolean;
    FErrorMsg: string;
    FElapsedMS: Int64;

    FOnProgress: TTransferProgressEvent;
    FOnComplete: TTransferCompleteEvent;

    procedure DoProgress;
    procedure DoComplete;
    function QuoteIdent(const AName: string; const ADriver: TDBDriverType): string;
    function MapColumnType(const ASrcCol: TSchemaColumn; const ATargetDriver: TDBDriverType): string;
    function GenerateCreateTableDDL(
      ASrcDriver: TDBDriverBase;
      const ATableName: string;
      const ATargetDriver: TDBDriverType
    ): string;
  protected
    procedure Execute; override;
  public
    constructor Create(
      ASourceProfile, ATargetProfile: TConnectionProfile;
      ASourceTables: TStrings;
      const AOptions: TDataTransferOptions;
      AOnProgress: TTransferProgressEvent = nil;
      AOnComplete: TTransferCompleteEvent = nil
    );
    destructor Destroy; override;
    procedure CancelTransfer;
  end;

implementation

{ TDataTransferWorkerThread }

constructor TDataTransferWorkerThread.Create(
  ASourceProfile, ATargetProfile: TConnectionProfile;
  ASourceTables: TStrings;
  const AOptions: TDataTransferOptions;
  AOnProgress: TTransferProgressEvent;
  AOnComplete: TTransferCompleteEvent
);
begin
  inherited Create(True);
  FreeOnTerminate := False;

  FSourceProfile := TConnectionProfile.Create;
  FSourceProfile.Assign(ASourceProfile);

  FTargetProfile := TConnectionProfile.Create;
  FTargetProfile.Assign(ATargetProfile);

  FSourceTables := TStringList.Create;
  FSourceTables.Assign(ASourceTables);

  FOptions := AOptions;
  FOnProgress := AOnProgress;
  FOnComplete := AOnComplete;

  FSuccess := False;
  FErrorMsg := '';
  FGrandTotalCopied := 0;
end;

destructor TDataTransferWorkerThread.Destroy;
begin
  FSourceTables.Free;
  FSourceProfile.Free;
  FTargetProfile.Free;
  inherited Destroy;
end;

procedure TDataTransferWorkerThread.CancelTransfer;
begin
  FOnProgress := nil;
  Terminate;
end;

procedure TDataTransferWorkerThread.DoProgress;
begin
  if not Terminated and Assigned(FOnProgress) then
    FOnProgress(Self, FCurrentTable, FTableIdx, FTotalTables, FRowsCopied, FTotalRows, FStatusMsg);
end;

procedure TDataTransferWorkerThread.DoComplete;
begin
  if Assigned(FOnComplete) then
    FOnComplete(Self, FSuccess, FGrandTotalCopied, FElapsedMS, FErrorMsg);
end;

function TDataTransferWorkerThread.QuoteIdent(const AName: string; const ADriver: TDBDriverType): string;
begin
  case ADriver of
    dtMySQL, dtMariaDB: Result := '`' + AName + '`';
    else Result := '"' + AName + '"';
  end;
end;

function TDataTransferWorkerThread.MapColumnType(const ASrcCol: TSchemaColumn; const ATargetDriver: TDBDriverType): string;
var
  T: string;
begin
  T := UpperCase(Trim(ASrcCol.DataType));

  case ATargetDriver of
    dtPostgreSQL:
    begin
      if Pos('INT', T) > 0 then
      begin
        if Pos('BIG', T) > 0 then Result := 'BIGINT'
        else if (Pos('SMALL', T) > 0) or (Pos('TINY', T) > 0) then Result := 'SMALLINT'
        else Result := 'INTEGER';
      end
      else if (Pos('FLOAT', T) > 0) or (Pos('DOUBLE', T) > 0) or (Pos('REAL', T) > 0) then Result := 'DOUBLE PRECISION'
      else if (Pos('DECIMAL', T) > 0) or (Pos('NUMERIC', T) > 0) then Result := 'NUMERIC'
      else if Pos('BOOL', T) > 0 then Result := 'BOOLEAN'
      else if (Pos('DATE', T) > 0) and (Pos('TIME', T) = 0) then Result := 'DATE'
      else if Pos('TIME', T) > 0 then Result := 'TIMESTAMP'
      else if (Pos('BLOB', T) > 0) or (Pos('BYTEA', T) > 0) or (Pos('BINARY', T) > 0) then Result := 'BYTEA'
      else if (ASrcCol.Length > 0) and (ASrcCol.Length <= 10485760) then Result := Format('VARCHAR(%d)', [ASrcCol.Length])
      else Result := 'TEXT';
    end;

    dtMySQL, dtMariaDB:
    begin
      if Pos('BOOL', T) > 0 then Result := 'TINYINT(1)'
      else if (Pos('BIGINT', T) > 0) or (Pos('INT8', T) > 0) then Result := 'BIGINT'
      else if (Pos('SMALLINT', T) > 0) or (Pos('INT2', T) > 0) then Result := 'SMALLINT'
      else if Pos('INT', T) > 0 then Result := 'INT'
      else if (Pos('DOUBLE', T) > 0) or (Pos('FLOAT', T) > 0) then Result := 'DOUBLE'
      else if (Pos('DECIMAL', T) > 0) or (Pos('NUMERIC', T) > 0) then Result := 'DECIMAL(18,4)'
      else if (Pos('DATE', T) > 0) and (Pos('TIME', T) = 0) then Result := 'DATE'
      else if Pos('TIME', T) > 0 then Result := 'DATETIME'
      else if (Pos('BLOB', T) > 0) or (Pos('BYTEA', T) > 0) then Result := 'LONGBLOB'
      else if (ASrcCol.Length > 0) and (ASrcCol.Length <= 255) then Result := Format('VARCHAR(%d)', [ASrcCol.Length])
      else Result := 'LONGTEXT';
    end;

    dtSQLite:
    begin
      if Pos('INT', T) > 0 then Result := 'INTEGER'
      else if (Pos('FLOAT', T) > 0) or (Pos('DOUBLE', T) > 0) or (Pos('DECIMAL', T) > 0) or (Pos('NUMERIC', T) > 0) then Result := 'REAL'
      else if (Pos('BLOB', T) > 0) or (Pos('BYTEA', T) > 0) then Result := 'BLOB'
      else Result := 'TEXT';
    end;

    else
      Result := 'VARCHAR(255)';
  end;
end;

function TDataTransferWorkerThread.GenerateCreateTableDDL(
  ASrcDriver: TDBDriverBase;
  const ATableName: string;
  const ATargetDriver: TDBDriverType
): string;
var
  Cols: TSchemaColumnList;
  I: Integer;
  ColDef, PKs: string;
begin
  Cols := TSchemaColumnList.Create;
  try
    ASrcDriver.ExtractColumns('', '', ATableName, Cols);
    Result := Format('CREATE TABLE %s (' + LineEnding, [QuoteIdent(ATableName, ATargetDriver)]);
    PKs := '';

    for I := 0 to Cols.Count - 1 do
    begin
      ColDef := '  ' + QuoteIdent(Cols[I].Name, ATargetDriver) + ' ' + MapColumnType(Cols[I], ATargetDriver);

      if not Cols[I].IsNullable then
        ColDef := ColDef + ' NOT NULL';

      if Cols[I].IsPrimaryKey then
      begin
        if PKs <> '' then PKs := PKs + ', ';
        PKs := PKs + QuoteIdent(Cols[I].Name, ATargetDriver);
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

procedure TDataTransferWorkerThread.Execute;
var
  SrcConn, TgtConn: TZConnection;
  SrcQuery, TgtQuery: TZQuery;
  SrcDriver, TgtDriver: TDBDriverBase;
  TblIdx, ColIdx: Integer;
  TblName, SelectSQL, InsertSQL, ColList, ParamList: string;
  BatchCount: Integer;
  StartTime: QWord;
  TgtTables: TSchemaObjectList;
  TableExists: Boolean;
  I: Integer;
begin
  StartTime := GetTickCount64;
  SrcConn := nil;
  TgtConn := nil;
  SrcQuery := nil;
  TgtQuery := nil;
  SrcDriver := nil;
  TgtDriver := nil;
  TgtTables := nil;

  try
    try
      // 1. Inisialisasi Koneksi Zeos Sumber & Target
      SrcConn := TZConnection.Create(nil);
      TgtConn := TZConnection.Create(nil);

      case FSourceProfile.DriverType of
        dtMySQL: SrcConn.Protocol := 'mysql';
        dtMariaDB: SrcConn.Protocol := 'mariadb';
        dtPostgreSQL: SrcConn.Protocol := 'postgresql';
        dtFirebird: SrcConn.Protocol := 'firebird';
        dtSQLite: SrcConn.Protocol := 'sqlite';
      end;
      SrcConn.HostName := FSourceProfile.Host;
      SrcConn.Port := FSourceProfile.Port;
      SrcConn.Database := FSourceProfile.DatabaseName;
      SrcConn.User := FSourceProfile.Username;
      SrcConn.Password := FSourceProfile.Password;
      SrcConn.AutoCommit := True;
      SrcConn.Connect;

      case FTargetProfile.DriverType of
        dtMySQL: TgtConn.Protocol := 'mysql';
        dtMariaDB: TgtConn.Protocol := 'mariadb';
        dtPostgreSQL: TgtConn.Protocol := 'postgresql';
        dtFirebird: TgtConn.Protocol := 'firebird';
        dtSQLite: TgtConn.Protocol := 'sqlite';
      end;
      TgtConn.HostName := FTargetProfile.Host;
      TgtConn.Port := FTargetProfile.Port;
      TgtConn.Database := FTargetProfile.DatabaseName;
      TgtConn.User := FTargetProfile.Username;
      TgtConn.Password := FTargetProfile.Password;
      TgtConn.AutoCommit := False; // Transaksi manual untuk kecepatan batch insert
      TgtConn.Connect;

      SrcDriver := TDBConnectionFactory.CreateDriver(FSourceProfile);
      TgtDriver := TDBConnectionFactory.CreateDriver(FTargetProfile);
      TgtTables := TSchemaObjectList.Create;

      FTotalTables := FSourceTables.Count;
      FGrandTotalCopied := 0;

      for TblIdx := 0 to FSourceTables.Count - 1 do
      begin
        if Terminated then Break;

        TblName := FSourceTables[TblIdx];
        FCurrentTable := TblName;
        FTableIdx := TblIdx + 1;
        FRowsCopied := 0;
        FTotalRows := 0;
        FStatusMsg := 'Menyiapkan tabel target...';
        Synchronize(@DoProgress);

        // Periksa keberadaan tabel di target
        TgtTables.Clear;
        TgtDriver.ExtractTables('', '', TgtTables);
        TableExists := False;
        for I := 0 to TgtTables.Count - 1 do
        begin
          if SameText(TgtTables[I].Name, TblName) then
          begin
            TableExists := True;
            Break;
          end;
        end;

        // Auto-create tabel di target jika belum ada
        if not TableExists and FOptions.CreateTableIfNotExists then
        begin
          FStatusMsg := 'Membuat struktur tabel target...';
          Synchronize(@DoProgress);
          TgtConn.ExecuteDirect(GenerateCreateTableDDL(SrcDriver, TblName, FTargetProfile.DriverType));
          TgtConn.Commit;
          TableExists := True;
        end;

        if not TableExists then
        begin
          if not FOptions.ContinueOnError then
            raise Exception.CreateFmt('Tabel "%s" tidak ditemukan pada database target.', [TblName]);
          Continue;
        end;

        // Truncate tabel target jika opsi dipilih
        if FOptions.TruncateTargetTable then
        begin
          FStatusMsg := 'Mengosongkan tabel target...';
          Synchronize(@DoProgress);
          TgtConn.ExecuteDirect('DELETE FROM ' + QuoteIdent(TblName, FTargetProfile.DriverType));
          TgtConn.Commit;
        end;

        if not FOptions.TransferData then Continue;

        // 2. Query Data dari Sumber
        SrcQuery := TZQuery.Create(nil);
        SrcQuery.Connection := SrcConn;
        SelectSQL := 'SELECT * FROM ' + QuoteIdent(TblName, FSourceProfile.DriverType);
        SrcQuery.SQL.Text := SelectSQL;
        SrcQuery.Open;

        // Siapkan INSERT statement terparameterisasi pada Target
        ColList := '';
        ParamList := '';
        for ColIdx := 0 to SrcQuery.FieldCount - 1 do
        begin
          if ColIdx > 0 then
          begin
            ColList := ColList + ', ';
            ParamList := ParamList + ', ';
          end;
          ColList := ColList + QuoteIdent(SrcQuery.Fields[ColIdx].FieldName, FTargetProfile.DriverType);
          ParamList := ParamList + ':p' + IntToStr(ColIdx);
        end;

        InsertSQL := Format('INSERT INTO %s (%s) VALUES (%s)', [
          QuoteIdent(TblName, FTargetProfile.DriverType),
          ColList,
          ParamList
        ]);

        TgtQuery := TZQuery.Create(nil);
        TgtQuery.Connection := TgtConn;
        TgtQuery.SQL.Text := InsertSQL;

        BatchCount := 0;
        while not SrcQuery.EOF do
        begin
          if Terminated then Break;

          // Mapping parameter baris per baris
          for ColIdx := 0 to SrcQuery.FieldCount - 1 do
          begin
            if SrcQuery.Fields[ColIdx].IsNull then
              TgtQuery.Params[ColIdx].Clear
            else
              TgtQuery.Params[ColIdx].Value := SrcQuery.Fields[ColIdx].Value;
          end;

          TgtQuery.ExecSQL;
          Inc(FRowsCopied);
          Inc(FGrandTotalCopied);
          Inc(BatchCount);

          // Batch Commit
          if BatchCount >= FOptions.BatchSize then
          begin
            TgtConn.Commit;
            BatchCount := 0;
            FStatusMsg := Format('Mentransfer baris (%d disalin)...', [FRowsCopied]);
            Synchronize(@DoProgress);
          end;

          SrcQuery.Next;
        end;

        // Selesaikan sisa batch
        if BatchCount > 0 then
          TgtConn.Commit;

        SrcQuery.Close;
        FreeAndNil(SrcQuery);
        FreeAndNil(TgtQuery);

        FStatusMsg := Format('Selesai (%d baris).', [FRowsCopied]);
        Synchronize(@DoProgress);
      end;

      FSuccess := not Terminated;
    except
      on E: Exception do
      begin
        if Assigned(TgtConn) and TgtConn.Connected then
          TgtConn.Rollback;
        FSuccess := False;
        FErrorMsg := E.Message;
      end;
    end;
  finally
    if Assigned(SrcQuery) then SrcQuery.Free;
    if Assigned(TgtQuery) then TgtQuery.Free;
    if Assigned(TgtTables) then TgtTables.Free;
    if Assigned(SrcDriver) then SrcDriver.Free;
    if Assigned(TgtDriver) then TgtDriver.Free;
    if Assigned(SrcConn) then SrcConn.Free;
    if Assigned(TgtConn) then TgtConn.Free;

    FElapsedMS := GetTickCount64 - StartTime;
    Synchronize(@DoComplete);
  end;
end;

end.
