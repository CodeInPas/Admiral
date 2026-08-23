unit uMetadataExtractor;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  uAppTypes, uDBTypes, uDBDriverBase, uModelSchemaObject;

type
  { TMetadataExtractor }
  TMetadataExtractor = class
  private
    FDriver: TDBDriverBase;
    FOnProgress: TProgressProcedure;
    FOnLog: TLogProcedure;

    procedure DoLog(const AMessage: string);
    procedure DoProgress(const ACurrent, AMax: Int64; const AMessage: string);
    function CreateGroupNode(AParent: TSchemaObject; const AName: string; const AType: TSchemaObjectType): TSchemaObject;
  public
    constructor Create(ADriver: TDBDriverBase);

    // Operasi Ekstraksi Hirarki
    procedure ExtractAllDatabases(ARootNode: TSchemaObject);
    procedure ExtractDatabaseObjects(ADatabaseNode: TSchemaObject);
    procedure ExtractSchemaObjects(ASchemaNode: TSchemaObject; const ADBName, ASchemaName: string);
    procedure PopulateTableDetails(ATableNode: TSchemaObject);

    property Driver: TDBDriverBase read FDriver write FDriver;
    property OnProgress: TProgressProcedure read FOnProgress write FOnProgress;
    property OnLog: TLogProcedure read FOnLog write FOnLog;
  end;

implementation

{ TMetadataExtractor }

constructor TMetadataExtractor.Create(ADriver: TDBDriverBase);
begin
  inherited Create;
  FDriver := ADriver;
end;

procedure TMetadataExtractor.DoLog(const AMessage: string);
begin
  if Assigned(FOnLog) then
    FOnLog(AMessage);
end;

procedure TMetadataExtractor.DoProgress(const ACurrent, AMax: Int64; const AMessage: string);
begin
  if Assigned(FOnProgress) then
    FOnProgress(ACurrent, AMax, AMessage);
end;

function TMetadataExtractor.CreateGroupNode(AParent: TSchemaObject; const AName: string; const AType: TSchemaObjectType): TSchemaObject;
begin
  Result := TSchemaObject.Create;
  Result.Name := AName;
  Result.ObjectType := AType;
  Result.DatabaseName := AParent.DatabaseName;
  Result.SchemaName := AParent.SchemaName;
  Result.Parent := AParent;
  AParent.Children.Add(Result);
end;

procedure TMetadataExtractor.ExtractAllDatabases(ARootNode: TSchemaObject);
var
  DBList: TStringList;
  DBNode: TSchemaObject;
  I: Integer;
begin
  if not Assigned(FDriver) or not Assigned(ARootNode) then Exit;

  ARootNode.Children.Clear;
  DBList := TStringList.Create;
  try
    DoLog('Memulai ekstraksi daftar database...');

    if dbcMultipleDatabases in FDriver.GetCapabilities then
      FDriver.ExtractDatabases(DBList)
    else
      DBList.Add(FDriver.Profile.DatabaseName);

    for I := 0 to DBList.Count - 1 do
    begin
      DBNode := TSchemaObject.Create;
      DBNode.Name := DBList[I];
      DBNode.DatabaseName := DBList[I];
      DBNode.ObjectType := sotDatabase;
      DBNode.Parent := ARootNode;
      ARootNode.Children.Add(DBNode);

      DoProgress(I + 1, DBList.Count, Format('Database ditemukan: %s', [DBList[I]]));
    end;
  finally
    DBList.Free;
  end;
end;

procedure TMetadataExtractor.ExtractDatabaseObjects(ADatabaseNode: TSchemaObject);
var
  SchemaList: TStringList;
  SchemaNode: TSchemaObject;
  I: Integer;
begin
  if not Assigned(FDriver) or not Assigned(ADatabaseNode) then Exit;

  ADatabaseNode.Children.Clear;
  SchemaList := TStringList.Create;
  try
    if dbcSchemas in FDriver.GetCapabilities then
    begin
      DoLog(Format('Mengekstrak skema untuk database [%s]...', [ADatabaseNode.Name]));
      FDriver.ExtractSchemas(ADatabaseNode.Name, SchemaList);

      for I := 0 to SchemaList.Count - 1 do
      begin
        SchemaNode := TSchemaObject.Create;
        SchemaNode.Name := SchemaList[I];
        SchemaNode.DatabaseName := ADatabaseNode.Name;
        SchemaNode.SchemaName := SchemaList[I];
        SchemaNode.ObjectType := sotSchema;
        SchemaNode.Parent := ADatabaseNode;
        ADatabaseNode.Children.Add(SchemaNode);

        ExtractSchemaObjects(SchemaNode, ADatabaseNode.Name, SchemaList[I]);
      end;
    end
    else
    begin
      // DBMS tanpa level skema (e.g. MySQL, SQLite)
      ExtractSchemaObjects(ADatabaseNode, ADatabaseNode.Name, '');
    end;
  finally
    SchemaList.Free;
  end;
end;

procedure TMetadataExtractor.ExtractSchemaObjects(ASchemaNode: TSchemaObject; const ADBName, ASchemaName: string);
var
  Caps: TDBCapabilities;
  GroupNode: TSchemaObject;
begin
  if not Assigned(FDriver) or not Assigned(ASchemaNode) then Exit;

  Caps := FDriver.GetCapabilities;

  // 1. Tables Group
  GroupNode := CreateGroupNode(ASchemaNode, 'Tables', sotTableGroup);
  FDriver.ExtractTables(ADBName, ASchemaName, GroupNode.Children);

  // 2. Views Group
  GroupNode := CreateGroupNode(ASchemaNode, 'Views', sotViewGroup);
  FDriver.ExtractViews(ADBName, ASchemaName, GroupNode.Children);

  // 3. Stored Procedures Group
  if dbcStoredProcedures in Caps then
  begin
    GroupNode := CreateGroupNode(ASchemaNode, 'Procedures', sotProcGroup);
    FDriver.ExtractProcedures(ADBName, ASchemaName, GroupNode.Children);
  end;

  // 4. Functions Group
  if dbcFunctions in Caps then
  begin
    GroupNode := CreateGroupNode(ASchemaNode, 'Functions', sotFunctionGroup);
    FDriver.ExtractFunctions(ADBName, ASchemaName, GroupNode.Children);
  end;

  // 5. Triggers Group
  if dbcTriggers in Caps then
  begin
    GroupNode := CreateGroupNode(ASchemaNode, 'Triggers', sotTriggerGroup);
    FDriver.ExtractTriggers(ADBName, ASchemaName, GroupNode.Children);
  end;

  // 6. Sequences Group
  if dbcSequences in Caps then
  begin
    GroupNode := CreateGroupNode(ASchemaNode, 'Sequences', sotSequenceGroup);
    FDriver.ExtractSequences(ADBName, ASchemaName, GroupNode.Children);
  end;
end;

procedure TMetadataExtractor.PopulateTableDetails(ATableNode: TSchemaObject);
begin
  if not Assigned(FDriver) or not Assigned(ATableNode) then Exit;

  DoLog(Format('Memuat detail struktur tabel [%s]...', [ATableNode.Name]));

  // Ekstrak detail kolom, indeks, foreign key, dan DDL
  FDriver.ExtractColumns(ATableNode.DatabaseName, ATableNode.SchemaName, ATableNode.Name, ATableNode.Columns);
  FDriver.ExtractIndexes(ATableNode.DatabaseName, ATableNode.SchemaName, ATableNode.Name, ATableNode.Indexes);

  if dbcForeignKeys in FDriver.GetCapabilities then
    FDriver.ExtractForeignKeys(ATableNode.DatabaseName, ATableNode.SchemaName, ATableNode.Name, ATableNode.ForeignKeys);

  ATableNode.DDL := FDriver.GetTableDDL(ATableNode.DatabaseName, ATableNode.SchemaName, ATableNode.Name);
end;

end.
