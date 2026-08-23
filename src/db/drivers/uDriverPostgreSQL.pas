unit uDriverPostgreSQL;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  ZConnection, ZDataset,
  uAppTypes, uDBTypes, uDBDriverBase, uDDLGenerator,
  uModelConnection, uModelSchemaObject;

type
  { TDriverPostgreSQL }
  TDriverPostgreSQL = class(TDBDriverBase)
  protected
    procedure ConfigureConnection; override;
    function ResolveSchema(const ASchema: string): string;
  public
    function GetDriverType: TDBDriverType; override;
    function GetCapabilities: TDBCapabilities; override;
    function GetServerInfo: TDBServerInfo; override;
    function QuoteIdentifier(const AIdentifier: string): string; override;

    // Ekstraksi Metadata PostgreSQL
    procedure ExtractDatabases(AList: TStrings); override;
    procedure ExtractSchemas(const ADBName: string; AList: TStrings); override;
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

{ TDriverPostgreSQL }

procedure TDriverPostgreSQL.ConfigureConnection;
begin
  inherited ConfigureConnection;
  if not Assigned(FProfile) then Exit;

  FConnection.Protocol := 'postgresql';

  if FProfile.Port = 0 then
    FConnection.Port := 5432;

  if FProfile.Charset <> '' then
    FConnection.Properties.Values['codepage'] := FProfile.Charset
  else
    FConnection.Properties.Values['codepage'] := 'UTF8';

  // Penanganan Mode SSL PostgreSQL
  case FProfile.SSLMode of
    sslRequire:    FConnection.Properties.Values['sslmode'] := 'require';
    sslVerifyCA:   FConnection.Properties.Values['sslmode'] := 'verify-ca';
    sslVerifyFull: FConnection.Properties.Values['sslmode'] := 'verify-full';
    else           FConnection.Properties.Values['sslmode'] := 'disable';
  end;

  if FProfile.TimeoutSec > 0 then
    FConnection.Properties.Values['connect_timeout'] := IntToStr(FProfile.TimeoutSec);
end;

function TDriverPostgreSQL.ResolveSchema(const ASchema: string): string;
begin
  if ASchema <> '' then
    Result := ASchema
  else
    Result := 'public';
end;

function TDriverPostgreSQL.GetDriverType: TDBDriverType;
begin
  Result := dtPostgreSQL;
end;

function TDriverPostgreSQL.GetCapabilities: TDBCapabilities;
begin
  Result := [
    dbcSchemas,
    dbcStoredProcedures,
    dbcFunctions,
    dbcTriggers,
    dbcSequences,
    dbcForeignKeys,
    dbcExplainPlan,
    dbcMultipleDatabases,
    dbcSSLConnection,
    dbcCancelQuery
  ];
end;

function TDriverPostgreSQL.QuoteIdentifier(const AIdentifier: string): string;
begin
  Result := '"' + StringReplace(AIdentifier, '"', '""', [rfReplaceAll]) + '"';
end;

function TDriverPostgreSQL.GetServerInfo: TDBServerInfo;
var
  Qry: TZQuery;
  VerStr, NumStr: string;
  Parts: TStringArray;
  I: Integer;
begin
  Result := inherited GetServerInfo;
  Result.ProductName := 'PostgreSQL';

  if IsConnected then
  begin
    Qry := TZQuery.Create(nil);
    try
      Qry.Connection := FConnection;
      Qry.SQL.Text := 'SELECT version() AS ver, current_database() AS cur_db, current_user AS cur_usr, pg_client_encoding() AS cur_charset;';
      Qry.Open;
      if not Qry.IsEmpty then
      begin
        VerStr := Qry.FieldByName('ver').AsString;
        Result.ServerVersion := VerStr;
        Result.CurrentDatabase := Qry.FieldByName('cur_db').AsString;
        Result.CurrentUser := Qry.FieldByName('cur_usr').AsString;
        Result.DefaultCharset := Qry.FieldByName('cur_charset').AsString;

        // Ekstraksi versi numerik (contoh string: "PostgreSQL 15.3 on x86_64-pc-linux-gnu...")
        if Pos('PostgreSQL ', VerStr) = 1 then
        begin
          NumStr := Copy(VerStr, 12, Pos(' ', VerStr + ' ', 12) - 12);
          Parts := NumStr.Split(['.']);
          if Length(Parts) > 0 then Result.VersionMajor := StrToIntDef(Parts[0], 14);
          if Length(Parts) > 1 then Result.VersionMinor := StrToIntDef(Parts[1], 0);
          if Length(Parts) > 2 then Result.VersionRelease := StrToIntDef(Parts[2], 0);
        end;
      end;
      Qry.Close;
    finally
      Qry.Free;
    end;
  end;

  FServerInfo := Result;
end;

procedure TDriverPostgreSQL.ExtractDatabases(AList: TStrings);
var
  Qry: TZQuery;
begin
  AList.Clear;
  Connect;

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT datname FROM pg_database ' +
      'WHERE datistemplate = false AND datallowconn = true ' +
      'ORDER BY datname;';
    Qry.Open;

    while not Qry.EOF do
    begin
      AList.Add(Qry.FieldByName('datname').AsString);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverPostgreSQL.ExtractSchemas(const ADBName: string; AList: TStrings);
var
  Qry: TZQuery;
  SchemaName: string;
begin
  AList.Clear;
  Connect;

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT schema_name FROM information_schema.schemata ' +
      'WHERE schema_name NOT IN (''information_schema'', ''pg_catalog'', ''pg_toast'') ' +
      '  AND schema_name NOT LIKE ''pg_temp_%%'' ' +
      '  AND schema_name NOT LIKE ''pg_toast_temp_%%'' ' +
      'ORDER BY schema_name;';
    Qry.Open;

    while not Qry.EOF do
    begin
      SchemaName := Qry.FieldByName('schema_name').AsString;
      AList.Add(SchemaName);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverPostgreSQL.ExtractTables(const ADBName, ASchema: string; AList: TSchemaObjectList);
var
  Qry: TZQuery;
  Item: TSchemaObject;
  TargetSchema: string;
begin
  AList.Clear;
  Connect;
  TargetSchema := ResolveSchema(ASchema);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT t.table_name, ' +
      '       (SELECT obj_description(c.oid, ''pg_class'') ' +
      '        FROM pg_class c ' +
      '        JOIN pg_namespace n ON n.oid = c.relnamespace ' +
      '        WHERE c.relname = t.table_name AND n.nspname = t.table_schema) AS table_comment, ' +
      '       (SELECT c.reltuples::bigint ' +
      '        FROM pg_class c ' +
      '        JOIN pg_namespace n ON n.oid = c.relnamespace ' +
      '        WHERE c.relname = t.table_name AND n.nspname = t.table_schema) AS approx_rows ' +
      'FROM information_schema.tables t ' +
      'WHERE t.table_schema = :schema AND t.table_type = ''BASE TABLE'' ' +
      'ORDER BY t.table_name;';
    Qry.ParamByName('schema').AsString := TargetSchema;
    Qry.Open;

    while not Qry.EOF do
    begin
      Item := TSchemaObject.Create;
      Item.Name := Qry.FieldByName('table_name').AsString;
      Item.DatabaseName := FProfile.DatabaseName;
      Item.SchemaName := TargetSchema;
      Item.ObjectType := sotTable;
      Item.RowCount := Qry.FieldByName('approx_rows').AsLargeInt;
      Item.Comment := Qry.FieldByName('table_comment').AsString;
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverPostgreSQL.ExtractViews(const ADBName, ASchema: string; AList: TSchemaObjectList);
var
  Qry: TZQuery;
  Item: TSchemaObject;
  TargetSchema: string;
begin
  AList.Clear;
  Connect;
  TargetSchema := ResolveSchema(ASchema);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT table_name, view_definition ' +
      'FROM information_schema.views ' +
      'WHERE table_schema = :schema ' +
      'ORDER BY table_name;';
    Qry.ParamByName('schema').AsString := TargetSchema;
    Qry.Open;

    while not Qry.EOF do
    begin
      Item := TSchemaObject.Create;
      Item.Name := Qry.FieldByName('table_name').AsString;
      Item.DatabaseName := FProfile.DatabaseName;
      Item.SchemaName := TargetSchema;
      Item.ObjectType := sotView;
      Item.DDL := Qry.FieldByName('view_definition').AsString;
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverPostgreSQL.ExtractProcedures(const ADBName, ASchema: string; AList: TSchemaObjectList);
var
  Qry: TZQuery;
  Item: TSchemaObject;
  TargetSchema: string;
begin
  AList.Clear;
  Connect;
  TargetSchema := ResolveSchema(ASchema);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT routine_name, routine_definition ' +
      'FROM information_schema.routines ' +
      'WHERE specific_schema = :schema AND routine_type = ''PROCEDURE'' ' +
      'ORDER BY routine_name;';
    Qry.ParamByName('schema').AsString := TargetSchema;
    Qry.Open;

    while not Qry.EOF do
    begin
      Item := TSchemaObject.Create;
      Item.Name := Qry.FieldByName('routine_name').AsString;
      Item.DatabaseName := FProfile.DatabaseName;
      Item.SchemaName := TargetSchema;
      Item.ObjectType := sotProcedure;
      Item.DDL := Qry.FieldByName('routine_definition').AsString;
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverPostgreSQL.ExtractFunctions(const ADBName, ASchema: string; AList: TSchemaObjectList);
var
  Qry: TZQuery;
  Item: TSchemaObject;
  TargetSchema: string;
begin
  AList.Clear;
  Connect;
  TargetSchema := ResolveSchema(ASchema);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT routine_name, routine_definition ' +
      'FROM information_schema.routines ' +
      'WHERE specific_schema = :schema AND routine_type = ''FUNCTION'' ' +
      'ORDER BY routine_name;';
    Qry.ParamByName('schema').AsString := TargetSchema;
    Qry.Open;

    while not Qry.EOF do
    begin
      Item := TSchemaObject.Create;
      Item.Name := Qry.FieldByName('routine_name').AsString;
      Item.DatabaseName := FProfile.DatabaseName;
      Item.SchemaName := TargetSchema;
      Item.ObjectType := sotFunction;
      Item.DDL := Qry.FieldByName('routine_definition').AsString;
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverPostgreSQL.ExtractTriggers(const ADBName, ASchema: string; AList: TSchemaObjectList);
var
  Qry: TZQuery;
  Item: TSchemaObject;
  TargetSchema: string;
begin
  AList.Clear;
  Connect;
  TargetSchema := ResolveSchema(ASchema);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT DISTINCT trigger_name, event_object_table, action_statement, ' +
      '       action_timing, event_manipulation ' +
      'FROM information_schema.triggers ' +
      'WHERE trigger_schema = :schema ' +
      'ORDER BY trigger_name;';
    Qry.ParamByName('schema').AsString := TargetSchema;
    Qry.Open;

    while not Qry.EOF do
    begin
      Item := TSchemaObject.Create;
      Item.Name := Qry.FieldByName('trigger_name').AsString;
      Item.DatabaseName := FProfile.DatabaseName;
      Item.SchemaName := TargetSchema;
      Item.ObjectType := sotTrigger;
      Item.Comment := Format('%s %s ON %s', [
        Qry.FieldByName('action_timing').AsString,
        Qry.FieldByName('event_manipulation').AsString,
        Qry.FieldByName('event_object_table').AsString
      ]);
      Item.DDL := Qry.FieldByName('action_statement').AsString;
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverPostgreSQL.ExtractSequences(const ADBName, ASchema: string; AList: TSchemaObjectList);
var
  Qry: TZQuery;
  Item: TSchemaObject;
  TargetSchema: string;
begin
  AList.Clear;
  Connect;
  TargetSchema := ResolveSchema(ASchema);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT sequence_name ' +
      'FROM information_schema.sequences ' +
      'WHERE sequence_schema = :schema ' +
      'ORDER BY sequence_name;';
    Qry.ParamByName('schema').AsString := TargetSchema;
    Qry.Open;

    while not Qry.EOF do
    begin
      Item := TSchemaObject.Create;
      Item.Name := Qry.FieldByName('sequence_name').AsString;
      Item.DatabaseName := FProfile.DatabaseName;
      Item.SchemaName := TargetSchema;
      Item.ObjectType := sotSequence;
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverPostgreSQL.ExtractColumns(const ADBName, ASchema, ATable: string; AList: TSchemaColumnList);
var
  Qry: TZQuery;
  Col: TSchemaColumn;
  TargetSchema, DfltVal: string;
begin
  AList.Clear;
  Connect;
  TargetSchema := ResolveSchema(ASchema);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT c.column_name, c.ordinal_position, c.column_default, c.is_nullable, ' +
      '       c.data_type, c.udt_name, c.character_maximum_length, c.numeric_precision, ' +
      '       c.numeric_scale, c.is_identity, ' +
      '       (SELECT pg_catalog.col_description(cl.oid, c.ordinal_position::int) ' +
      '        FROM pg_catalog.pg_class cl ' +
      '        JOIN pg_catalog.pg_namespace n ON n.oid = cl.relnamespace ' +
      '        WHERE cl.relname = c.table_name AND n.nspname = c.table_schema) AS column_comment, ' +
      '       (SELECT COUNT(1) ' +
      '        FROM information_schema.table_constraints tc ' +
      '        JOIN information_schema.key_column_usage kcu ' +
      '          ON tc.constraint_name = kcu.constraint_name ' +
      '         AND tc.table_schema = kcu.table_schema ' +
      '        WHERE tc.constraint_type = ''PRIMARY KEY'' ' +
      '          AND tc.table_schema = c.table_schema ' +
      '          AND tc.table_name = c.table_name ' +
      '          AND kcu.column_name = c.column_name) AS is_pk ' +
      'FROM information_schema.columns c ' +
      'WHERE c.table_schema = :schema AND c.table_name = :tbl ' +
      'ORDER BY c.ordinal_position;';
    Qry.ParamByName('schema').AsString := TargetSchema;
    Qry.ParamByName('tbl').AsString := ATable;
    Qry.Open;

    while not Qry.EOF do
    begin
      Col := TSchemaColumn.Create;
      Col.OrdinalPosition := Qry.FieldByName('ordinal_position').AsInteger;
      Col.Name := Qry.FieldByName('column_name').AsString;
      Col.DataType := UpperCase(Qry.FieldByName('udt_name').AsString);

      if not Qry.FieldByName('character_maximum_length').IsNull then
        Col.Length := Qry.FieldByName('character_maximum_length').AsInteger;

      if not Qry.FieldByName('numeric_precision').IsNull then
        Col.Precision := Qry.FieldByName('numeric_precision').AsInteger;

      if not Qry.FieldByName('numeric_scale').IsNull then
        Col.Scale := Qry.FieldByName('numeric_scale').AsInteger;

      Col.IsNullable := SameText(Qry.FieldByName('is_nullable').AsString, 'YES');
      Col.IsPrimaryKey := Qry.FieldByName('is_pk').AsInteger > 0;

      DfltVal := Qry.FieldByName('column_default').AsString;
      Col.DefaultValue := DfltVal;

      // Deteksi Serial / Autoincrement
      if (Pos('nextval(', DfltVal) = 1) or SameText(Qry.FieldByName('is_identity').AsString, 'YES') then
        Col.IsAutoIncrement := True;

      Col.Comment := Qry.FieldByName('column_comment').AsString;
      AList.Add(Col);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverPostgreSQL.ExtractIndexes(const ADBName, ASchema, ATable: string; AList: TSchemaIndexList);
var
  Qry: TZQuery;
  Idx: TSchemaIndex;
  TargetSchema, IdxName, LastIdxName: string;
begin
  AList.Clear;
  Connect;
  TargetSchema := ResolveSchema(ASchema);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT i.relname AS index_name, ' +
      '       a.attname AS column_name, ' +
      '       ix.indisunique AS is_unique, ' +
      '       ix.indisprimary AS is_primary, ' +
      '       am.amname AS index_type ' +
      'FROM pg_class t ' +
      'JOIN pg_namespace n ON n.oid = t.relnamespace ' +
      'JOIN pg_index ix ON t.oid = ix.indrelid ' +
      'JOIN pg_class i ON i.oid = ix.indexrelid ' +
      'JOIN pg_am am ON am.oid = i.relam ' +
      'JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(ix.indkey) ' +
      'WHERE n.nspname = :schema AND t.relname = :tbl ' +
      'ORDER BY i.relname, array_position(ix.indkey, a.attnum);';
    Qry.ParamByName('schema').AsString := TargetSchema;
    Qry.ParamByName('tbl').AsString := ATable;
    Qry.Open;

    Idx := nil;
    LastIdxName := '';

    while not Qry.EOF do
    begin
      IdxName := Qry.FieldByName('index_name').AsString;

      if IdxName <> LastIdxName then
      begin
        Idx := TSchemaIndex.Create;
        Idx.Name := IdxName;
        Idx.TableName := ATable;
        Idx.IsUnique := Qry.FieldByName('is_unique').AsBoolean;
        Idx.IsPrimary := Qry.FieldByName('is_primary').AsBoolean;
        Idx.IndexType := UpperCase(Qry.FieldByName('index_type').AsString);
        AList.Add(Idx);
        LastIdxName := IdxName;
      end;

      if Assigned(Idx) then
        Idx.Columns.Add(Qry.FieldByName('column_name').AsString);

      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverPostgreSQL.ExtractForeignKeys(const ADBName, ASchema, ATable: string; AList: TSchemaForeignKeyList);
var
  Qry: TZQuery;
  FK: TSchemaForeignKey;
  TargetSchema, ConstraintName, LastConstraintName: string;
begin
  AList.Clear;
  Connect;
  TargetSchema := ResolveSchema(ASchema);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT tc.constraint_name, ' +
      '       kcu.column_name, ' +
      '       ccu.table_name AS foreign_table_name, ' +
      '       ccu.column_name AS foreign_column_name, ' +
      '       rc.update_rule, ' +
      '       rc.delete_rule ' +
      'FROM information_schema.table_constraints tc ' +
      'JOIN information_schema.key_column_usage kcu ' +
      '  ON tc.constraint_name = kcu.constraint_name ' +
      ' AND tc.table_schema = kcu.table_schema ' +
      'JOIN information_schema.constraint_column_usage ccu ' +
      '  ON ccu.constraint_name = tc.constraint_name ' +
      ' AND ccu.table_schema = tc.table_schema ' +
      'JOIN information_schema.referential_constraints rc ' +
      '  ON rc.constraint_name = tc.constraint_name ' +
      ' AND rc.constraint_schema = tc.table_schema ' +
      'WHERE tc.constraint_type = ''FOREIGN KEY'' ' +
      '  AND tc.table_schema = :schema ' +
      '  AND tc.table_name = :tbl ' +
      'ORDER BY tc.constraint_name, kcu.ordinal_position;';
    Qry.ParamByName('schema').AsString := TargetSchema;
    Qry.ParamByName('tbl').AsString := ATable;
    Qry.Open;

    FK := nil;
    LastConstraintName := '';

    while not Qry.EOF do
    begin
      ConstraintName := Qry.FieldByName('constraint_name').AsString;

      if ConstraintName <> LastConstraintName then
      begin
        FK := TSchemaForeignKey.Create;
        FK.Name := ConstraintName;
        FK.TableName := ATable;
        FK.RefTableName := Qry.FieldByName('foreign_table_name').AsString;
        FK.OnUpdate := Qry.FieldByName('update_rule').AsString;
        FK.OnDelete := Qry.FieldByName('delete_rule').AsString;
        AList.Add(FK);
        LastConstraintName := ConstraintName;
      end;

      if Assigned(FK) then
      begin
        FK.ColumnNames.Add(Qry.FieldByName('column_name').AsString);
        FK.RefColumnNames.Add(Qry.FieldByName('foreign_column_name').AsString);
      end;

      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

function TDriverPostgreSQL.GetTableDDL(const ADBName, ASchema, ATable: string): string;
var
  TableObj: TSchemaObject;
  TargetSchema: string;
begin
  Result := '';
  Connect;
  TargetSchema := ResolveSchema(ASchema);

  TableObj := TSchemaObject.Create;
  try
    TableObj.Name := ATable;
    TableObj.DatabaseName := FProfile.DatabaseName;
    TableObj.SchemaName := TargetSchema;
    TableObj.ObjectType := sotTable;

    ExtractColumns(ADBName, TargetSchema, ATable, TableObj.Columns);
    ExtractIndexes(ADBName, TargetSchema, ATable, TableObj.Indexes);
    ExtractForeignKeys(ADBName, TargetSchema, ATable, TableObj.ForeignKeys);

    Result := TDDLGenerator.GenerateCreateTable(TableObj, dtPostgreSQL);
  finally
    TableObj.Free;
  end;
end;

function TDriverPostgreSQL.GetExplainPlan(const ASQL: string; var APlan: TDBExecutionPlanArray): Boolean;
var
  Qry: TZQuery;
  Idx, NodeID: Integer;
  Line: string;
begin
  Result := False;
  SetLength(APlan, 0);
  Connect;

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text := 'EXPLAIN ' + ASQL;
    Qry.Open;

    NodeID := 1;
    while not Qry.EOF do
    begin
      Line := Qry.Fields[0].AsString;
      Idx := Length(APlan);
      SetLength(APlan, Idx + 1);

      APlan[Idx].ID := NodeID;
      APlan[Idx].ParentID := 0;
      APlan[Idx].Operation := 'PLAN LINE';
      APlan[Idx].Details := Line;
      APlan[Idx].Cost := 0;
      APlan[Idx].EstimatedRows := 0;
      APlan[Idx].ActualRows := 0;

      Inc(NodeID);
      Qry.Next;
    end;

    Result := Length(APlan) > 0;
  except
    Result := False;
  end;
  Qry.Free;
end;

end.

