unit uExportWorkerThread;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, DateUtils, db,
  ZConnection, ZDataset,
  uAppTypes, uDBTypes, uModelConnection, uDBDriverBase, uDBConnectionFactory;

type
  { TExportFormat }
  TExportFormat = (
    efCSV,
    efJSON,
    efSQL,
    efHTML,
    efMarkdown,
    efXML
  );

  { TExportOptions }
  TExportOptions = record
    FileName: string;
    Format: TExportFormat;
    Delimiter: Char;
    QuoteChar: Char;
    IncludeHeaders: Boolean;
    NullValueString: string;
    TableName: string;
    BatchSize: Integer;
  end;

  { Event Definitions }
  TExportProgressEvent = procedure(Sender: TObject; const CurrentRow, TotalRows: Int64; const AMessage: string) of object;
  TExportSuccessEvent = procedure(Sender: TObject; const TotalRows: Int64; const ElapsedMS: Int64) of object;
  TExportErrorEvent = procedure(Sender: TObject; const AErrorMessage: string) of object;

  { TExportWorkerThread }
  TExportWorkerThread = class(TThread)
  private
    FProfile: TConnectionProfile;
    FSQL: string;
    FDatabaseTarget: string;
    FOptions: TExportOptions;
    FDriver: TDBDriverBase;
    FQuery: TZQuery;

    FCurrentRow: Int64;
    FTotalRows: Int64;
    FElapsedMS: Int64;
    FErrorMessage: string;
    FProgressMessage: string;

    FOnProgress: TExportProgressEvent;
    FOnSuccess: TExportSuccessEvent;
    FOnError: TExportErrorEvent;

    procedure DoSyncProgress;
    procedure DoSyncSuccess;
    procedure DoSyncError;
    procedure ReportProgress(const ACurrent, ATotal: Int64; const AMessage: string);

    // Format Exporters
    procedure WriteStrToStream(AStream: TStream; const AText: string);
    function EscapeCSVField(const AValue: string; const ADelimiter, AQuote: Char): string;
    function EscapeJSONString(const AValue: string): string;
    function EscapeXMLString(const AValue: string): string;
    function FormatSQLValue(AField: TField): string;

    procedure ExportCSV(AQry: TZQuery; AStream: TStream);
    procedure ExportJSON(AQry: TZQuery; AStream: TStream);
    procedure ExportSQL(AQry: TZQuery; AStream: TStream);
    procedure ExportHTML(AQry: TZQuery; AStream: TStream);
    procedure ExportMarkdown(AQry: TZQuery; AStream: TStream);
    procedure ExportXML(AQry: TZQuery; AStream: TStream);
  protected
    procedure Execute; override;
  public
    constructor Create(AProfile: TConnectionProfile; const ASQL: string; const AOptions: TExportOptions; const ADatabaseTarget: string = '');
    destructor Destroy; override;

    procedure CancelExport;

    property Options: TExportOptions read FOptions write FOptions;
    property CurrentRow: Int64 read FCurrentRow;
    property TotalRows: Int64 read FTotalRows;
    property ElapsedMS: Int64 read FElapsedMS;

    property OnProgress: TExportProgressEvent read FOnProgress write FOnProgress;
    property OnSuccess: TExportSuccessEvent read FOnSuccess write FOnSuccess;
    property OnError: TExportErrorEvent read FOnError write FOnError;
  end;

function DefaultExportOptions(const AFileName: string; const AFormat: TExportFormat): TExportOptions;

implementation

function DefaultExportOptions(const AFileName: string; const AFormat: TExportFormat): TExportOptions;
begin
  Result.FileName := AFileName;
  Result.Format := AFormat;
  Result.Delimiter := ',';
  Result.QuoteChar := '"';
  Result.IncludeHeaders := True;
  Result.NullValueString := 'NULL';
  Result.TableName := 'exported_data';
  Result.BatchSize := 100;
end;

{ TExportWorkerThread }

constructor TExportWorkerThread.Create(AProfile: TConnectionProfile; const ASQL: string; const AOptions: TExportOptions; const ADatabaseTarget: string);
begin
  inherited Create(True);
  FreeOnTerminate := False;

  FProfile := TConnectionProfile.Create;
  if Assigned(AProfile) then
    FProfile.Assign(AProfile);

  FSQL := ASQL;
  FOptions := AOptions;
  FDatabaseTarget := ADatabaseTarget;

  if (FDatabaseTarget <> '') and (FProfile.DriverType in [dtMySQL, dtMariaDB, dtPostgreSQL]) then
    FProfile.DatabaseName := FDatabaseTarget;

  FDriver := nil;
  FQuery := nil;
  FCurrentRow := 0;
  FTotalRows := 0;
  FElapsedMS := 0;
  FErrorMessage := '';
  FProgressMessage := '';
end;

destructor TExportWorkerThread.Destroy;
begin
  if Assigned(FQuery) then
    FreeAndNil(FQuery);

  if Assigned(FDriver) then
    FreeAndNil(FDriver);

  if Assigned(FProfile) then
    FreeAndNil(FProfile);

  //inherited Destroy;
end;

procedure TExportWorkerThread.ReportProgress(const ACurrent, ATotal: Int64; const AMessage: string);
begin
  FCurrentRow := ACurrent;
  FTotalRows := ATotal;
  FProgressMessage := AMessage;
  Synchronize(@DoSyncProgress);
end;

procedure TExportWorkerThread.DoSyncProgress;
begin
  if Assigned(FOnProgress) and not Terminated then
    FOnProgress(Self, FCurrentRow, FTotalRows, FProgressMessage);
end;

procedure TExportWorkerThread.DoSyncSuccess;
begin
  if Assigned(FOnSuccess) and not Terminated then
    FOnSuccess(Self, FTotalRows, FElapsedMS);
end;

procedure TExportWorkerThread.DoSyncError;
begin
  if Assigned(FOnError) and not Terminated then
    FOnError(Self, FErrorMessage);
end;

procedure TExportWorkerThread.CancelExport;
begin
  Terminate;
  try
    if Assigned(FDriver) and FDriver.IsConnected then
    begin
      if Assigned(FQuery) and FQuery.Active then
        FQuery.Close;
      FDriver.Disconnect;
    end;
  except
    // Mengabaikan pemutusan darurat saat cancel
  end;
end;

procedure TExportWorkerThread.WriteStrToStream(AStream: TStream; const AText: string);
var
  RawBytes: RawByteString;
begin
  RawBytes := UTF8Encode(AText);
  if Length(RawBytes) > 0 then
    AStream.WriteBuffer(RawBytes[1], Length(RawBytes));
end;

function TExportWorkerThread.EscapeCSVField(const AValue: string; const ADelimiter, AQuote: Char): string;
var
  NeedsQuoting: Boolean;
begin
  NeedsQuoting := (Pos(ADelimiter, AValue) > 0) or
                  (Pos(AQuote, AValue) > 0) or
                  (Pos(#10, AValue) > 0) or
                  (Pos(#13, AValue) > 0);

  if NeedsQuoting or (Pos(' ', AValue) = 1) or (Pos(' ', AValue) = Length(AValue)) then
    Result := AQuote + StringReplace(AValue, AQuote, AQuote + AQuote, [rfReplaceAll]) + AQuote
  else
    Result := AValue;
end;

function TExportWorkerThread.EscapeJSONString(const AValue: string): string;
var
  I: Integer;
  Ch: Char;
begin
  Result := '';
  for I := 1 to Length(AValue) do
  begin
    Ch := AValue[I];
    case Ch of
      '"':  Result := Result + '\"';
      '\':  Result := Result + '\\';
      #8:   Result := Result + '\b';
      #9:   Result := Result + '\t';
      #10:  Result := Result + '\n';
      #12:  Result := Result + '\f';
      #13:  Result := Result + '\r';
      else
      begin
        if Ord(Ch) < 32 then
          Result := Result + Format('\u%.4x', [Ord(Ch)])
        else
          Result := Result + Ch;
      end;
    end;
  end;
end;

function TExportWorkerThread.EscapeXMLString(const AValue: string): string;
begin
  Result := StringReplace(AValue, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&apos;', [rfReplaceAll]);
end;

function TExportWorkerThread.FormatSQLValue(AField: TField): string;
begin
  if AField.IsNull then
    Result := 'NULL'
  else
  begin
    case AField.DataType of
      ftSmallint, ftInteger, ftWord, ftLargeint, ftAutoInc:
        Result := AField.AsString;
      ftFloat, ftCurrency, ftBCD, ftFMTBcd:
        Result := FloatToStrF(AField.AsFloat, ffGeneral, 15, 4);
      ftBoolean:
        if AField.AsBoolean then
          Result := '1'
        else
          Result := '0';
      ftDate:
        Result := Format('''%s''', [FormatDateTime('YYYY-MM-DD', AField.AsDateTime)]);
      ftTime:
        Result := Format('''%s''', [FormatDateTime('HH:NN:SS', AField.AsDateTime)]);
      ftDateTime, ftTimeStamp:
        Result := Format('''%s''', [FormatDateTime('YYYY-MM-DD HH:NN:SS', AField.AsDateTime)]);
      else
        Result := Format('''%s''', [StringReplace(AField.AsString, '''', '''''', [rfReplaceAll])]);
    end;
  end;
end;

procedure TExportWorkerThread.ExportCSV(AQry: TZQuery; AStream: TStream);
var
  Line: string;
  I: Integer;
begin
  // Write BOM for UTF-8 compatibility
  WriteStrToStream(AStream, #$EF#$BB#$BF);

  // Header Kolom
  if FOptions.IncludeHeaders then
  begin
    Line := '';
    for I := 0 to AQry.FieldCount - 1 do
    begin
      if I > 0 then Line := Line + FOptions.Delimiter;
      Line := Line + EscapeCSVField(AQry.Fields[I].FieldName, FOptions.Delimiter, FOptions.QuoteChar);
    end;
    Line := Line + LineEnding;
    WriteStrToStream(AStream, Line);
  end;

  // Data Baris
  while not AQry.EOF and not Terminated do
  begin
    Line := '';
    for I := 0 to AQry.FieldCount - 1 do
    begin
      if I > 0 then Line := Line + FOptions.Delimiter;
      if AQry.Fields[I].IsNull then
        Line := Line + FOptions.NullValueString
      else
        Line := Line + EscapeCSVField(AQry.Fields[I].AsString, FOptions.Delimiter, FOptions.QuoteChar);
    end;
    Line := Line + LineEnding;
    WriteStrToStream(AStream, Line);

    Inc(FCurrentRow);
    if (FCurrentRow mod 100 = 0) or (FCurrentRow = FTotalRows) then
      ReportProgress(FCurrentRow, FTotalRows, Format('Diekspor %d baris...', [FCurrentRow]));

    AQry.Next;
  end;
end;

procedure TExportWorkerThread.ExportJSON(AQry: TZQuery; AStream: TStream);
var
  Line: string;
  I: Integer;
  IsFirstRow: Boolean;
begin
  WriteStrToStream(AStream, '[' + LineEnding);
  IsFirstRow := True;

  while not AQry.EOF and not Terminated do
  begin
    if not IsFirstRow then
      WriteStrToStream(AStream, ',' + LineEnding);

    Line := '  {';
    for I := 0 to AQry.FieldCount - 1 do
    begin
      if I > 0 then Line := Line + ', ';
      Line := Line + '"' + EscapeJSONString(AQry.Fields[I].FieldName) + '": ';

      if AQry.Fields[I].IsNull then
        Line := Line + 'null'
      else
      begin
        case AQry.Fields[I].DataType of
          ftSmallint, ftInteger, ftWord, ftLargeint, ftAutoInc:
            Line := Line + AQry.Fields[I].AsString;
          ftFloat, ftCurrency, ftBCD, ftFMTBcd:
            Line := Line + FloatToStrF(AQry.Fields[I].AsFloat, ffGeneral, 15, 4);
          ftBoolean:
            if AQry.Fields[I].AsBoolean then
              Line := Line + 'true'
            else
              Line := Line + 'false';
          else
            Line := Line + '"' + EscapeJSONString(AQry.Fields[I].AsString) + '"';
        end;
      end;
    end;
    Line := Line + '}';
    WriteStrToStream(AStream, Line);

    IsFirstRow := False;
    Inc(FCurrentRow);
    if (FCurrentRow mod 100 = 0) or (FCurrentRow = FTotalRows) then
      ReportProgress(FCurrentRow, FTotalRows, Format('Diekspor %d baris...', [FCurrentRow]));

    AQry.Next;
  end;

  WriteStrToStream(AStream, LineEnding + ']' + LineEnding);
end;

procedure TExportWorkerThread.ExportSQL(AQry: TZQuery; AStream: TStream);
var
  ColNames, Values, TargetTable: string;
  I: Integer;
begin
  If (FOptions.TableName) <> '' Then TargetTable :=  FOptions.TableName else TargetTable :=  'exported_data';

  ColNames := '';
  for I := 0 to AQry.FieldCount - 1 do
  begin
    if I > 0 then ColNames := ColNames + ', ';
    ColNames := ColNames + FDriver.QuoteIdentifier(AQry.Fields[I].FieldName);
  end;

  while not AQry.EOF and not Terminated do
  begin
    Values := '';
    for I := 0 to AQry.FieldCount - 1 do
    begin
      if I > 0 then Values := Values + ', ';
      Values := Values + FormatSQLValue(AQry.Fields[I]);
    end;

    WriteStrToStream(AStream, Format('INSERT INTO %s (%s) VALUES (%s);' + LineEnding, [TargetTable, ColNames, Values]));

    Inc(FCurrentRow);
    if (FCurrentRow mod 100 = 0) or (FCurrentRow = FTotalRows) then
      ReportProgress(FCurrentRow, FTotalRows, Format('Diekspor %d baris...', [FCurrentRow]));

    AQry.Next;
  end;
end;

procedure TExportWorkerThread.ExportHTML(AQry: TZQuery; AStream: TStream);
var
  Line: string;
  I: Integer;
begin
  WriteStrToStream(AStream, '<!DOCTYPE html>' + LineEnding + '<html><head><meta charset="UTF-8"><title>Export</title>' +
    '<style>table{border-collapse:collapse;width:100%;font-family:sans-serif;font-size:13px;}' +
    'th,td{border:1px solid #ddd;padding:6px 10px;text-align:left;}th{background:#f2f2f2;}</style>' +
    '</head><body><table>' + LineEnding);

  // Headers
  WriteStrToStream(AStream, '  <thead><tr>' + LineEnding);
  for I := 0 to AQry.FieldCount - 1 do
    WriteStrToStream(AStream, '    <th>' + EscapeXMLString(AQry.Fields[I].FieldName) + '</th>' + LineEnding);
  WriteStrToStream(AStream, '  </tr></thead>' + LineEnding + '  <tbody>' + LineEnding);

  // Rows
  while not AQry.EOF and not Terminated do
  begin
    Line := '    <tr>';
    for I := 0 to AQry.FieldCount - 1 do
    begin
      if AQry.Fields[I].IsNull then
        Line := Line + '<td><em>' + EscapeXMLString(FOptions.NullValueString) + '</em></td>'
      else
        Line := Line + '<td>' + EscapeXMLString(AQry.Fields[I].AsString) + '</td>';
    end;
    Line := Line + '</tr>' + LineEnding;
    WriteStrToStream(AStream, Line);

    Inc(FCurrentRow);
    if (FCurrentRow mod 100 = 0) or (FCurrentRow = FTotalRows) then
      ReportProgress(FCurrentRow, FTotalRows, Format('Diekspor %d baris...', [FCurrentRow]));

    AQry.Next;
  end;

  WriteStrToStream(AStream, '  </tbody>' + LineEnding + '</table></body></html>' + LineEnding);
end;

procedure TExportWorkerThread.ExportMarkdown(AQry: TZQuery; AStream: TStream);
var
  HeaderLine, SepLine, RowLine: string;
  I: Integer;
begin
  HeaderLine := '|';
  SepLine := '|';

  for I := 0 to AQry.FieldCount - 1 do
  begin
    HeaderLine := HeaderLine + ' ' + AQry.Fields[I].FieldName + ' |';
    SepLine := SepLine + ' --- |';
  end;

  WriteStrToStream(AStream, HeaderLine + LineEnding);
  WriteStrToStream(AStream, SepLine + LineEnding);

  while not AQry.EOF and not Terminated do
  begin
    RowLine := '|';
    for I := 0 to AQry.FieldCount - 1 do
    begin
      if AQry.Fields[I].IsNull then
        RowLine := RowLine + ' ' + FOptions.NullValueString + ' |'
      else
        RowLine := RowLine + ' ' + StringReplace(AQry.Fields[I].AsString, '|', '\|', [rfReplaceAll]) + ' |';
    end;
    RowLine := RowLine + LineEnding;
    WriteStrToStream(AStream, RowLine);

    Inc(FCurrentRow);
    if (FCurrentRow mod 100 = 0) or (FCurrentRow = FTotalRows) then
      ReportProgress(FCurrentRow, FTotalRows, Format('Diekspor %d baris...', [FCurrentRow]));

    AQry.Next;
  end;
end;

procedure TExportWorkerThread.ExportXML(AQry: TZQuery; AStream: TStream);
var
  ColTag, Val: string;
  I: Integer;
begin
  WriteStrToStream(AStream, '<?xml version="1.0" encoding="UTF-8"?>' + LineEnding + '<dataset>' + LineEnding);

  while not AQry.EOF and not Terminated do
  begin
    WriteStrToStream(AStream, '  <row>' + LineEnding);
    for I := 0 to AQry.FieldCount - 1 do
    begin
      ColTag := AQry.Fields[I].FieldName;
      if AQry.Fields[I].IsNull then
        WriteStrToStream(AStream, Format('    <%s xsi:nil="true"/>' + LineEnding, [ColTag]))
      else
      begin
        Val := EscapeXMLString(AQry.Fields[I].AsString);
        WriteStrToStream(AStream, Format('    <%s>%s</%s>' + LineEnding, [ColTag, Val, ColTag]));
      end;
    end;
    WriteStrToStream(AStream, '  </row>' + LineEnding);

    Inc(FCurrentRow);
    if (FCurrentRow mod 100 = 0) or (FCurrentRow = FTotalRows) then
      ReportProgress(FCurrentRow, FTotalRows, Format('Diekspor %d baris...', [FCurrentRow]));

    AQry.Next;
  end;

  WriteStrToStream(AStream, '</dataset>' + LineEnding);
end;

procedure TExportWorkerThread.Execute;
var
  StartTime: TDateTime;
  FileStream: TFileStream;
begin
  StartTime := Now;
  FCurrentRow := 0;
  FTotalRows := 0;

  try
    ReportProgress(0, 0, 'Menghubungkan ke sumber data...');
    FDriver := TDBConnectionFactory.CreateDriver(FProfile);
    FDriver.Connect;

    if Terminated then Exit;

    FQuery := TZQuery.Create(nil);
    FQuery.Connection := FDriver.Connection;
    FQuery.SQL.Text := FSQL;

    ReportProgress(0, 0, 'Mengambil dataset kueri...');
    FQuery.Open;
    FTotalRows := FQuery.RecordCount;

    if Terminated then Exit;

    ReportProgress(0, FTotalRows, 'Membuka berkas tujuan...');
    FileStream := TFileStream.Create(FOptions.FileName, fmCreate);
    try
      case FOptions.Format of
        efCSV:      ExportCSV(FQuery, FileStream);
        efJSON:     ExportJSON(FQuery, FileStream);
        efSQL:      ExportSQL(FQuery, FileStream);
        efHTML:     ExportHTML(FQuery, FileStream);
        efMarkdown: ExportMarkdown(FQuery, FileStream);
        efXML:      ExportXML(FQuery, FileStream);
      end;
    finally
      FileStream.Free;
    end;

    FElapsedMS := MilliSecondsBetween(Now, StartTime);

    if not Terminated then
    begin
      ReportProgress(FTotalRows, FTotalRows, 'Ekspor selesai.');
      Synchronize(@DoSyncSuccess);
    end;
  except
    on E: Exception do
    begin
      FErrorMessage := E.Message;
      FElapsedMS := MilliSecondsBetween(Now, StartTime);
      if not Terminated then
        Synchronize(@DoSyncError);
    end;
  end;
end;

end.

