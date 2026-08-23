unit uDriverFirebird;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  ZConnection, ZDataset,
  uAppTypes, uDBTypes, uDBDriverBase, uModelConnection, uModelSchemaObject;

type
  { TDriverFirebird }
  TDriverFirebird = class(TDBDriverBase)
  private
    function MapFieldType(const AFieldType, ASubType, AScale, ACharLen, AByteLen: Integer): string;
  protected
    procedure ConfigureConnection; override;
  public
    function GetDriverType: TDBDriverType; override;
    function GetCapabilities: TDBCapabilities; override;
    function GetServerInfo: TDBServerInfo; override;
    function FormatLimitOffset(const ASQL: string; const ALimit, AOffset: Integer): string; override;

    // Ekstraksi Metadata Firebird
    procedure ExtractDatabases(AList: TStrings); override;
    procedure ExtractTables(const ADBName, ASchema: string; AList: TSchemaObjectList); override;
    procedure ExtractViews(const ADBName, ASchema: string; AList: TSchemaObjectList); override;
    procedure ExtractProcedures(const ADBName, ASchema: string; AList: TSchemaObjectList); override;
    procedure ExtractFunctions(const ADBName, ASchema: string; AList: TSchemaObjectList); override;
    procedure ExtractTriggers(const ADBName, ASchema: string; AList: TSchemaObjectList); override;
    procedure ExtractSequences(const ADBName, ASchema: string; AList: TSchemaObjectList); override;
    procedure ExtractColumns(const ADBName, ASchema, ATable: string; AList: TSchemaColumnList); override;
    procedure ExtractIndexes(const ADBName, ASchema, ATable: string; AList: TSchemaIndexList); override;
    procedure ExtractForeignKeys(const ADBName, ASchema, ATable: string; AList: TSchemaForeignKeyList); override;
    function GetTableDDL(const ADBName, ASchema, ATable: string): string; override;
    function GetExplainPlan(const ASQL: string; var APlan: TDBExecutionPlanArray): Boolean; override;
  end;

implementation

{ TDriverFirebird }

procedure TDriverFirebird.ConfigureConnection;
begin
  inherited ConfigureConnection;
  if not Assigned(FProfile) then Exit;

  FConnection.Protocol := 'firebird';

  if FProfile.Port = 0 then
    FConnection.Port := 3050;

  if FProfile.Charset <> '' then
    FConnection.Properties.Values['codepage'] := FProfile.Charset
  else
    FConnection.Properties.Values['codepage'] := 'UTF8';

  // Konfigurasi parameter wire-protocol & dialek SQL
  FConnection.Properties.Values['dialect'] := '3';
  if FProfile.TimeoutSec > 0 then
    FConnection.Properties.Values['timeout'] := IntToStr(FProfile.TimeoutSec);
end;

function TDriverFirebird.GetDriverType: TDBDriverType;
begin
  Result := dtFirebird;
end;

function TDriverFirebird.GetCapabilities: TDBCapabilities;
begin
  Result := [
    dbcStoredProcedures,
    dbcFunctions,
    dbcTriggers,
    dbcSequences,
    dbcForeignKeys,
    dbcExplainPlan,
    dbcCancelQuery
  ];
end;

function TDriverFirebird.FormatLimitOffset(const ASQL: string; const ALimit, AOffset: Integer): string;
begin
  if AOffset > 0 then
    Result := Format('SELECT FIRST %d SKIP %d * FROM (%s)', [ALimit, AOffset, ASQL])
  else
    Result := Format('SELECT FIRST %d * FROM (%s)', [ALimit, ASQL]);
end;

function TDriverFirebird.MapFieldType(const AFieldType, ASubType, AScale, ACharLen, AByteLen: Integer): string;
begin
  case AFieldType of
    7:
    begin
      if AScale < 0 then
        Result := 'NUMERIC'
      else
        Result := 'SMALLINT';
    end;
    8:
    begin
      if AScale < 0 then
        Result := 'NUMERIC'
      else
        Result := 'INTEGER';
    end;
    10: Result := 'FLOAT';
    12: Result := 'DATE';
    13: Result := 'TIME';
    14: Result := 'CHAR';
    16:
    begin
      if AScale < 0 then
      begin
        if ASubType = 2 then
          Result := 'DECIMAL'
        else
          Result := 'NUMERIC';
      end
      else
        Result := 'BIGINT';
    end;
    27: Result := 'DOUBLE PRECISION';
    35: Result := 'TIMESTAMP';
    37: Result := 'VARCHAR';
    261:
    begin
      if ASubType = 1 then
        Result := 'BLOB SUB_TYPE TEXT'
      else
        Result := 'BLOB';
    end;
    else
      Result := 'VARCHAR';
  end;
end;

function TDriverFirebird.GetServerInfo: TDBServerInfo;
var
  Qry: TZQuery;
  VerStr: string;
  Parts: TStringArray;
begin
  Result := inherited GetServerInfo;
  Result.ProductName := 'Firebird';

  if IsConnected then
  begin
    Qry := TZQuery.Create(nil);
    try
      Qry.Connection := FConnection;
      Qry.SQL.Text := 'SELECT rdb$get_context(''SYSTEM'', ''ENGINE_VERSION'') AS ver, CURRENT_USER AS cur_usr FROM rdb$database;';
      try
        Qry.Open;
        if not Qry.IsEmpty then
        begin
          VerStr := Trim(Qry.FieldByName('ver').AsString);
          Result.ServerVersion := VerStr;
          Result.CurrentUser := Trim(Qry.FieldByName('cur_usr').AsString);

          Parts := VerStr.Split(['.']);
          if Length(Parts) > 0 then Result.VersionMajor := StrToIntDef(Parts[0], 3);
          if Length(Parts) > 1 then Result.VersionMinor := StrToIntDef(Parts[1], 0);
          if Length(Parts) > 2 then Result.VersionRelease := StrToIntDef(Parts[2], 0);
        end;
        Qry.Close;
      except
        // Fallback untuk Firebird versi lama (< 2.5)
        Result.ServerVersion := 'Firebird (Legacy)';
      end;
    finally
      Qry.Free;
    end;
  end;

  FServerInfo := Result;
end;

procedure TDriverFirebird.ExtractDatabases(AList: TStrings);
begin
  AList.Clear;
  if Assigned(FProfile) and (FProfile.DatabaseName <> '') then
    AList.Add(FProfile.DatabaseName)
  else
    AList.Add('Default');
end;

procedure TDriverFirebird.ExtractTables(const ADBName, ASchema: string; AList: TSchemaObjectList);
var
  Qry: TZQuery;
  Item: TSchemaObject;
begin
  AList.Clear;
  Connect;

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT TRIM(r.RDB$RELATION_NAME) AS REL_NAME, r.RDB$DESCRIPTION AS REL_DESC ' +
      'FROM RDB$RELATIONS r ' +
      'WHERE (r.RDB$SYSTEM_FLAG IS NULL OR r.RDB$SYSTEM_FLAG = 0) ' +
      '  AND r.RDB$VIEW_BLR IS NULL ' +
      'ORDER BY r.RDB$RELATION_NAME;';
    Qry.Open;

    while not Qry.EOF do
    begin
      Item := TSchemaObject.Create;
      Item.Name := Trim(Qry.FieldByName('REL_NAME').AsString);
      Item.DatabaseName := FProfile.DatabaseName;
      Item.ObjectType := sotTable;
      Item.Comment := Trim(Qry.FieldByName('REL_DESC').AsString);
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverFirebird.ExtractViews(const ADBName, ASchema: string; AList: TSchemaObjectList);
var
  Qry: TZQuery;
  Item: TSchemaObject;
begin
  AList.Clear;
  Connect;

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT TRIM(r.RDB$RELATION_NAME) AS VIEW_NAME, r.RDB$DESCRIPTION AS VIEW_DESC, r.RDB$VIEW_SOURCE AS VIEW_SRC ' +
      'FROM RDB$RELATIONS r ' +
      'WHERE (r.RDB$SYSTEM_FLAG IS NULL OR r.RDB$SYSTEM_FLAG = 0) ' +
      '  AND r.RDB$VIEW_BLR IS NOT NULL ' +
      'ORDER BY r.RDB$RELATION_NAME;';
    Qry.Open;

    while not Qry.EOF do
    begin
      Item := TSchemaObject.Create;
      Item.Name := Trim(Qry.FieldByName('VIEW_NAME').AsString);
      Item.DatabaseName := FProfile.DatabaseName;
      Item.ObjectType := sotView;
      Item.Comment := Trim(Qry.FieldByName('VIEW_DESC').AsString);
      Item.DDL := Trim(Qry.FieldByName('VIEW_SRC').AsString);
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverFirebird.ExtractProcedures(const ADBName, ASchema: string; AList: TSchemaObjectList);
var
  Qry: TZQuery;
  Item: TSchemaObject;
begin
  AList.Clear;
  Connect;

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT TRIM(p.RDB$PROCEDURE_NAME) AS PROC_NAME, p.RDB$DESCRIPTION AS PROC_DESC, p.RDB$PROCEDURE_SOURCE AS PROC_SRC ' +
      'FROM RDB$PROCEDURES p ' +
      'WHERE (p.RDB$SYSTEM_FLAG IS NULL OR p.RDB$SYSTEM_FLAG = 0) ' +
      'ORDER BY p.RDB$PROCEDURE_NAME;';
    Qry.Open;

    while not Qry.EOF do
    begin
      Item := TSchemaObject.Create;
      Item.Name := Trim(Qry.FieldByName('PROC_NAME').AsString);
      Item.DatabaseName := FProfile.DatabaseName;
      Item.ObjectType := sotProcedure;
      Item.Comment := Trim(Qry.FieldByName('PROC_DESC').AsString);
      Item.DDL := Trim(Qry.FieldByName('PROC_SRC').AsString);
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverFirebird.ExtractFunctions(const ADBName, ASchema: string; AList: TSchemaObjectList);
var
  Qry: TZQuery;
  Item: TSchemaObject;
begin
  AList.Clear;
  Connect;

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT TRIM(f.RDB$FUNCTION_NAME) AS FUNC_NAME, f.RDB$DESCRIPTION AS FUNC_DESC ' +
      'FROM RDB$FUNCTIONS f ' +
      'WHERE (f.RDB$SYSTEM_FLAG IS NULL OR f.RDB$SYSTEM_FLAG = 0) ' +
      'ORDER BY f.RDB$FUNCTION_NAME;';
    Qry.Open;

    while not Qry.EOF do
    begin
      Item := TSchemaObject.Create;
      Item.Name := Trim(Qry.FieldByName('FUNC_NAME').AsString);
      Item.DatabaseName := FProfile.DatabaseName;
      Item.ObjectType := sotFunction;
      Item.Comment := Trim(Qry.FieldByName('FUNC_DESC').AsString);
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverFirebird.ExtractTriggers(const ADBName, ASchema: string; AList: TSchemaObjectList);
var
  Qry: TZQuery;
  Item: TSchemaObject;
begin
  AList.Clear;
  Connect;

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT TRIM(t.RDB$TRIGGER_NAME) AS TRIG_NAME, TRIM(t.RDB$RELATION_NAME) AS TBL_NAME, ' +
      '       t.RDB$TRIGGER_SOURCE AS TRIG_SRC, t.RDB$DESCRIPTION AS TRIG_DESC ' +
      'FROM RDB$TRIGGERS t ' +
      'WHERE (t.RDB$SYSTEM_FLAG IS NULL OR t.RDB$SYSTEM_FLAG = 0) ' +
      'ORDER BY t.RDB$TRIGGER_NAME;';
    Qry.Open;

    while not Qry.EOF do
    begin
      Item := TSchemaObject.Create;
      Item.Name := Trim(Qry.FieldByName('TRIG_NAME').AsString);
      Item.DatabaseName := FProfile.DatabaseName;
      Item.ObjectType := sotTrigger;
      Item.Comment := Format('ON TABLE %s', [Trim(Qry.FieldByName('TBL_NAME').AsString)]);
      Item.DDL := Trim(Qry.FieldByName('TRIG_SRC').AsString);
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverFirebird.ExtractSequences(const ADBName, ASchema: string; AList: TSchemaObjectList);
var
  Qry: TZQuery;
  Item: TSchemaObject;
begin
  AList.Clear;
  Connect;

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT TRIM(g.RDB$GENERATOR_NAME) AS GEN_NAME, g.RDB$DESCRIPTION AS GEN_DESC ' +
      'FROM RDB$GENERATORS g ' +
      'WHERE (g.RDB$SYSTEM_FLAG IS NULL OR g.RDB$SYSTEM_FLAG = 0) ' +
      'ORDER BY g.RDB$GENERATOR_NAME;';
    Qry.Open;

    while not Qry.EOF do
    begin
      Item := TSchemaObject.Create;
      Item.Name := Trim(Qry.FieldByName('GEN_NAME').AsString);
      Item.DatabaseName := FProfile.DatabaseName;
      Item.ObjectType := sotSequence;
      Item.Comment := Trim(Qry.FieldByName('GEN_DESC').AsString);
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverFirebird.ExtractColumns(const ADBName, ASchema, ATable: string; AList: TSchemaColumnList);
var
  Qry: TZQuery;
  Col: TSchemaColumn;
  FType, FSubType, FScale, FCharLen, FByteLen, FPrecision: Integer;
begin
  AList.Clear;
  Connect;

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT TRIM(rf.RDB$FIELD_NAME) AS COL_NAME, rf.RDB$FIELD_POSITION AS ORDINAL_POS, ' +
      '       f.RDB$FIELD_TYPE AS FLD_TYPE, f.RDB$FIELD_SUB_TYPE AS FLD_SUB_TYPE, ' +
      '       f.RDB$FIELD_SCALE AS FLD_SCALE, f.RDB$FIELD_LENGTH AS FLD_BYTE_LEN, ' +
      '       f.RDB$CHARACTER_LENGTH AS FLD_CHAR_LEN, f.RDB$FIELD_PRECISION AS FLD_PREC, ' +
      '       rf.RDB$NULL_FLAG AS NULL_FLAG, rf.RDB$DEFAULT_SOURCE AS DFLT_SRC, ' +
      '       rf.RDB$DESCRIPTION AS COL_DESC, ' +
      '       (SELECT COUNT(1) FROM RDB$RELATION_CONSTRAINTS rc ' +
      '        JOIN RDB$INDEX_SEGMENTS idx ON idx.RDB$INDEX_NAME = rc.RDB$INDEX_NAME ' +
      '        WHERE rc.RDB$RELATION_NAME = rf.RDB$RELATION_NAME ' +
      '          AND rc.RDB$CONSTRAINT_TYPE = ''PRIMARY KEY'' ' +
      '          AND idx.RDB$FIELD_NAME = rf.RDB$FIELD_NAME) AS IS_PK ' +
      'FROM RDB$RELATION_FIELDS rf ' +
      'JOIN RDB$FIELDS f ON f.RDB$FIELD_NAME = rf.RDB$FIELD_SOURCE ' +
      'WHERE rf.RDB$RELATION_NAME = :tbl ' +
      'ORDER BY rf.RDB$FIELD_POSITION;';
    Qry.ParamByName('tbl').AsString := UpperCase(Trim(ATable));
    Qry.Open;

    while not Qry.EOF do
    begin
      Col := TSchemaColumn.Create;
      Col.OrdinalPosition := Qry.FieldByName('ORDINAL_POS').AsInteger + 1;
      Col.Name := Trim(Qry.FieldByName('COL_NAME').AsString);

      FType := Qry.FieldByName('FLD_TYPE').AsInteger;
      FSubType := Qry.FieldByName('FLD_SUB_TYPE').AsInteger;
      FScale := Qry.FieldByName('FLD_SCALE').AsInteger;
      FCharLen := Qry.FieldByName('FLD_CHAR_LEN').AsInteger;
      FByteLen := Qry.FieldByName('FLD_BYTE_LEN').AsInteger;
      FPrecision := Qry.FieldByName('FLD_PREC').AsInteger;

      Col.DataType := MapFieldType(FType, FSubType, FScale, FCharLen, FByteLen);
      if FCharLen > 0 then
        Col.Length := FCharLen
      else
        Col.Length := FByteLen;

      Col.Precision := FPrecision;
      Col.Scale := Abs(FScale);

      Col.IsNullable := Qry.FieldByName('NULL_FLAG').IsNull or (Qry.FieldByName('NULL_FLAG').AsInteger = 0);
      Col.IsPrimaryKey := Qry.FieldByName('IS_PK').AsInteger > 0;
      Col.DefaultValue := Trim(Qry.FieldByName('DFLT_SRC').AsString);
      Col.Comment := Trim(Qry.FieldByName('COL_DESC').AsString);

      AList.Add(Col);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverFirebird.ExtractIndexes(const ADBName, ASchema, ATable: string; AList: TSchemaIndexList);
var
  Qry: TZQuery;
  Idx: TSchemaIndex;
  IdxName, LastIdxName: string;
begin
  AList.Clear;
  Connect;

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT TRIM(i.RDB$INDEX_NAME) AS IDX_NAME, i.RDB$UNIQUE_FLAG AS UNIQ_FLAG, ' +
      '       TRIM(s.RDB$FIELD_NAME) AS COL_NAME, rc.RDB$CONSTRAINT_TYPE AS CNSTR_TYPE ' +
      'FROM RDB$INDICES i ' +
      'JOIN RDB$INDEX_SEGMENTS s ON s.RDB$INDEX_NAME = i.RDB$INDEX_NAME ' +
      'LEFT JOIN RDB$RELATION_CONSTRAINTS rc ON rc.RDB$INDEX_NAME = i.RDB$INDEX_NAME ' +
      'WHERE i.RDB$RELATION_NAME = :tbl ' +
      'ORDER BY i.RDB$INDEX_NAME, s.RDB$FIELD_POSITION;';
    Qry.ParamByName('tbl').AsString := UpperCase(Trim(ATable));
    Qry.Open;

    Idx := nil;
    LastIdxName := '';

    while not Qry.EOF do
    begin
      IdxName := Trim(Qry.FieldByName('IDX_NAME').AsString);

      if IdxName <> LastIdxName then
      begin
        Idx := TSchemaIndex.Create;
        Idx.Name := IdxName;
        Idx.TableName := ATable;
        Idx.IsUnique := (Qry.FieldByName('UNIQ_FLAG').AsInteger = 1);
        Idx.IsPrimary := SameText(Trim(Qry.FieldByName('CNSTR_TYPE').AsString), 'PRIMARY KEY');
        Idx.IndexType := 'BTREE';
        AList.Add(Idx);
        LastIdxName := IdxName;
      end;

      if Assigned(Idx) then
        Idx.Columns.Add(Trim(Qry.FieldByName('COL_NAME').AsString));

      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverFirebird.ExtractForeignKeys(const ADBName, ASchema, ATable: string; AList: TSchemaForeignKeyList);
var
  Qry: TZQuery;
  FK: TSchemaForeignKey;
  FKName, LastFKName: string;
begin
  AList.Clear;
  Connect;

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT TRIM(rc.RDB$CONSTRAINT_NAME) AS FK_NAME, ' +
      '       TRIM(rf_src.RDB$FIELD_NAME) AS SRC_COL, ' +
      '       TRIM(rc_ref.RDB$RELATION_NAME) AS REF_TABLE, ' +
      '       TRIM(rf_ref.RDB$FIELD_NAME) AS REF_COL, ' +
      '       refc.RDB$UPDATE_RULE AS UPD_RULE, refc.RDB$DELETE_RULE AS DEL_RULE ' +
      'FROM RDB$RELATION_CONSTRAINTS rc ' +
      'JOIN RDB$REF_CONSTRAINTS refc ON refc.RDB$CONSTRAINT_NAME = rc.RDB$CONSTRAINT_NAME ' +
      'JOIN RDB$RELATION_CONSTRAINTS rc_ref ON rc_ref.RDB$CONSTRAINT_NAME = refc.RDB$CONST_NAME_UQ ' +
      'JOIN RDB$INDEX_SEGMENTS rf_src ON rf_src.RDB$INDEX_NAME = rc.RDB$INDEX_NAME ' +
      'JOIN RDB$INDEX_SEGMENTS rf_ref ON rf_ref.RDB$INDEX_NAME = rc_ref.RDB$INDEX_NAME ' +
      '                              AND rf_ref.RDB$FIELD_POSITION = rf_src.RDB$FIELD_POSITION ' +
      'WHERE rc.RDB$RELATION_NAME = :tbl AND rc.RDB$CONSTRAINT_TYPE = ''FOREIGN KEY'' ' +
      'ORDER BY rc.RDB$CONSTRAINT_NAME, rf_src.RDB$FIELD_POSITION;';
    Qry.ParamByName('tbl').AsString := UpperCase(Trim(ATable));
    Qry.Open;

    FK := nil;
    LastFKName := '';

    while not Qry.EOF do
    begin
      FKName := Trim(Qry.FieldByName('FK_NAME').AsString);

      if FKName <> LastFKName then
      begin
        FK := TSchemaForeignKey.Create;
        FK.Name := FKName;
        FK.TableName := ATable;
        FK.RefTableName := Trim(Qry.FieldByName('REF_TABLE').AsString);
        FK.OnUpdate := Trim(Qry.FieldByName('UPD_RULE').AsString);
        FK.OnDelete := Trim(Qry.FieldByName('DEL_RULE').AsString);
        AList.Add(FK);
        LastFKName := FKName;
      end;

      if Assigned(FK) then
      begin
        FK.ColumnNames.Add(Trim(Qry.FieldByName('SRC_COL').AsString));
        FK.RefColumnNames.Add(Trim(Qry.FieldByName('REF_COL').AsString));
      end;

      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

function TDriverFirebird.GetTableDDL(const ADBName, ASchema, ATable: string): string;
var
  TableObj: TSchemaObject;
begin
  Result := '';
  Connect;

  TableObj := TSchemaObject.Create;
  try
    TableObj.Name := ATable;
    TableObj.DatabaseName := FProfile.DatabaseName;
    TableObj.ObjectType := sotTable;

    ExtractColumns(ADBName, ASchema, ATable, TableObj.Columns);
    ExtractIndexes(ADBName, ASchema, ATable, TableObj.Indexes);
    ExtractForeignKeys(ADBName, ASchema, ATable, TableObj.ForeignKeys);

    Result := TableObj.DDL;
  finally
    TableObj.Free;
  end;
end;

function TDriverFirebird.GetExplainPlan(const ASQL: string; var APlan: TDBExecutionPlanArray): Boolean;
var
  Qry: TZQuery;
begin
  Result := False;
  SetLength(APlan, 0);
  Connect;

  Qry := TZQuery.Create(nil);
  try
    try
      Qry.Connection := FConnection;
      Qry.SQL.Text := ASQL;
      Qry.Prepare;

      SetLength(APlan, 1);
      APlan[0].ID := 1;
      APlan[0].ParentID := 0;
      APlan[0].Operation := 'FIREBIRD STATEMENT';
      APlan[0].TargetObject := '';
      APlan[0].EstimatedRows := 0;
      APlan[0].Details := 'Statement prepared and validated successfully.';
      Result := True;
    except
      on E: Exception do
      begin
        SetLength(APlan, 1);
        APlan[0].ID := 1;
        APlan[0].ParentID := 0;
        APlan[0].Operation := 'PARSER ERROR';
        APlan[0].TargetObject := '';
        APlan[0].EstimatedRows := 0;
        APlan[0].Details := E.Message;
        Result := False;
      end;
    end;
  finally
    Qry.Free;
  end;
end;

end.
