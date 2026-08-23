unit uDriverSQLite;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  ZConnection, ZDataset,
  uAppTypes, uDBTypes, uDBDriverBase, uModelConnection, uModelSchemaObject;

type
  { TDriverSQLite }
  TDriverSQLite = class(TDBDriverBase)
  private
    function SanitizeSchema(const ADBName: string): string;
  protected
    procedure ConfigureConnection; override;
    procedure ParseDataTypeParameters(const AFullType: string; out ABaseType: string; out ALen, APrec, AScale: Integer);
  public
    function GetDriverType: TDBDriverType; override;
    function GetCapabilities: TDBCapabilities; override;
    function GetServerInfo: TDBServerInfo; override;

    // Ekstraksi Metadata SQLite
    procedure ExtractDatabases(AList: TStrings); override;
    procedure ExtractTables(const ADBName, ASchema: string; AList: TSchemaObjectList); override;
    procedure ExtractViews(const ADBName, ASchema: string; AList: TSchemaObjectList); override;
    procedure ExtractTriggers(const ADBName, ASchema: string; AList: TSchemaObjectList); override;
    procedure ExtractColumns(const ADBName, ASchema, ATable: string; AList: TSchemaColumnList); override;
    procedure ExtractIndexes(const ADBName, ASchema, ATable: string; AList: TSchemaIndexList); override;
    procedure ExtractForeignKeys(const ADBName, ASchema, ATable: string; AList: TSchemaForeignKeyList); override;
    function GetTableDDL(const ADBName, ASchema, ATable: string): string; override;
    function GetExplainPlan(const ASQL: string; var APlan: TDBExecutionPlanArray): Boolean; override;
  end;

implementation

{ TDriverSQLite }

function TDriverSQLite.SanitizeSchema(const ADBName: string): string;
begin
  // Jika parameter berisi path Windows (ada ':\', '\', atau '/'), arahkan ke skema 'main'
  if (ADBName = '') or (Pos(':', ADBName) > 0) or (Pos('/', ADBName) > 0) or (Pos('\', ADBName) > 0) then
    Result := 'main'
  else
    Result := ADBName;
end;

procedure TDriverSQLite.ConfigureConnection;
begin
  inherited ConfigureConnection;
  if not Assigned(FProfile) then Exit;

  FConnection.Protocol := 'sqlite';
  FConnection.Database := FProfile.DatabaseName;
  FConnection.Properties.Values['foreign_keys'] := 'ON';
  if FProfile.TimeoutSec > 0 then
    FConnection.Properties.Values['busy_timeout'] := IntToStr(FProfile.TimeoutSec * 1000)
  else
    FConnection.Properties.Values['busy_timeout'] := '5000';
end;

function TDriverSQLite.GetDriverType: TDBDriverType;
begin
  Result := dtSQLite;
end;

function TDriverSQLite.GetCapabilities: TDBCapabilities;
begin
  Result := [dbcTriggers, dbcForeignKeys, dbcExplainPlan];
end;

function TDriverSQLite.GetServerInfo: TDBServerInfo;
var
  Qry: TZQuery;
  VerStr: string;
  Parts: TStringArray;
begin
  Result := inherited GetServerInfo;
  Result.ProductName := 'SQLite';
  Result.DefaultCharset := 'UTF-8';

  if IsConnected then
  begin
    Qry := TZQuery.Create(nil);
    try
      Qry.Connection := FConnection;
      Qry.ParamCheck := False;
      Qry.SQL.Text := 'SELECT sqlite_version() AS ver;';
      Qry.Open;
      if not Qry.IsEmpty then
      begin
        VerStr := Qry.FieldByName('ver').AsString;
        Result.ServerVersion := VerStr;
        Parts := VerStr.Split(['.']);
        if Length(Parts) > 0 then Result.VersionMajor := StrToIntDef(Parts[0], 3);
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

procedure TDriverSQLite.ParseDataTypeParameters(const AFullType: string; out ABaseType: string; out ALen, APrec, AScale: Integer);
var
  OpenPos, ClosePos, CommaPos: Integer;
  ParamStr: string;
begin
  ALen := 0;
  APrec := 0;
  AScale := 0;
  ABaseType := UpperCase(Trim(AFullType));

  OpenPos := Pos('(', ABaseType);
  ClosePos := Pos(')', ABaseType);

  if (OpenPos > 0) and (ClosePos > OpenPos) then
  begin
    ParamStr := Copy(ABaseType, OpenPos + 1, ClosePos - OpenPos - 1);
    ABaseType := Trim(Copy(ABaseType, 1, OpenPos - 1));
    CommaPos := Pos(',', ParamStr);

    if CommaPos > 0 then
    begin
      APrec := StrToIntDef(Trim(Copy(ParamStr, 1, CommaPos - 1)), 0);
      AScale := StrToIntDef(Trim(Copy(ParamStr, CommaPos + 1, Length(ParamStr))), 0);
    end
    else
    begin
      ALen := StrToIntDef(Trim(ParamStr), 0);
      APrec := ALen;
    end;
  end;
end;

procedure TDriverSQLite.ExtractDatabases(AList: TStrings);
var
  Qry: TZQuery;
begin
  AList.Clear;
  Connect;
  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.ParamCheck := False;
    Qry.SQL.Text := 'PRAGMA database_list;';
    Qry.Open;
    while not Qry.EOF do
    begin
      AList.Add(Qry.FieldByName('name').AsString);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverSQLite.ExtractTables(const ADBName, ASchema: string; AList: TSchemaObjectList);
var
  Qry: TZQuery;
  Item: TSchemaObject;
  TargetDB: string;
begin
  AList.Clear;
  Connect;
  TargetDB := SanitizeSchema(ADBName);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.ParamCheck := False;
    Qry.SQL.Text := Format(
      'SELECT name, sql FROM %s.sqlite_master ' +
      'WHERE type = ''table'' AND name NOT LIKE ''sqlite_%%'' ' +
      'ORDER BY name;', [TargetDB]
    );
    Qry.Open;

    while not Qry.EOF do
    begin
      Item := TSchemaObject.Create;
      Item.Name := Qry.FieldByName('name').AsString;
      Item.DatabaseName := TargetDB;
      Item.ObjectType := sotTable;
      Item.DDL := Qry.FieldByName('sql').AsString;
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverSQLite.ExtractViews(const ADBName, ASchema: string; AList: TSchemaObjectList);
var
  Qry: TZQuery;
  Item: TSchemaObject;
  TargetDB: string;
begin
  AList.Clear;
  Connect;
  TargetDB := SanitizeSchema(ADBName);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.ParamCheck := False;
    Qry.SQL.Text := Format(
      'SELECT name, sql FROM %s.sqlite_master ' +
      'WHERE type = ''view'' ORDER BY name;', [TargetDB]
    );
    Qry.Open;

    while not Qry.EOF do
    begin
      Item := TSchemaObject.Create;
      Item.Name := Qry.FieldByName('name').AsString;
      Item.DatabaseName := TargetDB;
      Item.ObjectType := sotView;
      Item.DDL := Qry.FieldByName('sql').AsString;
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverSQLite.ExtractTriggers(const ADBName, ASchema: string; AList: TSchemaObjectList);
var
  Qry: TZQuery;
  Item: TSchemaObject;
  TargetDB: string;
begin
  AList.Clear;
  Connect;
  TargetDB := SanitizeSchema(ADBName);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.ParamCheck := False;
    Qry.SQL.Text := Format(
      'SELECT name, tbl_name, sql FROM %s.sqlite_master ' +
      'WHERE type = ''trigger'' ORDER BY name;', [TargetDB]
    );
    Qry.Open;

    while not Qry.EOF do
    begin
      Item := TSchemaObject.Create;
      Item.Name := Qry.FieldByName('name').AsString;
      Item.DatabaseName := TargetDB;
      Item.ObjectType := sotTrigger;
      Item.DDL := Qry.FieldByName('sql').AsString;
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverSQLite.ExtractColumns(const ADBName, ASchema, ATable: string; AList: TSchemaColumnList);
var
  Qry: TZQuery;
  Col: TSchemaColumn;
  TargetDB, TableDDL, CleanDDL, BaseType: string;
  Len, Prec, Scale: Integer;
begin
  AList.Clear;
  Connect;
  TargetDB := SanitizeSchema(ADBName);
  TableDDL := GetTableDDL(TargetDB, ASchema, ATable);
  CleanDDL := UpperCase(TableDDL);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.ParamCheck := False;
    Qry.SQL.Text := Format('PRAGMA %s.table_info(%s);', [TargetDB, QuoteIdentifier(ATable)]);
    Qry.Open;

    while not Qry.EOF do
    begin
      Col := TSchemaColumn.Create;
      Col.OrdinalPosition := Qry.FieldByName('cid').AsInteger + 1;
      Col.Name := Qry.FieldByName('name').AsString;

      ParseDataTypeParameters(Qry.FieldByName('type').AsString, BaseType, Len, Prec, Scale);
      if BaseType <> '' then
        Col.DataType := BaseType
      else
        Col.DataType := 'TEXT';

      Col.Length := Len;
      Col.Precision := Prec;
      Col.Scale := Scale;

      Col.IsNullable := (Qry.FieldByName('notnull').AsInteger = 0);
      Col.IsPrimaryKey := (Qry.FieldByName('pk').AsInteger > 0);
      Col.DefaultValue := Qry.FieldByName('dflt_value').AsString;

      // Deteksi Autoincrement
      if Col.IsPrimaryKey and (Pos('AUTOINCREMENT', CleanDDL) > 0) and
         (Pos(UpperCase(Col.Name), CleanDDL) > 0) then
        Col.IsAutoIncrement := True;

      AList.Add(Col);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TDriverSQLite.ExtractIndexes(const ADBName, ASchema, ATable: string; AList: TSchemaIndexList);
var
  QryList, QryInfo: TZQuery;
  Idx: TSchemaIndex;
  TargetDB, IdxName: string;
begin
  AList.Clear;
  Connect;
  TargetDB := SanitizeSchema(ADBName);

  QryList := TZQuery.Create(nil);
  QryInfo := TZQuery.Create(nil);
  try
    QryList.Connection := FConnection;
    QryList.ParamCheck := False;
    QryInfo.Connection := FConnection;
    QryInfo.ParamCheck := False;

    QryList.SQL.Text := Format('PRAGMA %s.index_list(%s);', [TargetDB, QuoteIdentifier(ATable)]);
    QryList.Open;

    while not QryList.EOF do
    begin
      IdxName := QryList.FieldByName('name').AsString;
      Idx := TSchemaIndex.Create;
      Idx.Name := IdxName;
      Idx.TableName := ATable;
      Idx.IsUnique := (QryList.FieldByName('unique').AsInteger = 1);
      Idx.IsPrimary := (QryList.FieldByName('origin').AsString = 'pk');
      Idx.IndexType := 'BTREE';

      // Mengambil daftar kolom untuk indeks terkait
      QryInfo.Close;
      QryInfo.SQL.Text := Format('PRAGMA %s.index_info(%s);', [TargetDB, QuoteIdentifier(IdxName)]);
      QryInfo.Open;

      while not QryInfo.EOF do
      begin
        Idx.Columns.Add(QryInfo.FieldByName('name').AsString);
        QryInfo.Next;
      end;

      AList.Add(Idx);
      QryList.Next;
    end;
  finally
    QryInfo.Free;
    QryList.Free;
  end;
end;

procedure TDriverSQLite.ExtractForeignKeys(const ADBName, ASchema, ATable: string; AList: TSchemaForeignKeyList);
var
  Qry: TZQuery;
  FK: TSchemaForeignKey;
  TargetDB: string;
  CurrentID: Integer;
begin
  AList.Clear;
  Connect;
  TargetDB := SanitizeSchema(ADBName);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.ParamCheck := False;
    Qry.SQL.Text := Format('PRAGMA %s.foreign_key_list(%s);', [TargetDB, QuoteIdentifier(ATable)]);
    Qry.Open;

    FK := nil;
    CurrentID := -1;

    while not Qry.EOF do
    begin
      if Qry.FieldByName('id').AsInteger <> CurrentID then
      begin
        CurrentID := Qry.FieldByName('id').AsInteger;
        FK := TSchemaForeignKey.Create;
        FK.Name := Format('fk_%s_%s_%d', [ATable, Qry.FieldByName('table').AsString, CurrentID]);
        FK.TableName := ATable;
        FK.RefTableName := Qry.FieldByName('table').AsString;
        FK.OnUpdate := Qry.FieldByName('on_update').AsString;
        FK.OnDelete := Qry.FieldByName('on_delete').AsString;
        AList.Add(FK);
      end;

      if Assigned(FK) then
      begin
        FK.ColumnNames.Add(Qry.FieldByName('from').AsString);
        FK.RefColumnNames.Add(Qry.FieldByName('to').AsString);
      end;

      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

function TDriverSQLite.GetTableDDL(const ADBName, ASchema, ATable: string): string;
var
  Qry: TZQuery;
  TargetDB: string;
begin
  Result := '';
  Connect;
  TargetDB := SanitizeSchema(ADBName);

  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text := Format(
      'SELECT sql FROM %s.sqlite_master WHERE type = ''table'' AND name = :tbl LIMIT 1;',
      [TargetDB]
    );
    Qry.ParamByName('tbl').AsString := ATable;
    Qry.Open;
    if not Qry.IsEmpty then
    begin
      Result := Qry.FieldByName('sql').AsString;
      if (Result <> '') and not Result.EndsWith(';') then
        Result := Result + ';';
    end;
  finally
    Qry.Free;
  end;
end;

function TDriverSQLite.GetExplainPlan(const ASQL: string; var APlan: TDBExecutionPlanArray): Boolean;
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
    Qry.ParamCheck := False;
    Qry.SQL.Text := 'EXPLAIN QUERY PLAN ' + ASQL;
    Qry.Open;

    while not Qry.EOF do
    begin
      Idx := Length(APlan);
      SetLength(APlan, Idx + 1);

      APlan[Idx].ID := Qry.Fields[0].AsInteger;
      APlan[Idx].ParentID := Qry.Fields[1].AsInteger;
      APlan[Idx].Operation := 'QUERY PLAN';

      if Qry.FieldCount >= 4 then
        APlan[Idx].Details := Qry.Fields[3].AsString
      else
        APlan[Idx].Details := Qry.Fields[2].AsString;

      APlan[Idx].TargetObject := '';
      APlan[Idx].Cost := 0;
      APlan[Idx].EstimatedRows := 0;
      APlan[Idx].ActualRows := 0;

      Qry.Next;
    end;

    Result := Length(APlan) > 0;
  except
    Result := False;
  end;
  Qry.Free;
end;

end.
