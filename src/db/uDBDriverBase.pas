unit uDBDriverBase;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, DateUtils,
  ZConnection, ZDataset,
  uAppConst, uAppTypes, uAppUtils, uDBTypes,
  uModelConnection, uModelSchemaObject;

type
  { TDBDriverBase }
  TDBDriverBase = class
  protected
    FProfile: TConnectionProfile;
    FConnection: TZConnection;
    FServerInfo: TDBServerInfo;
    FOnStateChange: TDBStateChangeEvent;

    procedure ConfigureConnection; virtual;
    procedure TriggerStateChange(const AConnected: Boolean; const AStatusMessage: string);
    function MeasureExecutionTime(const AStartTime: TDateTime): Int64;
  public
    constructor Create(AProfile: TConnectionProfile); virtual;
    destructor Destroy; override;

    // Manajemen Siklus Koneksi
    procedure Connect; virtual;
    procedure Disconnect; virtual;
    function TestConnection: Boolean; virtual;
    function IsConnected: Boolean; virtual;

    // Transaksi
    procedure StartTransaction; virtual;
    procedure Commit; virtual;
    procedure Rollback; virtual;
    function InTransaction: Boolean; virtual;

    // Eksekusi SQL
    function ExecuteDirect(const ASQL: string): Boolean; virtual;
    function ExecuteQuery(const ASQL: string; out AResult: TDBQueryResult; ATargetQuery: TZQuery = nil): Boolean; virtual;

    // Dialek & Sintaks SQL
    function GetDriverType: TDBDriverType; virtual; abstract;
    function GetCapabilities: TDBCapabilities; virtual; abstract;
    function QuoteIdentifier(const AIdentifier: string): string; virtual;
    function QuoteString(const AValue: string): string; virtual;
    function FormatLimitOffset(const ASQL: string; const ALimit, AOffset: Integer): string; virtual;
    function GetServerInfo: TDBServerInfo; virtual;

    // Ekstraksi Metadata Skema
    procedure ExtractDatabases(AList: TStrings); virtual;
    procedure ExtractSchemas(const ADBName: string; AList: TStrings); virtual;
    procedure ExtractTables(const ADBName, ASchema: string; AList: TSchemaObjectList); virtual;
    procedure ExtractViews(const ADBName, ASchema: string; AList: TSchemaObjectList); virtual;
    procedure ExtractProcedures(const ADBName, ASchema: string; AList: TSchemaObjectList); virtual;
    procedure ExtractFunctions(const ADBName, ASchema: string; AList: TSchemaObjectList); virtual;
    procedure ExtractTriggers(const ADBName, ASchema: string; AList: TSchemaObjectList); virtual;
    procedure ExtractSequences(const ADBName, ASchema: string; AList: TSchemaObjectList); virtual;
    procedure ExtractColumns(const ADBName, ASchema, ATable: string; AList: TSchemaColumnList); virtual;
    procedure ExtractIndexes(const ADBName, ASchema, ATable: string; AList: TSchemaIndexList); virtual;
    procedure ExtractForeignKeys(const ADBName, ASchema, ATable: string; AList: TSchemaForeignKeyList); virtual;

    function GetTableDDL(const ADBName, ASchema, ATable: string): string; virtual;
    function GetViewDDL(const ADBName, ASchema, AView: string): string; virtual;
    function GetExplainPlan(const ASQL: string; var APlan: TDBExecutionPlanArray): Boolean; virtual;

    property Profile: TConnectionProfile read FProfile;
    property Connection: TZConnection read FConnection;
    property ServerInfoData: TDBServerInfo read FServerInfo;
    property OnStateChange: TDBStateChangeEvent read FOnStateChange write FOnStateChange;
  end;

implementation

{ TDBDriverBase }

constructor TDBDriverBase.Create(AProfile: TConnectionProfile);
begin
  inherited Create;
  FProfile := AProfile;
  FConnection := TZConnection.Create(nil);
  FillChar(FServerInfo, SizeOf(TDBServerInfo), 0);
  ConfigureConnection;
end;

destructor TDBDriverBase.Destroy;
begin
  Disconnect;
  FConnection.Free;
  inherited Destroy;
end;

procedure TDBDriverBase.ConfigureConnection;
begin
  if not Assigned(FProfile) then Exit;

  FConnection.HostName := FProfile.Host;
  FConnection.Port := FProfile.Port;
  FConnection.Database := FProfile.DatabaseName;
  FConnection.User := FProfile.Username;
  FConnection.Password := FProfile.Password;
  FConnection.AutoCommit := True;

  if FProfile.Charset <> '' then
    FConnection.Properties.Values['codepage'] := FProfile.Charset;

  if FProfile.TimeoutSec > 0 then
    FConnection.Properties.Values['timeout'] := IntToStr(FProfile.TimeoutSec);
end;

procedure TDBDriverBase.TriggerStateChange(const AConnected: Boolean; const AStatusMessage: string);
begin
  if Assigned(FOnStateChange) then
    FOnStateChange(AConnected, AStatusMessage);
end;

function TDBDriverBase.MeasureExecutionTime(const AStartTime: TDateTime): Int64;
begin
  Result := MilliSecondsBetween(Now, AStartTime);
end;

procedure TDBDriverBase.Connect;
begin
  if not FConnection.Connected then
  begin
    ConfigureConnection;
    try
      FConnection.Connect;
      GetServerInfo;
      TriggerStateChange(True, 'Connected successfully.');
    except
      on E: Exception do
      begin
        TriggerStateChange(False, E.Message);
        raise;
      end;
    end;
  end;
end;

procedure TDBDriverBase.Disconnect;
begin
  if Assigned(FConnection) and FConnection.Connected then
  begin
    try
      FConnection.Disconnect;
    finally
      FServerInfo.IsConnected := False;
      TriggerStateChange(False, 'Disconnected.');
    end;
  end;
end;

function TDBDriverBase.TestConnection: Boolean;
begin
  try
    Connect;
    Result := IsConnected;
  except
    Result := False;
  end;
end;

function TDBDriverBase.IsConnected: Boolean;
begin
  Result := Assigned(FConnection) and FConnection.Connected;
end;

procedure TDBDriverBase.StartTransaction;
begin
  if IsConnected and not FConnection.InTransaction then
    FConnection.StartTransaction;
end;

procedure TDBDriverBase.Commit;
begin
  if IsConnected and FConnection.InTransaction then
    FConnection.Commit;
end;

procedure TDBDriverBase.Rollback;
begin
  if IsConnected and FConnection.InTransaction then
    FConnection.Rollback;
end;

function TDBDriverBase.InTransaction: Boolean;
begin
  Result := IsConnected and FConnection.InTransaction;
end;

function TDBDriverBase.ExecuteDirect(const ASQL: string): Boolean;
begin
  Connect;
  try
    FConnection.ExecuteDirect(ASQL);
    Result := True;
  except
    Result := False;
    raise;
  end;
end;

function TDBDriverBase.ExecuteQuery(const ASQL: string; out AResult: TDBQueryResult; ATargetQuery: TZQuery): Boolean;
var
  Qry: TZQuery;
  OwnsQry: Boolean;
  StartTime: TDateTime;
begin
  Connect;
  FillChar(AResult, SizeOf(TDBQueryResult), 0);
  AResult.StatementType := DetectStatementType(ASQL);

  OwnsQry := (ATargetQuery = nil);
  if OwnsQry then
    Qry := TZQuery.Create(nil)
  else
    Qry := ATargetQuery;

  try
    Qry.Connection := FConnection;
    Qry.SQL.Text := ASQL;
    StartTime := Now;

    try
      if AResult.StatementType = stSelect then
      begin
        Qry.Open;
        AResult.HasResultSet := True;
        AResult.RowsAffected := Qry.RecordCount;
      end
      else
      begin
        Qry.ExecSQL;
        AResult.HasResultSet := False;
        AResult.RowsAffected := Qry.RowsAffected;
      end;

      AResult.ExecutionTimeMS := MeasureExecutionTime(StartTime);
      AResult.IsSuccess := True;
      Result := True;
    except
      on E: Exception do
      begin
        AResult.ExecutionTimeMS := MeasureExecutionTime(StartTime);
        AResult.IsSuccess := False;
        AResult.ErrorMessage := E.Message;
        Result := False;
      end;
    end;
  finally
    if OwnsQry then
      Qry.Free;
  end;
end;

function TDBDriverBase.QuoteIdentifier(const AIdentifier: string): string;
begin
  Result := '"' + AIdentifier + '"';
end;

function TDBDriverBase.QuoteString(const AValue: string): string;
begin
  Result := '''' + StringReplace(AValue, '''', '''''', [rfReplaceAll]) + '''';
end;

function TDBDriverBase.FormatLimitOffset(const ASQL: string; const ALimit, AOffset: Integer): string;
begin
  if AOffset > 0 then
    Result := Format('%s LIMIT %d OFFSET %d', [ASQL, ALimit, AOffset])
  else
    Result := Format('%s LIMIT %d', [ASQL, ALimit]);
end;

function TDBDriverBase.GetServerInfo: TDBServerInfo;
begin
  FServerInfo.IsConnected := IsConnected;
  FServerInfo.HostAddress := FProfile.Host;
  FServerInfo.Port := FProfile.Port;
  FServerInfo.CurrentDatabase := FProfile.DatabaseName;
  FServerInfo.CurrentUser := FProfile.Username;
  Result := FServerInfo;
end;

procedure TDBDriverBase.ExtractDatabases(AList: TStrings);
begin
  AList.Clear;
end;

procedure TDBDriverBase.ExtractSchemas(const ADBName: string; AList: TStrings);
begin
  AList.Clear;
end;

procedure TDBDriverBase.ExtractTables(const ADBName, ASchema: string; AList: TSchemaObjectList);
begin
  AList.Clear;
end;

procedure TDBDriverBase.ExtractViews(const ADBName, ASchema: string; AList: TSchemaObjectList);
begin
  AList.Clear;
end;

procedure TDBDriverBase.ExtractProcedures(const ADBName, ASchema: string; AList: TSchemaObjectList);
begin
  AList.Clear;
end;

procedure TDBDriverBase.ExtractFunctions(const ADBName, ASchema: string; AList: TSchemaObjectList);
begin
  AList.Clear;
end;

procedure TDBDriverBase.ExtractTriggers(const ADBName, ASchema: string; AList: TSchemaObjectList);
begin
  AList.Clear;
end;

procedure TDBDriverBase.ExtractSequences(const ADBName, ASchema: string; AList: TSchemaObjectList);
begin
  AList.Clear;
end;

procedure TDBDriverBase.ExtractColumns(const ADBName, ASchema, ATable: string; AList: TSchemaColumnList);
begin
  AList.Clear;
end;

procedure TDBDriverBase.ExtractIndexes(const ADBName, ASchema, ATable: string; AList: TSchemaIndexList);
begin
  AList.Clear;
end;

procedure TDBDriverBase.ExtractForeignKeys(const ADBName, ASchema, ATable: string; AList: TSchemaForeignKeyList);
begin
  AList.Clear;
end;

function TDBDriverBase.GetTableDDL(const ADBName, ASchema, ATable: string): string;
begin
  Result := '';
end;

function TDBDriverBase.GetViewDDL(const ADBName, ASchema, AView: string): string;
var
  Qry: TZQuery;
  TargetSchema, RawSQL: string;
begin
  Result := '';
  Connect;
  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    case GetDriverType of
      // --- SQLITE (DROP VIEW IF EXISTS + CREATE VIEW) ---
      dtSQLite:
      begin
        Qry.SQL.Text := 'SELECT sql FROM sqlite_master WHERE type = ''view'' AND name = :vname;';
        Qry.ParamByName('vname').AsString := AView;
        Qry.Open;
        if not Qry.IsEmpty and not Qry.Fields[0].IsNull then
        begin
          RawSQL := Trim(Qry.Fields[0].AsString);
          if not RawSQL.EndsWith(';') then
            RawSQL := RawSQL + ';';

          // Sisipkan DROP VIEW IF EXISTS agar langsung siap dieksekusi ulang tanpa error exists
          Result := Format('DROP VIEW IF EXISTS %s;' + sLineBreak + '%s', [
            QuoteIdentifier(AView),
            RawSQL
          ]);
        end;
      end;

      // --- MYSQL & MARIADB (CREATE OR REPLACE VIEW) ---
      dtMySQL, dtMariaDB:
      begin
        try
          if ADBName <> '' then
            Qry.SQL.Text := Format('SHOW CREATE VIEW `%s`.`%s`;', [ADBName, AView])
          else
            Qry.SQL.Text := Format('SHOW CREATE VIEW `%s`;', [AView]);
          Qry.Open;
          if not Qry.IsEmpty and (Qry.FieldCount >= 2) then
          begin
            RawSQL := Trim(Qry.Fields[1].AsString);
            // Ubah CREATE VIEW menjadi CREATE OR REPLACE VIEW jika belum ada
            if (UpperCase(Copy(RawSQL, 1, 7)) = 'CREATE ') and (Pos('OR REPLACE', UpperCase(RawSQL)) = 0) then
              RawSQL := 'CREATE OR REPLACE ' + Copy(RawSQL, 8, Length(RawSQL));
            Result := RawSQL + ';';
          end;
        except
          Result := '';
        end;
      end;

      // --- POSTGRESQL (CREATE OR REPLACE VIEW) ---
      dtPostgreSQL:
      begin
        if ASchema <> '' then
          TargetSchema := ASchema
        else
          TargetSchema := 'public';

        Qry.SQL.Text := 'SELECT pg_get_viewdef(format(''%I.%I'', :sch, :vname)::regclass, true) AS vdef;';
        Qry.ParamByName('sch').AsString := TargetSchema;
        Qry.ParamByName('vname').AsString := AView;
        try
          Qry.Open;
          if not Qry.IsEmpty and not Qry.Fields[0].IsNull then
            Result := Format('CREATE OR REPLACE VIEW "%s"."%s" AS' + sLineBreak + '%s;',
              [TargetSchema, AView, Trim(Qry.Fields[0].AsString)]);
        except
          Result := '';
        end;
      end;

      // --- FIREBIRD (RECREATE VIEW) ---
      dtFirebird:
      begin
        Qry.SQL.Text := 'SELECT RDB$VIEW_SOURCE FROM RDB$RELATIONS WHERE RDB$RELATION_NAME = UPPER(:vname);';
        Qry.ParamByName('vname').AsString := AView;
        try
          Qry.Open;
          if not Qry.IsEmpty and not Qry.Fields[0].IsNull then
            Result := Format('RECREATE VIEW %s AS' + sLineBreak + '%s;', [QuoteIdentifier(AView), Trim(Qry.Fields[0].AsString)]);
        except
          Result := '';
        end;
      end;
    end;
  finally
    Qry.Free;
  end;
end;

function TDBDriverBase.GetExplainPlan(const ASQL: string; var APlan: TDBExecutionPlanArray): Boolean;
begin
  SetLength(APlan, 0);
  Result := False;
end;

end.
