unit uImportWorkerThread;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils, Math,
  ZConnection, ZDataset,
  fpjson, jsonparser,
  uAppTypes, uDBTypes, uModelConnection;

type
  { Format Berkas Impor }
  TImportFileFormat = (iffCSV, iffJSON, iffSQL);

  { Opsi Penanganan Kesalahan }
  TImportErrorAction = (ieaAbort, ieaSkipRow);

  { Konfigurasi Pemetaan Kolom }
  TColumnMapping = record
    SourceIndex: Integer;
    SourceFieldName: string;
    TargetColumnName: string;
    TargetDataType: string;
    IsMapped: Boolean;
  end;
  TColumnMappingArray = array of TColumnMapping;

  { Event Notifikasi Thread }
  TImportProgressEvent = procedure(Sender: TObject; const ACurrentRow, ATotalRows: Int64; const AStatusText: string) of object;
  TImportCompleteEvent = procedure(Sender: TObject; const ATotalImported, ATotalSkipped: Int64; const AElapsedMS: Int64) of object;
  TImportErrorEvent = procedure(Sender: TObject; const AError: string) of object;

  { TImportWorkerThread }
  TImportWorkerThread = class(TThread)
  private
    FProfile: TConnectionProfile;
    FFileName: string;
    FFormat: TImportFileFormat;
    FTargetTable: string;
    FMappings: TColumnMappingArray;
    FDelimiter: Char;
    FHasHeader: Boolean;
    FBatchSize: Integer;
    FErrorAction: TImportErrorAction;

    FTotalImported: Int64;
    FTotalSkipped: Int64;
    FElapsedMS: Int64;
    FErrorMessage: string;

    FProgCurrentRow: Int64;
    FProgTotalRows: Int64;
    FProgStatusText: string;

    FOnProgress: TImportProgressEvent;
    FOnComplete: TImportCompleteEvent;
    FOnError: TImportErrorEvent;

    procedure DoProgress;
    procedure DoComplete;
    procedure DoError;

    function SplitCSVLine(const ALine: string; const ADelim: Char): TStringList;
    function QuoteIdentifier(const AName: string): string;
    procedure ImportCSV(AConn: TZConnection);
    procedure ImportJSON(AConn: TZConnection);
    procedure ImportSQL(AConn: TZConnection);
  protected
    procedure Execute; override;
  public
    constructor Create(
      AProfile: TConnectionProfile;
      const AFileName: string;
      const AFormat: TImportFileFormat;
      const ATargetTable: string;
      const AMappings: TColumnMappingArray;
      const ADelimiter: Char;
      const AHasHeader: Boolean;
      const ABatchSize: Integer;
      const AErrorAction: TImportErrorAction
    );
    destructor Destroy; override;

    property OnProgress: TImportProgressEvent read FOnProgress write FOnProgress;
    property OnComplete: TImportCompleteEvent read FOnComplete write FOnComplete;
    property OnError: TImportErrorEvent read FOnError write FOnError;
  end;

implementation

{ TImportWorkerThread }

constructor TImportWorkerThread.Create(
  AProfile: TConnectionProfile;
  const AFileName: string;
  const AFormat: TImportFileFormat;
  const ATargetTable: string;
  const AMappings: TColumnMappingArray;
  const ADelimiter: Char;
  const AHasHeader: Boolean;
  const ABatchSize: Integer;
  const AErrorAction: TImportErrorAction
);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FProfile := TConnectionProfile.Create;
  FProfile.Assign(AProfile);
  FFileName := AFileName;
  FFormat := AFormat;
  FTargetTable := ATargetTable;
  FMappings := AMappings;
  FDelimiter := ADelimiter;
  FHasHeader := AHasHeader;
  FBatchSize := ABatchSize;
  FErrorAction := AErrorAction;

  FTotalImported := 0;
  FTotalSkipped := 0;
  FElapsedMS := 0;
  FErrorMessage := '';
end;

destructor TImportWorkerThread.Destroy;
begin
  FProfile.Free;
  //inherited Destroy;
end;

procedure TImportWorkerThread.DoProgress;
begin
  if Assigned(FOnProgress) then
    FOnProgress(Self, FProgCurrentRow, FProgTotalRows, FProgStatusText);
end;

procedure TImportWorkerThread.DoComplete;
begin
  if Assigned(FOnComplete) then
    FOnComplete(Self, FTotalImported, FTotalSkipped, FElapsedMS);
end;

procedure TImportWorkerThread.DoError;
begin
  if Assigned(FOnError) then
    FOnError(Self, FErrorMessage);
end;

function TImportWorkerThread.QuoteIdentifier(const AName: string): string;
begin
  case FProfile.DriverType of
    dtMySQL, dtMariaDB: Result := '`' + AName + '`';
    else Result := '"' + AName + '"';
  end;
end;

function TImportWorkerThread.SplitCSVLine(const ALine: string; const ADelim: Char): TStringList;
var
  I: Integer;
  CurToken: string;
  InQuotes: Boolean;
begin
  Result := TStringList.Create;
  CurToken := '';
  InQuotes := False;

  for I := 1 to Length(ALine) do
  begin
    if ALine[I] = '"' then
      InQuotes := not InQuotes
    else if (ALine[I] = ADelim) and not InQuotes then
    begin
      Result.Add(Trim(CurToken));
      CurToken := '';
    end
    else
      CurToken := CurToken + ALine[I];
  end;
  Result.Add(Trim(CurToken));
end;

procedure TImportWorkerThread.ImportCSV(AConn: TZConnection);
var
  SL: TStringList;
  Line: string;
  Tokens: TStringList;
  I, LineIdx, StartIdx: Integer;
  ColListStr, ValListStr, SQLInsert, CellVal: string;
  UncommittedCount: Integer;
  LineNumber: Int64;
begin
  SL := TStringList.Create;
  UncommittedCount := 0;
  LineNumber := 0;

  try
    SL.LoadFromFile(FFileName);
    FProgTotalRows := SL.Count;

    if FHasHeader then
      StartIdx := 1
    else
      StartIdx := 0;

    for LineIdx := StartIdx to SL.Count - 1 do
    begin
      if Terminated then Break;

      Line := Trim(SL[LineIdx]);
      Inc(LineNumber);
      if Line = '' then Continue;

      Tokens := SplitCSVLine(Line, FDelimiter);
      try
        ColListStr := '';
        ValListStr := '';

        for I := 0 to High(FMappings) do
        begin
          if FMappings[I].IsMapped and (FMappings[I].SourceIndex < Tokens.Count) then
          begin
            if ColListStr <> '' then
            begin
              ColListStr := ColListStr + ', ';
              ValListStr := ValListStr + ', ';
            end;

            ColListStr := ColListStr + QuoteIdentifier(FMappings[I].TargetColumnName);
            CellVal := Tokens[FMappings[I].SourceIndex];

            // Hilangkan quote pembungkus jika ada
            if (Length(CellVal) >= 2) and (CellVal[1] = '"') and (CellVal[Length(CellVal)] = '"') then
              CellVal := Copy(CellVal, 2, Length(CellVal) - 2);

            if (CellVal = '') or (UpperCase(CellVal) = 'NULL') then
              ValListStr := ValListStr + 'NULL'
            else
              ValListStr := ValListStr + '''' + StringReplace(CellVal, '''', '''''', [rfReplaceAll]) + '''';
          end;
        end;

        if (ColListStr <> '') and (ValListStr <> '') then
        begin
          SQLInsert := Format('INSERT INTO %s (%s) VALUES (%s);', [QuoteIdentifier(FTargetTable), ColListStr, ValListStr]);
          try
            AConn.ExecuteDirect(SQLInsert);
            Inc(FTotalImported);
            Inc(UncommittedCount);

            if UncommittedCount >= FBatchSize then
            begin
              AConn.Commit;
              UncommittedCount := 0;
            end;
          except
            on E: Exception do
            begin
              Inc(FTotalSkipped);
              if FErrorAction = ieaAbort then
                raise Exception.CreateFmt('Gagal pada baris %d: %s', [LineNumber, E.Message]);
            end;
          end;
        end;

        if LineNumber mod 50 = 0 then
        begin
          FProgCurrentRow := LineNumber;
          FProgStatusText := Format('Mengimpor CSV... (%d baris berhasil)', [FTotalImported]);
          Synchronize(@DoProgress);
        end;
      finally
        Tokens.Free;
      end;
    end;

    if UncommittedCount > 0 then
      AConn.Commit;

  finally
    SL.Free;
  end;
end;

procedure TImportWorkerThread.ImportJSON(AConn: TZConnection);
var
  FileStream: TFileStream;
  Parser: TJSONParser;
  JSONData: TJSONData;
  JSONArray: TJSONArray;
  RowObj: TJSONObject;
  FieldItem: TJSONData;
  I, J: Integer;
  ColListStr, ValListStr, SQLInsert, CellVal, FieldKey: string;
  UncommittedCount: Integer;
begin
  FileStream := TFileStream.Create(FFileName, fmOpenRead or fmShareDenyNone);
  try
    Parser := TJSONParser.Create(FileStream);
    try
      JSONData := Parser.Parse;
      try
        if not (JSONData is TJSONArray) then
          raise Exception.Create('Berkas JSON harus berupa Array of Object [...]');

        JSONArray := TJSONArray(JSONData);
        FProgTotalRows := JSONArray.Count;
        UncommittedCount := 0;

        for I := 0 to JSONArray.Count - 1 do
        begin
          if Terminated then Break;

          if JSONArray.Types[I] = jtObject then
          begin
            RowObj := TJSONObject(JSONArray.Objects[I]);
            ColListStr := '';
            ValListStr := '';

            for J := 0 to High(FMappings) do
            begin
              if FMappings[J].IsMapped then
              begin
                FieldKey := FMappings[J].SourceFieldName;
                FieldItem := RowObj.Find(FieldKey);
                if Assigned(FieldItem) then
                begin
                  if ColListStr <> '' then
                  begin
                    ColListStr := ColListStr + ', ';
                    ValListStr := ValListStr + ', ';
                  end;

                  ColListStr := ColListStr + QuoteIdentifier(FMappings[J].TargetColumnName);

                  if FieldItem is TJSONNull then
                    ValListStr := ValListStr + 'NULL'
                  else
                  begin
                    CellVal := FieldItem.AsString;
                    ValListStr := ValListStr + '''' + StringReplace(CellVal, '''', '''''', [rfReplaceAll]) + '''';
                  end;
                end;
              end;
            end;

            if (ColListStr <> '') and (ValListStr <> '') then
            begin
              SQLInsert := Format('INSERT INTO %s (%s) VALUES (%s);', [QuoteIdentifier(FTargetTable), ColListStr, ValListStr]);
              try
                AConn.ExecuteDirect(SQLInsert);
                Inc(FTotalImported);
                Inc(UncommittedCount);

                if UncommittedCount >= FBatchSize then
                begin
                  AConn.Commit;
                  UncommittedCount := 0;
                end;
              except
                on E: Exception do
                begin
                  Inc(FTotalSkipped);
                  if FErrorAction = ieaAbort then
                    raise Exception.CreateFmt('Gagal pada JSON item ke-%d: %s', [I + 1, E.Message]);
                end;
              end;
            end;
          end;

          if (I + 1) mod 25 = 0 then
          begin
            FProgCurrentRow := I + 1;
            FProgStatusText := Format('Mengimpor JSON... (%d/%d)', [I + 1, JSONArray.Count]);
            Synchronize(@DoProgress);
          end;
        end;

        if UncommittedCount > 0 then
          AConn.Commit;

      finally
        JSONData.Free;
      end;
    finally
      Parser.Free;
    end;
  finally
    FileStream.Free;
  end;
end;

procedure TImportWorkerThread.ImportSQL(AConn: TZConnection);
var
  SL: TStringList;
  I: Integer;
  Line, Statement: string;
  UncommittedCount: Integer;
begin
  SL := TStringList.Create;
  try
    SL.LoadFromFile(FFileName);
    FProgTotalRows := SL.Count;
    UncommittedCount := 0;
    Statement := '';

    for I := 0 to SL.Count - 1 do
    begin
      if Terminated then Break;

      Line := Trim(SL[I]);
      if (Line = '') or Line.StartsWith('--') or Line.StartsWith('/*') then Continue;

      Statement := Statement + ' ' + Line;
      if Line.EndsWith(';') then
      begin
        try
          AConn.ExecuteDirect(Statement);
          Inc(FTotalImported);
          Inc(UncommittedCount);

          if UncommittedCount >= FBatchSize then
          begin
            AConn.Commit;
            UncommittedCount := 0;
          end;
        except
          on E: Exception do
          begin
            Inc(FTotalSkipped);
            if FErrorAction = ieaAbort then
              raise Exception.CreateFmt('Kesalahan SQL pada baris %d: %s', [I + 1, E.Message]);
          end;
        end;
        Statement := '';
      end;

      if (I + 1) mod 50 = 0 then
      begin
        FProgCurrentRow := I + 1;
        FProgStatusText := Format('Mengeksekusi skrip SQL... (%d kueri)', [FTotalImported]);
        Synchronize(@DoProgress);
      end;
    end;

    if UncommittedCount > 0 then
      AConn.Commit;

  finally
    SL.Free;
  end;
end;

procedure TImportWorkerThread.Execute;
var
  StartTime: QWord;
  Conn: TZConnection;
begin
  StartTime := GetTickCount64;
  Conn := TZConnection.Create(nil);
  try
    case FProfile.DriverType of
      dtMySQL: Conn.Protocol := 'mysql';
      dtMariaDB: Conn.Protocol := 'mariadb';
      dtPostgreSQL: Conn.Protocol := 'postgresql';
      dtFirebird: Conn.Protocol := 'firebird';
      dtSQLite: Conn.Protocol := 'sqlite';
    end;

    Conn.HostName := FProfile.Host;
    Conn.Port := FProfile.Port;
    Conn.Database := FProfile.DatabaseName;
    Conn.User := FProfile.Username;
    Conn.Password := FProfile.Password;
    Conn.AutoCommit := False;

    if FProfile.Charset <> '' then
      Conn.Properties.Values['codepage'] := FProfile.Charset;

    try
      Conn.Connect;

      case FFormat of
        iffCSV: ImportCSV(Conn);
        iffJSON: ImportJSON(Conn);
        iffSQL: ImportSQL(Conn);
      end;

      FElapsedMS := GetTickCount64 - StartTime;
      Synchronize(@DoComplete);
    except
      on E: Exception do
      begin
        if Conn.Connected then
          Conn.Rollback;
        FErrorMessage := E.Message;
        Synchronize(@DoError);
      end;
    end;
  finally
    Conn.Free;
  end;
end;

end.
