unit uDriverMySQL;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  ZConnection, ZDataset,
  uAppTypes, uDBTypes, uDBDriverBase, uModelConnection, uModelSchemaObject;

type
  { TDriverMySQL }
  TDriverMySQL = class(TDBDriverBase)
  protected
    procedure ConfigureConnection; override;
    function ResolveDatabase(const ADBName: string): string;
  public
    function GetDriverType: TDBDriverType; override;
    function GetCapabilities: TDBCapabilities; override;
    function GetServerInfo: TDBServerInfo; override;
    function QuoteIdentifier(const AIdentifier: string): string; override;

    // Ekstraksi Metadata MySQL / MariaDB
    procedure ExtractDatabases(AList: TStrings); override;
    procedure ExtractTables(const ADBName, ASchema: string; AList: TSchemaObjectList); override;
    procedure ExtractViews(const ADBName, ASchema: string; AList: TSchemaObjectList); override;
    procedure ExtractProcedures(const ADBName, ASchema: string; AList: TSchemaObjectList); override;
    procedure ExtractFunctions(const ADBName, ASchema: string; AList: TSchemaObjectList); override;
    procedure ExtractTriggers(const ADBName, ASchema: string; AList: TSchemaObjectList); override;
    procedure ExtractColumns(const ADBName, ASchema, ATable: string; AList: TSchemaColumnList); override;
    procedure ExtractIndexes(const ADBName, ASchema, ATable: string; AList: TSchemaIndexList); override;
    procedure ExtractForeignKeys(const ADBName, ASchema, ATable: string; AList: TSchemaForeignKeyList); override;
    function GetTableDDL(const ADBName, ASchema, ATable: string): string; override;
    function GetExplainPlan(const ASQL: string; var APlan: TDBExecutionPlanArray): Boolean; override;
  end;

implementation

{ TDriverMySQL }

procedure TDriverMySQL.ConfigureConnection;
begin
  inherited ConfigureConnection;
  if not Assigned(FProfile) then Exit;

  if FProfile.DriverType = dtMariaDB then
    FConnection.Protocol := 'mariadb'
  else
    FConnection.Protocol := 'mysql';

  if FProfile.Port = 0 then
    FConnection.Port := 3306;

  if FProfile.Charset <> '' then
    FConnection.Properties.Values['codepage'] := FProfile.Charset
  else
    FConnection.Properties.Values['codepage'] := 'utf8mb4';

  case FProfile.SSLMode of
    sslRequire:    FConnection.Properties.Values['ssl'] := 'PREFERRED';
    sslVerifyCA:   FConnection.Properties.Values['ssl'] := 'REQUIRED';
    sslVerifyFull: FConnection.Properties.Values['ssl'] := 'VERIFY_IDENTITY';
    else           FConnection.Properties.Values['ssl'] := 'DISABLED';
  end;
end;

function TDriverMySQL.ResolveDatabase(const ADBName: string): string;
begin
  if ADBName <> '' then
    Result := ADBName
  else if Assigned(FProfile) and (FProfile.DatabaseName <> '') then
    Result := FProfile.DatabaseName
  else
    Result := FServerInfo.CurrentDatabase;
end;

function TDriverMySQL.GetDriverType: TDBDriverType;
begin
  Result := dtMySQL;
end;

function TDriverMySQL.GetCapabilities: TDBCapabilities;
begin
  Result := [
    dbcStoredProcedures,
    dbcFunctions,
    dbcTriggers,
    dbcForeignKeys,
    dbcExplainPlan,
    dbcMultipleDatabases,
    dbcSSLConnection,
    dbcCancelQuery
  ];
end;

function TDriverMySQL.QuoteIdentifier(const AIdentifier: string): string;
begin
  Result := '`' + StringReplace(AIdentifier, '`', '``', [rfReplaceAll]) + '`';
end;

function TDriverMySQL.GetServerInfo: TDBServerInfo;
var
  Qry: TZQuery;
  VerStr: string;
  Parts: TStringArray;
begin
  Result := inherited GetServerInfo;
  Result.ProductName := 'MySQL';

  if IsConnected then
  begin
    Qry := TZQuery.Create(nil);
    try
      Qry.Connection := FConnection;
      Qry.SQL.Text := 'SELECT VERSION() AS ver, DATABASE() AS cur_db, USER() AS cur_usr, @@character_set_database AS cur_charset;';
      Qry.Open;
      if not Qry.IsEmpty then
      begin
        VerStr := Qry.FieldByName('ver').AsString;
        Result.ServerVersion := VerStr;
        if Pos('MariaDB', VerStr) > 0 then
          Result.ProductName := 'MariaDB';

        Result.CurrentDatabase := Qry.FieldByName('cur_db').AsString;
        Result.CurrentUser := Qry.FieldByName('cur_usr').AsString;
        Result.DefaultCharset := Qry.FieldByName('cur_charset').AsString;

        // Ekstraksi versi numerik mayor.minor.rilis
        VerStr := StringReplace(VerStr, '-MariaDB', '', [rfIgnoreCase]);
        Parts := VerStr.Split(['.', '-']);
        if Length(Parts) > 0 then Result.VersionMajor := StrToIntDef(Parts[0], 8);
        if Length(Parts) > 1 then Result.VersionMinor := StrToIntDef(Parts[1], 0);
        if Length(Parts) > 2 then Result.VersionRelease := StrToIntDef(Parts[2], 0);
      end;
      Qry.Close;
    finally
      Qry.Free;
    end;
  end;

  FServerInfo := Result;
end;

procedure TDriverMySQL.ExtractDatabases(AList: TStrings);
var
  Qry: TZQuery;
  DBName: string;
begin
  AList.Clear;
  Connect;

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text := 'SHOW DATABASES;';
    Qry.Open;

    while not Qry.EOF do
    begin
      DBName := Qry.Fields[0].AsString;
      // Saring basis data internal sistem standar
      if not SameText(DBName, 'information_schema') and
         not SameText(DBName, 'performance_schema') and
         not SameText(DBName, 'sys') then
      begin
        AList.Add(DBName);
      end;
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverMySQL.ExtractTables(const ADBName, ASchema: string; AList: TSchemaObjectList);
var
  Qry: TZQuery;
  Item: TSchemaObject;
  TargetDB: string;
begin
  AList.Clear;
  Connect;
  TargetDB := ResolveDatabase(ADBName);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT TABLE_NAME, TABLE_ROWS, TABLE_COMMENT ' +
      'FROM information_schema.TABLES ' +
      'WHERE TABLE_SCHEMA = :db AND TABLE_TYPE = ''BASE TABLE'' ' +
      'ORDER BY TABLE_NAME;';
    Qry.ParamByName('db').AsString := TargetDB;
    Qry.Open;

    while not Qry.EOF do
    begin
      Item := TSchemaObject.Create;
      Item.Name := Qry.FieldByName('TABLE_NAME').AsString;
      Item.DatabaseName := TargetDB;
      Item.ObjectType := sotTable;
      Item.RowCount := Qry.FieldByName('TABLE_ROWS').AsLargeInt;
      Item.Comment := Qry.FieldByName('TABLE_COMMENT').AsString;
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverMySQL.ExtractViews(const ADBName, ASchema: string; AList: TSchemaObjectList);
var
  Qry: TZQuery;
  Item: TSchemaObject;
  TargetDB: string;
begin
  AList.Clear;
  Connect;
  TargetDB := ResolveDatabase(ADBName);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT TABLE_NAME ' +
      'FROM information_schema.VIEWS ' +
      'WHERE TABLE_SCHEMA = :db ' +
      'ORDER BY TABLE_NAME;';
    Qry.ParamByName('db').AsString := TargetDB;
    Qry.Open;

    while not Qry.EOF do
    begin
      Item := TSchemaObject.Create;
      Item.Name := Qry.FieldByName('TABLE_NAME').AsString;
      Item.DatabaseName := TargetDB;
      Item.ObjectType := sotView;
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverMySQL.ExtractProcedures(const ADBName, ASchema: string; AList: TSchemaObjectList);
var
  Qry: TZQuery;
  Item: TSchemaObject;
  TargetDB: string;
begin
  AList.Clear;
  Connect;
  TargetDB := ResolveDatabase(ADBName);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT ROUTINE_NAME, ROUTINE_COMMENT ' +
      'FROM information_schema.ROUTINES ' +
      'WHERE ROUTINE_SCHEMA = :db AND ROUTINE_TYPE = ''PROCEDURE'' ' +
      'ORDER BY ROUTINE_NAME;';
    Qry.ParamByName('db').AsString := TargetDB;
    Qry.Open;

    while not Qry.EOF do
    begin
      Item := TSchemaObject.Create;
      Item.Name := Qry.FieldByName('ROUTINE_NAME').AsString;
      Item.DatabaseName := TargetDB;
      Item.ObjectType := sotProcedure;
      Item.Comment := Qry.FieldByName('ROUTINE_COMMENT').AsString;
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverMySQL.ExtractFunctions(const ADBName, ASchema: string; AList: TSchemaObjectList);
var
  Qry: TZQuery;
  Item: TSchemaObject;
  TargetDB: string;
begin
  AList.Clear;
  Connect;
  TargetDB := ResolveDatabase(ADBName);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT ROUTINE_NAME, ROUTINE_COMMENT ' +
      'FROM information_schema.ROUTINES ' +
      'WHERE ROUTINE_SCHEMA = :db AND ROUTINE_TYPE = ''FUNCTION'' ' +
      'ORDER BY ROUTINE_NAME;';
    Qry.ParamByName('db').AsString := TargetDB;
    Qry.Open;

    while not Qry.EOF do
    begin
      Item := TSchemaObject.Create;
      Item.Name := Qry.FieldByName('ROUTINE_NAME').AsString;
      Item.DatabaseName := TargetDB;
      Item.ObjectType := sotFunction;
      Item.Comment := Qry.FieldByName('ROUTINE_COMMENT').AsString;
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverMySQL.ExtractTriggers(const ADBName, ASchema: string; AList: TSchemaObjectList);
var
  Qry: TZQuery;
  Item: TSchemaObject;
  TargetDB: string;
begin
  AList.Clear;
  Connect;
  TargetDB := ResolveDatabase(ADBName);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT TRIGGER_NAME, EVENT_MANIPULATION, EVENT_OBJECT_TABLE, ACTION_STATEMENT ' +
      'FROM information_schema.TRIGGERS ' +
      'WHERE TRIGGER_SCHEMA = :db ' +
      'ORDER BY TRIGGER_NAME;';
    Qry.ParamByName('db').AsString := TargetDB;
    Qry.Open;

    while not Qry.EOF do
    begin
      Item := TSchemaObject.Create;
      Item.Name := Qry.FieldByName('TRIGGER_NAME').AsString;
      Item.DatabaseName := TargetDB;
      Item.ObjectType := sotTrigger;
      Item.Comment := Format('%s ON %s', [
        Qry.FieldByName('EVENT_MANIPULATION').AsString,
        Qry.FieldByName('EVENT_OBJECT_TABLE').AsString
      ]);
      Item.DDL := Qry.FieldByName('ACTION_STATEMENT').AsString;
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverMySQL.ExtractColumns(const ADBName, ASchema, ATable: string; AList: TSchemaColumnList);
var
  Qry: TZQuery;
  Col: TSchemaColumn;
  TargetDB: string;
begin
  AList.Clear;
  Connect;
  TargetDB := ResolveDatabase(ADBName);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, ' +
      '       NUMERIC_SCALE, IS_NULLABLE, COLUMN_KEY, EXTRA, COLUMN_DEFAULT, ' +
      '       COLUMN_COMMENT, ORDINAL_POSITION ' +
      'FROM information_schema.COLUMNS ' +
      'WHERE TABLE_SCHEMA = :db AND TABLE_NAME = :tbl ' +
      'ORDER BY ORDINAL_POSITION;';
    Qry.ParamByName('db').AsString := TargetDB;
    Qry.ParamByName('tbl').AsString := ATable;
    Qry.Open;

    while not Qry.EOF do
    begin
      Col := TSchemaColumn.Create;
      Col.OrdinalPosition := Qry.FieldByName('ORDINAL_POSITION').AsInteger;
      Col.Name := Qry.FieldByName('COLUMN_NAME').AsString;
      Col.DataType := UpperCase(Qry.FieldByName('DATA_TYPE').AsString);

      if not Qry.FieldByName('CHARACTER_MAXIMUM_LENGTH').IsNull then
        Col.Length := Qry.FieldByName('CHARACTER_MAXIMUM_LENGTH').AsInteger;

      if not Qry.FieldByName('NUMERIC_PRECISION').IsNull then
        Col.Precision := Qry.FieldByName('NUMERIC_PRECISION').AsInteger;

      if not Qry.FieldByName('NUMERIC_SCALE').IsNull then
        Col.Scale := Qry.FieldByName('NUMERIC_SCALE').AsInteger;

      Col.IsNullable := SameText(Qry.FieldByName('IS_NULLABLE').AsString, 'YES');
      Col.IsPrimaryKey := Pos('PRI', Qry.FieldByName('COLUMN_KEY').AsString) > 0;
      Col.IsAutoIncrement := Pos('auto_increment', LowerCase(Qry.FieldByName('EXTRA').AsString)) > 0;
      Col.DefaultValue := Qry.FieldByName('COLUMN_DEFAULT').AsString;
      Col.Comment := Qry.FieldByName('COLUMN_COMMENT').AsString;

      AList.Add(Col);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverMySQL.ExtractIndexes(const ADBName, ASchema, ATable: string; AList: TSchemaIndexList);
var
  Qry: TZQuery;
  Idx: TSchemaIndex;
  TargetDB, IdxName, LastIdxName: string;
begin
  AList.Clear;
  Connect;
  TargetDB := ResolveDatabase(ADBName);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT INDEX_NAME, NON_UNIQUE, INDEX_TYPE, COLUMN_NAME, SEQ_IN_INDEX ' +
      'FROM information_schema.STATISTICS ' +
      'WHERE TABLE_SCHEMA = :db AND TABLE_NAME = :tbl ' +
      'ORDER BY INDEX_NAME, SEQ_IN_INDEX;';
    Qry.ParamByName('db').AsString := TargetDB;
    Qry.ParamByName('tbl').AsString := ATable;
    Qry.Open;

    Idx := nil;
    LastIdxName := '';

    while not Qry.EOF do
    begin
      IdxName := Qry.FieldByName('INDEX_NAME').AsString;

      if IdxName <> LastIdxName then
      begin
        Idx := TSchemaIndex.Create;
        Idx.Name := IdxName;
        Idx.TableName := ATable;
        Idx.IsUnique := (Qry.FieldByName('NON_UNIQUE').AsInteger = 0);
        Idx.IsPrimary := SameText(IdxName, 'PRIMARY');
        Idx.IndexType := Qry.FieldByName('INDEX_TYPE').AsString;
        AList.Add(Idx);
        LastIdxName := IdxName;
      end;

      if Assigned(Idx) then
        Idx.Columns.Add(Qry.FieldByName('COLUMN_NAME').AsString);

      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverMySQL.ExtractForeignKeys(const ADBName, ASchema, ATable: string; AList: TSchemaForeignKeyList);
var
  Qry: TZQuery;
  FK: TSchemaForeignKey;
  TargetDB, ConstraintName, LastConstraintName: string;
begin
  AList.Clear;
  Connect;
  TargetDB := ResolveDatabase(ADBName);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT kcu.CONSTRAINT_NAME, kcu.COLUMN_NAME, kcu.REFERENCED_TABLE_NAME, ' +
      '       kcu.REFERENCED_COLUMN_NAME, rc.UPDATE_RULE, rc.DELETE_RULE ' +
      'FROM information_schema.KEY_COLUMN_USAGE kcu ' +
      'JOIN information_schema.REFERENTIAL_CONSTRAINTS rc ' +
      '  ON rc.CONSTRAINT_SCHEMA = kcu.CONSTRAINT_SCHEMA ' +
      ' AND rc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME ' +
      'WHERE kcu.TABLE_SCHEMA = :db AND kcu.TABLE_NAME = :tbl ' +
      '  AND kcu.REFERENCED_TABLE_NAME IS NOT NULL ' +
      'ORDER BY kcu.CONSTRAINT_NAME, kcu.ORDINAL_POSITION;';
    Qry.ParamByName('db').AsString := TargetDB;
    Qry.ParamByName('tbl').AsString := ATable;
    Qry.Open;

    FK := nil;
    LastConstraintName := '';

    while not Qry.EOF do
    begin
      ConstraintName := Qry.FieldByName('CONSTRAINT_NAME').AsString;

      if ConstraintName <> LastConstraintName then
      begin
        FK := TSchemaForeignKey.Create;
        FK.Name := ConstraintName;
        FK.TableName := ATable;
        FK.RefTableName := Qry.FieldByName('REFERENCED_TABLE_NAME').AsString;
        FK.OnUpdate := Qry.FieldByName('UPDATE_RULE').AsString;
        FK.OnDelete := Qry.FieldByName('DELETE_RULE').AsString;
        AList.Add(FK);
        LastConstraintName := ConstraintName;
      end;

      if Assigned(FK) then
      begin
        FK.ColumnNames.Add(Qry.FieldByName('COLUMN_NAME').AsString);
        FK.RefColumnNames.Add(Qry.FieldByName('REFERENCED_COLUMN_NAME').AsString);
      end;

      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

function TDriverMySQL.GetTableDDL(const ADBName, ASchema, ATable: string): string;
var
  Qry: TZQuery;
  TargetDB: string;
begin
  Result := '';
  Connect;
  TargetDB := ResolveDatabase(ADBName);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text := Format('SHOW CREATE TABLE %s.%s;', [QuoteIdentifier(TargetDB), QuoteIdentifier(ATable)]);
    Qry.Open;
    if not Qry.IsEmpty and (Qry.FieldCount >= 2) then
      Result := Qry.Fields[1].AsString + ';';
  finally
    Qry.Free;
  end;
end;

function TDriverMySQL.GetExplainPlan(const ASQL: string; var APlan: TDBExecutionPlanArray): Boolean;
var
  Qry: TZQuery;
  Idx: Integer;
begin
  Result := False;
  SetLength(APlan, 0);
  Connect;

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text := 'EXPLAIN ' + ASQL;
    Qry.Open;

    while not Qry.EOF do
    begin
      Idx := Length(APlan);
      SetLength(APlan, Idx + 1);

      APlan[Idx].ID := Qry.FieldByName('id').AsInteger;
      APlan[Idx].ParentID := 0;
      APlan[Idx].Operation := Format('%s (%s)', [
        Qry.FieldByName('select_type').AsString,
        Qry.FieldByName('type').AsString
      ]);
      APlan[Idx].TargetObject := Qry.FieldByName('table').AsString;
      APlan[Idx].Cost := 0;
      APlan[Idx].EstimatedRows := Qry.FieldByName('rows').AsLargeInt;
      APlan[Idx].ActualRows := 0;
      APlan[Idx].Details := Format('key: %s, len: %s, ref: %s, extra: %s', [
        Qry.FieldByName('key').AsString,
        Qry.FieldByName('key_len').AsString,
        Qry.FieldByName('ref').AsString,
        Qry.FieldByName('Extra').AsString
      ]);

      Qry.Next;
    end;

    Result := Length(APlan) > 0;
  except
    Result := False;
  end;
  Qry.Free;
end;

end.

