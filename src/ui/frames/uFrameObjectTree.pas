unit uFrameObjectTree;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ComCtrls,
  ExtCtrls, StdCtrls, Buttons, Menus, Clipbrd,
  ZConnection, uFormExportDialog,
  uAppTypes, uDBTypes, uModelConnection, uModelSchemaObject,
  uDBDriverBase, uDBConnectionFactory, uFormTableBuilder;

type
  { TTreeObjectNodeType }
  TTreeObjectNodeType = (
    tntRootConnection,
    tntDatabase,
    tntSchema,
    tntGroupTables,
    tntGroupViews,
    tntGroupProcedures,
    tntGroupFunctions,
    tntGroupTriggers,
    tntGroupSequences,
    tntTable,
    tntView,
    tntProcedure,
    tntFunction,
    tntTrigger,
    tntSequence,
    tntGroupColumns,
    tntGroupIndexes,
    tntGroupForeignKeys,
    tntColumn,
    tntIndex,
    tntForeignKey
  );

  { TTreeObjectData }
  TTreeObjectData = class
  public
    NodeType: TTreeObjectNodeType;
    Profile: TConnectionProfile;
    DatabaseName: string;
    SchemaName: string;
    ObjectName: string;
    ExtraInfo: string;
    IsLoaded: Boolean;
    constructor Create(ANodeType: TTreeObjectNodeType; AProfile: TConnectionProfile = nil;
      const ADBName: string = ''; const ASchema: string = ''; const AObjName: string = '';
      const AExtra: string = '');
    destructor Destroy; override;
  end;

  { Definisi Event Eksternal }
  TNodeSelectEvent = procedure(Sender: TObject; ANodeData: TTreeObjectData) of object;
  TOpenQueryEvent = procedure(Sender: TObject; AProfile: TConnectionProfile; const ADBName, AInitialSQL: string) of object;
  TShowDataEvent = procedure(Sender: TObject; AProfile: TConnectionProfile; const ADBName, ASchema, ATableName: string) of object;
  TShowDDLEvent = procedure(Sender: TObject; AProfile: TConnectionProfile; const ADBName, ASchema, ATableName: string) of object;

  { TFrameObjectTree }
  TFrameObjectTree = class(TFrame)
    ilTree: TImageList;
    pnlToolbar: TPanel;
    edtFilter: TEdit;
    btnClearFilter: TSpeedButton;
    btnRefreshAll: TSpeedButton;
    tvObjects: TTreeView;

    // Menu Konteks
    popTree: TPopupMenu;
    mnuEditObject: TMenuItem;
    mnuOpenQuery: TMenuItem;
    mnuViewDataTop100: TMenuItem;
    mnuViewDDL: TMenuItem;
    mnuSep1: TMenuItem;
    mnuDropObject: TMenuItem;
    mnuTruncateTable: TMenuItem;
    mnuSep2: TMenuItem;
    mnuCreateNew: TMenuItem;
    mnuNewDatabase: TMenuItem;
    mnuNewTable: TMenuItem;
    mnuNewCopyTable: TMenuItem;
    mnuNewView: TMenuItem;
    mnuNewProcedure: TMenuItem;
    mnuNewFunction: TMenuItem;
    mnuNewTrigger: TMenuItem;
    mnuMaintenance: TMenuItem;
    mnuMaintOptimize: TMenuItem;
    mnuMaintAnalyze: TMenuItem;
    mnuMaintCheck: TMenuItem;
    mnuSep3: TMenuItem;
    mnuExportSQL: TMenuItem;
    mnuSep4: TMenuItem;
    mnuCopyName: TMenuItem;
    mnuRefreshNode: TMenuItem;
    mnuExpandAll: TMenuItem;
    mnuCollapseAll: TMenuItem;

    procedure btnClearFilterClick(Sender: TObject);
    procedure btnRefreshAllClick(Sender: TObject);
    procedure edtFilterChange(Sender: TObject);
    procedure tvObjectsExpanding(Sender: TObject; Node: TTreeNode; var AllowExpansion: Boolean);
    procedure tvObjectsSelectionChanged(Sender: TObject);
    procedure tvObjectsDblClick(Sender: TObject);
    procedure tvObjectsDeletion(Sender: TObject; Node: TTreeNode);
    procedure popTreePopup(Sender: TObject);

    // Event Handlers Menu Konteks
    procedure mnuEditObjectClick(Sender: TObject);
    procedure mnuOpenQueryClick(Sender: TObject);
    procedure mnuViewDataTop100Click(Sender: TObject);
    procedure mnuViewDDLClick(Sender: TObject);
    procedure mnuDropObjectClick(Sender: TObject);
    procedure mnuTruncateTableClick(Sender: TObject);
    procedure mnuNewDatabaseClick(Sender: TObject);
    procedure mnuNewTableClick(Sender: TObject);
    procedure mnuNewCopyTableClick(Sender: TObject);
    procedure mnuNewViewClick(Sender: TObject);
    procedure mnuNewProcedureClick(Sender: TObject);
    procedure mnuNewFunctionClick(Sender: TObject);
    procedure mnuNewTriggerClick(Sender: TObject);
    procedure mnuMaintOptimizeClick(Sender: TObject);
    procedure mnuMaintAnalyzeClick(Sender: TObject);
    procedure mnuMaintCheckClick(Sender: TObject);
    procedure mnuExportSQLClick(Sender: TObject);
    procedure mnuCopyNameClick(Sender: TObject);
    procedure mnuRefreshNodeClick(Sender: TObject);
    procedure mnuExpandAllClick(Sender: TObject);
    procedure mnuCollapseAllClick(Sender: TObject);
  private
    FProfile: TConnectionProfile;
    FOnNodeSelected: TNodeSelectEvent;
    FOnOpenQueryTab: TOpenQueryEvent;
    FOnShowTableData: TShowDataEvent;
    FOnShowTableDDL: TShowDDLEvent;

    procedure AddDummyChild(AParent: TTreeNode);
    function CreateNode(AParent: TTreeNode; const AText: string; ANodeType: TTreeObjectNodeType;
      const ADBName: string = ''; const ASchema: string = ''; const AObjName: string = '';
      const AExtra: string = ''): TTreeNode;

    procedure LoadDatabases(ARootNode: TTreeNode);
    procedure LoadSchemas(ADatabaseNode: TTreeNode);
    procedure LoadCategoryGroups(AParentNode: TTreeNode; const ADBName, ASchema: string);
    procedure LoadTables(AGroupNode: TTreeNode);
    procedure LoadViews(AGroupNode: TTreeNode);
    procedure LoadProcedures(AGroupNode: TTreeNode);
    procedure LoadFunctions(AGroupNode: TTreeNode);
    procedure LoadTriggers(AGroupNode: TTreeNode);
    procedure LoadSequences(AGroupNode: TTreeNode);
    procedure LoadTableDetails(ATableNode: TTreeNode);
    procedure LoadColumns(AGroupNode: TTreeNode);
    procedure LoadIndexes(AGroupNode: TTreeNode);
    procedure LoadForeignKeys(AGroupNode: TTreeNode);

    function GetNodeData(ANode: TTreeNode): TTreeObjectData;
    procedure RefreshNode(ANode: TTreeNode);
    function ExecuteDirectSQL(const ASQL: string; const ADBName: string = ''): Boolean;
    procedure ExecuteMaintenanceCommand(const ACommandType: string; const ATableName: string);
    function GetNodeIconIndex(const ANodeType: TTreeObjectNodeType; const AExtra: string): Integer;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure SetConnectionProfile(AProfile: TConnectionProfile);
    procedure RefreshTree;
    procedure Clear;

    property Profile: TConnectionProfile read FProfile;
    property OnNodeSelected: TNodeSelectEvent read FOnNodeSelected write FOnNodeSelected;
    property OnOpenQueryTab: TOpenQueryEvent read FOnOpenQueryTab write FOnOpenQueryTab;
    property OnShowTableData: TShowDataEvent read FOnShowTableData write FOnShowTableData;
    property OnShowTableDDL: TShowDDLEvent read FOnShowTableDDL write FOnShowTableDDL;
  end;

implementation

{$R *.lfm}

{ TTreeObjectData }

constructor TTreeObjectData.Create(ANodeType: TTreeObjectNodeType; AProfile: TConnectionProfile;
  const ADBName, ASchema, AObjName, AExtra: string);
begin
  inherited Create;
  NodeType := ANodeType;
  Profile := AProfile;
  DatabaseName := ADBName;
  SchemaName := ASchema;
  ObjectName := AObjName;
  ExtraInfo := AExtra;
  IsLoaded := False;
end;

destructor TTreeObjectData.Destroy;
begin
  inherited Destroy;
end;

{ TFrameObjectTree }

constructor TFrameObjectTree.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FProfile := TConnectionProfile.Create;
  tvObjects.PopupMenu := popTree;
  tvObjects.Images := ilTree;
  Clear;
end;

destructor TFrameObjectTree.Destroy;
begin
  Clear;
  FreeAndNil(FProfile);
  inherited Destroy;
end;

procedure TFrameObjectTree.Clear;
begin
  tvObjects.Items.Clear;
  edtFilter.Clear;
end;

function TFrameObjectTree.GetNodeData(ANode: TTreeNode): TTreeObjectData;
begin
  if Assigned(ANode) and Assigned(ANode.Data) then
    Result := TTreeObjectData(ANode.Data)
  else
    Result := nil;
end;

procedure TFrameObjectTree.AddDummyChild(AParent: TTreeNode);
begin
  tvObjects.Items.AddChild(AParent, 'Memuat...');
end;

function TFrameObjectTree.GetNodeIconIndex(const ANodeType: TTreeObjectNodeType; const AExtra: string): Integer;
begin
  case ANodeType of
    tntRootConnection: Result := 0;
    tntDatabase,
    tntSchema:         Result := 1;

    tntGroupTables,
    tntGroupViews,
    tntGroupProcedures,
    tntGroupFunctions,
    tntGroupTriggers,
    tntGroupSequences,
    tntGroupColumns,
    tntGroupIndexes,
    tntGroupForeignKeys: Result := 2;

    tntTable:          Result := 3;
    tntView:           Result := 4;
    tntProcedure,
    tntFunction:       Result := 5;
    tntTrigger:        Result := 6;

    tntColumn:
    begin
      if SameText(AExtra, 'PK') then
        Result := 8
      else
        Result := 7;
    end;

    tntIndex:          Result := 9;
    tntForeignKey:     Result := 10;
    tntSequence:       Result := 5;
    else               Result := -1;
  end;
end;

function TFrameObjectTree.CreateNode(AParent: TTreeNode; const AText: string; ANodeType: TTreeObjectNodeType;
  const ADBName, ASchema, AObjName, AExtra: string): TTreeNode;
var
  Data: TTreeObjectData;
  IconIdx: Integer;
begin
  Data := TTreeObjectData.Create(ANodeType, FProfile, ADBName, ASchema, AObjName, AExtra);
  Result := tvObjects.Items.AddChildObject(AParent, AText, Data);

  IconIdx := GetNodeIconIndex(ANodeType, AExtra);
  Result.ImageIndex := IconIdx;
  Result.SelectedIndex := IconIdx;
end;

procedure TFrameObjectTree.SetConnectionProfile(AProfile: TConnectionProfile);
begin
  if not Assigned(AProfile) then
  begin
    Clear;
    Exit;
  end;

  FProfile.Assign(AProfile);
  RefreshTree;
end;

procedure TFrameObjectTree.RefreshTree;
var
  RootNode: TTreeNode;
begin
  tvObjects.BeginUpdate;
  try
    tvObjects.Items.Clear;
    if FProfile.ConnectionName = '' then Exit;

    RootNode := CreateNode(nil, FProfile.GetDisplayName, tntRootConnection, FProfile.DatabaseName);
    AddDummyChild(RootNode);
    RootNode.Expand(False);
  finally
    tvObjects.EndUpdate;
  end;
end;

procedure TFrameObjectTree.LoadDatabases(ARootNode: TTreeNode);
var
  Driver: TDBDriverBase;
  DBList: TStringList;
  I: Integer;
  DBNode: TTreeNode;
begin
  Driver := nil;
  DBList := TStringList.Create;
  try
    Driver := TDBConnectionFactory.CreateDriver(FProfile);
    if dbcMultipleDatabases in Driver.GetCapabilities then
      Driver.ExtractDatabases(DBList)
    else if FProfile.DatabaseName <> '' then
      DBList.Add(FProfile.DatabaseName)
    else
      DBList.Add('main');

    for I := 0 to DBList.Count - 1 do
    begin
      DBNode := CreateNode(ARootNode, DBList[I], tntDatabase, DBList[I]);
      AddDummyChild(DBNode);
    end;
  finally
    DBList.Free;
    if Assigned(Driver) then
      Driver.Free;
  end;
end;

procedure TFrameObjectTree.LoadSchemas(ADatabaseNode: TTreeNode);
var
  Data: TTreeObjectData;
  Driver: TDBDriverBase;
  SchemaList: TStringList;
  I: Integer;
  SchemaNode: TTreeNode;
begin
  Data := GetNodeData(ADatabaseNode);
  if not Assigned(Data) then Exit;

  Driver := nil;
  SchemaList := TStringList.Create;
  try
    Driver := TDBConnectionFactory.CreateDriver(FProfile);
    if dbcSchemas in Driver.GetCapabilities then
    begin
      Driver.ExtractSchemas(Data.DatabaseName, SchemaList);
      for I := 0 to SchemaList.Count - 1 do
      begin
        SchemaNode := CreateNode(ADatabaseNode, SchemaList[I], tntSchema, Data.DatabaseName, SchemaList[I]);
        AddDummyChild(SchemaNode);
      end;
    end
    else
    begin
      LoadCategoryGroups(ADatabaseNode, Data.DatabaseName, '');
    end;
  finally
    SchemaList.Free;
    if Assigned(Driver) then
      Driver.Free;
  end;
end;

procedure TFrameObjectTree.LoadCategoryGroups(AParentNode: TTreeNode; const ADBName, ASchema: string);
var
  Driver: TDBDriverBase;
  Caps: TDBCapabilities;
  GrpNode: TTreeNode;
begin
  Driver := nil;
  try
    Driver := TDBConnectionFactory.CreateDriver(FProfile);
    Caps := Driver.GetCapabilities;

    GrpNode := CreateNode(AParentNode, 'Tables', tntGroupTables, ADBName, ASchema);
    AddDummyChild(GrpNode);

    GrpNode := CreateNode(AParentNode, 'Views', tntGroupViews, ADBName, ASchema);
    AddDummyChild(GrpNode);

    if dbcStoredProcedures in Caps then
    begin
      GrpNode := CreateNode(AParentNode, 'Procedures', tntGroupProcedures, ADBName, ASchema);
      AddDummyChild(GrpNode);
    end;

    if dbcFunctions in Caps then
    begin
      GrpNode := CreateNode(AParentNode, 'Functions', tntGroupFunctions, ADBName, ASchema);
      AddDummyChild(GrpNode);
    end;

    if dbcTriggers in Caps then
    begin
      GrpNode := CreateNode(AParentNode, 'Triggers', tntGroupTriggers, ADBName, ASchema);
      AddDummyChild(GrpNode);
    end;

    if dbcSequences in Caps then
    begin
      GrpNode := CreateNode(AParentNode, 'Sequences', tntGroupSequences, ADBName, ASchema);
      AddDummyChild(GrpNode);
    end;
  finally
    if Assigned(Driver) then
      Driver.Free;
  end;
end;

procedure TFrameObjectTree.LoadTables(AGroupNode: TTreeNode);
var
  Data: TTreeObjectData;
  Driver: TDBDriverBase;
  ObjList: TSchemaObjectList;
  I: Integer;
  TblNode: TTreeNode;
begin
  Data := GetNodeData(AGroupNode);
  if not Assigned(Data) then Exit;

  ObjList := TSchemaObjectList.Create(True);
  Driver := nil;
  try
    Driver := TDBConnectionFactory.CreateDriver(FProfile);
    Driver.ExtractTables(Data.DatabaseName, Data.SchemaName, ObjList);

    for I := 0 to ObjList.Count - 1 do
    begin
      TblNode := CreateNode(AGroupNode, ObjList[I].Name, tntTable, Data.DatabaseName, Data.SchemaName, ObjList[I].Name);
      AddDummyChild(TblNode);
    end;
  finally
    ObjList.Free;
    if Assigned(Driver) then
      Driver.Free;
  end;
end;

procedure TFrameObjectTree.LoadViews(AGroupNode: TTreeNode);
var
  Data: TTreeObjectData;
  Driver: TDBDriverBase;
  ObjList: TSchemaObjectList;
  I: Integer;
begin
  Data := GetNodeData(AGroupNode);
  if not Assigned(Data) then Exit;

  ObjList := TSchemaObjectList.Create(True);
  Driver := nil;
  try
    Driver := TDBConnectionFactory.CreateDriver(FProfile);
    Driver.ExtractViews(Data.DatabaseName, Data.SchemaName, ObjList);

    for I := 0 to ObjList.Count - 1 do
      CreateNode(AGroupNode, ObjList[I].Name, tntView, Data.DatabaseName, Data.SchemaName, ObjList[I].Name);
  finally
    ObjList.Free;
    if Assigned(Driver) then
      Driver.Free;
  end;
end;

procedure TFrameObjectTree.LoadProcedures(AGroupNode: TTreeNode);
var
  Data: TTreeObjectData;
  Driver: TDBDriverBase;
  ObjList: TSchemaObjectList;
  I: Integer;
begin
  Data := GetNodeData(AGroupNode);
  if not Assigned(Data) then Exit;

  ObjList := TSchemaObjectList.Create(True);
  Driver := nil;
  try
    Driver := TDBConnectionFactory.CreateDriver(FProfile);
    Driver.ExtractProcedures(Data.DatabaseName, Data.SchemaName, ObjList);

    for I := 0 to ObjList.Count - 1 do
      CreateNode(AGroupNode, ObjList[I].Name, tntProcedure, Data.DatabaseName, Data.SchemaName, ObjList[I].Name);
  finally
    ObjList.Free;
    if Assigned(Driver) then
      Driver.Free;
  end;
end;

procedure TFrameObjectTree.LoadFunctions(AGroupNode: TTreeNode);
var
  Data: TTreeObjectData;
  Driver: TDBDriverBase;
  ObjList: TSchemaObjectList;
  I: Integer;
begin
  Data := GetNodeData(AGroupNode);
  if not Assigned(Data) then Exit;

  ObjList := TSchemaObjectList.Create(True);
  Driver := nil;
  try
    Driver := TDBConnectionFactory.CreateDriver(FProfile);
    Driver.ExtractFunctions(Data.DatabaseName, Data.SchemaName, ObjList);

    for I := 0 to ObjList.Count - 1 do
      CreateNode(AGroupNode, ObjList[I].Name, tntFunction, Data.DatabaseName, Data.SchemaName, ObjList[I].Name);
  finally
    ObjList.Free;
    if Assigned(Driver) then
      Driver.Free;
  end;
end;

procedure TFrameObjectTree.LoadTriggers(AGroupNode: TTreeNode);
var
  Data: TTreeObjectData;
  Driver: TDBDriverBase;
  ObjList: TSchemaObjectList;
  I: Integer;
begin
  Data := GetNodeData(AGroupNode);
  if not Assigned(Data) then Exit;

  ObjList := TSchemaObjectList.Create(True);
  Driver := nil;
  try
    Driver := TDBConnectionFactory.CreateDriver(FProfile);
    Driver.ExtractTriggers(Data.DatabaseName, Data.SchemaName, ObjList);

    for I := 0 to ObjList.Count - 1 do
      CreateNode(AGroupNode, ObjList[I].Name, tntTrigger, Data.DatabaseName, Data.SchemaName, ObjList[I].Name);
  finally
    ObjList.Free;
    if Assigned(Driver) then
      Driver.Free;
  end;
end;

procedure TFrameObjectTree.LoadSequences(AGroupNode: TTreeNode);
var
  Data: TTreeObjectData;
  Driver: TDBDriverBase;
  ObjList: TSchemaObjectList;
  I: Integer;
begin
  Data := GetNodeData(AGroupNode);
  if not Assigned(Data) then Exit;

  ObjList := TSchemaObjectList.Create(True);
  Driver := nil;
  try
    Driver := TDBConnectionFactory.CreateDriver(FProfile);
    Driver.ExtractSequences(Data.DatabaseName, Data.SchemaName, ObjList);

    for I := 0 to ObjList.Count - 1 do
      CreateNode(AGroupNode, ObjList[I].Name, tntSequence, Data.DatabaseName, Data.SchemaName, ObjList[I].Name);
  finally
    ObjList.Free;
    if Assigned(Driver) then
      Driver.Free;
  end;
end;

procedure TFrameObjectTree.LoadTableDetails(ATableNode: TTreeNode);
var
  Data: TTreeObjectData;
  GrpNode: TTreeNode;
begin
  Data := GetNodeData(ATableNode);
  if not Assigned(Data) then Exit;

  GrpNode := CreateNode(ATableNode, 'Columns', tntGroupColumns, Data.DatabaseName, Data.SchemaName, Data.ObjectName);
  AddDummyChild(GrpNode);

  GrpNode := CreateNode(ATableNode, 'Indexes', tntGroupIndexes, Data.DatabaseName, Data.SchemaName, Data.ObjectName);
  AddDummyChild(GrpNode);

  GrpNode := CreateNode(ATableNode, 'Foreign Keys', tntGroupForeignKeys, Data.DatabaseName, Data.SchemaName, Data.ObjectName);
  AddDummyChild(GrpNode);
end;

procedure TFrameObjectTree.LoadColumns(AGroupNode: TTreeNode);
var
  Data: TTreeObjectData;
  Driver: TDBDriverBase;
  ColList: TSchemaColumnList;
  I: Integer;
  ColDisplay, ExtraPK: string;
begin
  Data := GetNodeData(AGroupNode);
  if not Assigned(Data) then Exit;

  ColList := TSchemaColumnList.Create(True);
  Driver := nil;
  try
    Driver := TDBConnectionFactory.CreateDriver(FProfile);
    Driver.ExtractColumns(Data.DatabaseName, Data.SchemaName, Data.ObjectName, ColList);

    for I := 0 to ColList.Count - 1 do
    begin
      ColDisplay := Format('%s (%s)', [ColList[I].Name, ColList[I].DataType]);
      if ColList[I].IsPrimaryKey then
      begin
        ColDisplay := '[PK] ' + ColDisplay;
        ExtraPK := 'PK';
      end
      else
        ExtraPK := '';

      CreateNode(AGroupNode, ColDisplay, tntColumn, Data.DatabaseName, Data.SchemaName, ColList[I].Name, ExtraPK);
    end;
  finally
    ColList.Free;
    if Assigned(Driver) then
      Driver.Free;
  end;
end;

procedure TFrameObjectTree.LoadIndexes(AGroupNode: TTreeNode);
var
  Data: TTreeObjectData;
  Driver: TDBDriverBase;
  IdxList: TSchemaIndexList;
  I: Integer;
  IdxDisplay: string;
begin
  Data := GetNodeData(AGroupNode);
  if not Assigned(Data) then Exit;

  IdxList := TSchemaIndexList.Create(True);
  Driver := nil;
  try
    Driver := TDBConnectionFactory.CreateDriver(FProfile);
    Driver.ExtractIndexes(Data.DatabaseName, Data.SchemaName, Data.ObjectName, IdxList);

    for I := 0 to IdxList.Count - 1 do
    begin
      IdxDisplay := IdxList[I].Name;
      if IdxList[I].IsUnique then
        IdxDisplay := '[UQ] ' + IdxDisplay;
      CreateNode(AGroupNode, IdxDisplay, tntIndex, Data.DatabaseName, Data.SchemaName, IdxList[I].Name);
    end;
  finally
    IdxList.Free;
    if Assigned(Driver) then
      Driver.Free;
  end;
end;

procedure TFrameObjectTree.LoadForeignKeys(AGroupNode: TTreeNode);
var
  Data: TTreeObjectData;
  Driver: TDBDriverBase;
  FKList: TSchemaForeignKeyList;
  I: Integer;
  FKDisplay: string;
begin
  Data := GetNodeData(AGroupNode);
  if not Assigned(Data) then Exit;

  FKList := TSchemaForeignKeyList.Create(True);
  Driver := nil;
  try
    Driver := TDBConnectionFactory.CreateDriver(FProfile);
    Driver.ExtractForeignKeys(Data.DatabaseName, Data.SchemaName, Data.ObjectName, FKList);

    for I := 0 to FKList.Count - 1 do
    begin
      FKDisplay := Format('%s -> %s', [FKList[I].Name, FKList[I].RefTableName]);
      CreateNode(AGroupNode, FKDisplay, tntForeignKey, Data.DatabaseName, Data.SchemaName, FKList[I].Name);
    end;
  finally
    FKList.Free;
    if Assigned(Driver) then
      Driver.Free;
  end;
end;

procedure TFrameObjectTree.tvObjectsExpanding(Sender: TObject; Node: TTreeNode; var AllowExpansion: Boolean);
var
  Data: TTreeObjectData;
begin
  Data := GetNodeData(Node);
  if not Assigned(Data) or Data.IsLoaded then Exit;

  tvObjects.BeginUpdate;
  Screen.Cursor := crHourGlass;
  try
    Node.DeleteChildren;
    case Data.NodeType of
      tntRootConnection:    LoadDatabases(Node);
      tntDatabase:          LoadSchemas(Node);
      tntSchema:            LoadCategoryGroups(Node, Data.DatabaseName, Data.SchemaName);
      tntGroupTables:       LoadTables(Node);
      tntGroupViews:        LoadViews(Node);
      tntGroupProcedures:   LoadProcedures(Node);
      tntGroupFunctions:    LoadFunctions(Node);
      tntGroupTriggers:     LoadTriggers(Node);
      tntGroupSequences:    LoadSequences(Node);
      tntTable:             LoadTableDetails(Node);
      tntGroupColumns:      LoadColumns(Node);
      tntGroupIndexes:      LoadIndexes(Node);
      tntGroupForeignKeys:  LoadForeignKeys(Node);
    end;
    Data.IsLoaded := True;
  finally
    Screen.Cursor := crDefault;
    tvObjects.EndUpdate;
  end;
end;

procedure TFrameObjectTree.tvObjectsSelectionChanged(Sender: TObject);
var
  Data: TTreeObjectData;
begin
  Data := GetNodeData(tvObjects.Selected);
  if Assigned(FOnNodeSelected) then
    FOnNodeSelected(Self, Data);
end;

procedure TFrameObjectTree.tvObjectsDblClick(Sender: TObject);
var
  Data: TTreeObjectData;
begin
  Data := GetNodeData(tvObjects.Selected);
  if not Assigned(Data) then Exit;

  if (Data.NodeType = tntTable) and Assigned(FOnShowTableData) then
    FOnShowTableData(Self, Data.Profile, Data.DatabaseName, Data.SchemaName, Data.ObjectName)
  else if (Data.NodeType = tntView) and Assigned(FOnOpenQueryTab) then
    FOnOpenQueryTab(Self, Data.Profile, Data.DatabaseName, Format('SELECT * FROM %s LIMIT 100;', [Data.ObjectName]));
end;

procedure TFrameObjectTree.tvObjectsDeletion(Sender: TObject; Node: TTreeNode);
begin
  if Assigned(Node.Data) then
  begin
    TTreeObjectData(Node.Data).Free;
    Node.Data := nil;
  end;
end;

procedure TFrameObjectTree.RefreshNode(ANode: TTreeNode);
var
  Data: TTreeObjectData;
begin
  if not Assigned(ANode) then Exit;
  Data := GetNodeData(ANode);
  if Assigned(Data) then
  begin
    Data.IsLoaded := False;
    ANode.DeleteChildren;
    AddDummyChild(ANode);
    ANode.Expand(False);
  end;
end;

procedure TFrameObjectTree.btnRefreshAllClick(Sender: TObject);
begin
  RefreshTree;
end;

procedure TFrameObjectTree.btnClearFilterClick(Sender: TObject);
begin
  edtFilter.Clear;
end;

procedure TFrameObjectTree.edtFilterChange(Sender: TObject);
var
  FilterText: string;
  I: Integer;
  Node: TTreeNode;
begin
  FilterText := UpperCase(Trim(edtFilter.Text));
  if FilterText = '' then Exit;

  for I := 0 to tvObjects.Items.Count - 1 do
  begin
    Node := tvObjects.Items[I];
    if Pos(FilterText, UpperCase(Node.Text)) > 0 then
    begin
      Node.MakeVisible;
      Node.Selected := True;
      Break;
    end;
  end;
end;

function TFrameObjectTree.ExecuteDirectSQL(const ASQL: string; const ADBName: string): Boolean;
var
  Conn: TZConnection;
begin
  Result := False;
  if not Assigned(FProfile) or (FProfile.ConnectionName = '') then Exit;

  Conn := TZConnection.Create(nil);
  try
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
      if ADBName <> '' then
        Conn.Database := ADBName
      else
        Conn.Database := FProfile.DatabaseName;
      Conn.User := FProfile.Username;
      Conn.Password := FProfile.Password;
      Conn.AutoCommit := True;
      Conn.Connect;

      Conn.ExecuteDirect(ASQL);
      Result := True;
    except
      on E: Exception do
        MessageDlg('Kesalahan Eksekusi SQL', E.Message, mtError, [mbOK], 0);
    end;
  finally
    Conn.Free;
  end;
end;

procedure TFrameObjectTree.ExecuteMaintenanceCommand(const ACommandType: string; const ATableName: string);
var
  SQL: string;
  Data: TTreeObjectData;
begin
  Data := GetNodeData(tvObjects.Selected);
  if not Assigned(Data) then Exit;

  case FProfile.DriverType of
    dtSQLite:
    begin
      if ACommandType = 'OPTIMIZE' then SQL := 'VACUUM;'
      else if ACommandType = 'ANALYZE' then SQL := 'ANALYZE;'
      else SQL := 'PRAGMA integrity_check;';
    end;
    dtPostgreSQL:
    begin
      if ACommandType = 'OPTIMIZE' then SQL := 'VACUUM ANALYZE ' + ATableName + ';'
      else if ACommandType = 'ANALYZE' then SQL := 'ANALYZE ' + ATableName + ';'
      else SQL := 'REINDEX TABLE ' + ATableName + ';';
    end;
    else
    begin
      if ACommandType = 'OPTIMIZE' then SQL := 'OPTIMIZE TABLE ' + ATableName + ';'
      else if ACommandType = 'ANALYZE' then SQL := 'ANALYZE TABLE ' + ATableName + ';'
      else SQL := 'CHECK TABLE ' + ATableName + ';';
    end;
  end;

  if ExecuteDirectSQL(SQL, Data.DatabaseName) then
    MessageDlg('Perawatan Berhasil', Format('Perintah perawatan [%s] selesai dijalankan:%s%s', [
      ACommandType, LineEnding, SQL
    ]), mtInformation, [mbOK], 0);
end;

procedure TFrameObjectTree.popTreePopup(Sender: TObject);
var
  Data: TTreeObjectData;
  IsTbl, IsDB, IsVw: Boolean;
begin
  Data := GetNodeData(tvObjects.Selected);
  if not Assigned(Data) then
  begin
    mnuEditObject.Enabled := False;
    mnuOpenQuery.Enabled := False;
    mnuViewDataTop100.Enabled := False;
    mnuViewDDL.Enabled := False;
    mnuDropObject.Enabled := False;
    mnuTruncateTable.Enabled := False;
    mnuCopyName.Enabled := False;
    mnuRefreshNode.Enabled := False;
    mnuMaintenance.Visible := False;
    Exit;
  end;

  IsTbl := (Data.NodeType = tntTable);
  IsDB := (Data.NodeType in [tntDatabase, tntRootConnection]);
  IsVw := (Data.NodeType = tntView);

  // Aktifkan Edit / Desain baik untuk Tabel maupun View
  mnuEditObject.Enabled := IsTbl or IsVw;
  if IsVw then
    mnuEditObject.Caption := Format('Sunting View "%s"...', [Data.ObjectName])
  else if IsTbl then
    mnuEditObject.Caption := Format('Sunting Tabel "%s"...', [Data.ObjectName])
  else
    mnuEditObject.Caption := 'Sunting / Desain...';

  mnuOpenQuery.Enabled := True;
  mnuViewDataTop100.Enabled := IsTbl or IsVw;
  mnuViewDDL.Enabled := IsTbl or IsVw;

  mnuDropObject.Enabled := IsTbl or IsDB or IsVw or (Data.NodeType in [tntProcedure, tntFunction, tntTrigger]);
  if IsTbl then
  begin
    mnuDropObject.Caption := Format('Hapus Tabel "%s"...', [Data.ObjectName]);
    mnuTruncateTable.Visible := True;
    mnuTruncateTable.Caption := Format('Kosongkan Tabel "%s"...', [Data.ObjectName]);
  end
  else if IsVw then
  begin
    mnuDropObject.Caption := Format('Hapus View "%s"...', [Data.ObjectName]);
    mnuTruncateTable.Visible := False;
  end
  else if IsDB then
  begin
    mnuDropObject.Caption := Format('Hapus Database "%s"...', [Data.DatabaseName]);
    mnuTruncateTable.Visible := False;
  end
  else
  begin
    mnuDropObject.Caption := 'Hapus...';
    mnuTruncateTable.Visible := False;
  end;

  mnuCreateNew.Enabled := True;
  mnuNewCopyTable.Enabled := IsTbl;
  mnuMaintenance.Visible := IsTbl or (Data.NodeType = tntDatabase);

  mnuCopyName.Enabled := (Data.ObjectName <> '') or (Data.DatabaseName <> '');
  mnuRefreshNode.Enabled := True;
end;

procedure TFrameObjectTree.mnuEditObjectClick(Sender: TObject);
var
  Data: TTreeObjectData;
  TblName, DBName, ViewDDL: string;
  Driver: TDBDriverBase;
begin
  Data := GetNodeData(tvObjects.Selected);
  if not Assigned(Data) then Exit;

  DBName := Data.DatabaseName;

  // 1. Jika objek adalah VIEW -> Buka definisi DDL-nya di Tab Kueri Baru untuk disunting
  if Data.NodeType = tntView then
  begin
    Driver := nil;
    try
      Driver := TDBConnectionFactory.CreateDriver(FProfile);
      ViewDDL := Driver.GetViewDDL(Data.DatabaseName, Data.SchemaName, Data.ObjectName);

      if Trim(ViewDDL) = '' then
        ViewDDL := Format('CREATE VIEW %s AS' + LineEnding + 'SELECT * FROM ...;', [Data.ObjectName]);

      if Assigned(FOnOpenQueryTab) then
        FOnOpenQueryTab(Self, FProfile, DBName, ViewDDL);
    finally
      if Assigned(Driver) then
        Driver.Free;
    end;
    Exit;
  end;

  // 2. Jika objek adalah TABEL -> Buka dialog Visual Table Builder
  TblName := '';
  if Data.NodeType = tntTable then
    TblName := Data.ObjectName
  else if Data.NodeType in [tntGroupColumns, tntGroupIndexes, tntGroupForeignKeys, tntColumn, tntIndex, tntForeignKey] then
    TblName := Data.ObjectName;

  if TblName <> '' then
    TFormTableBuilder.Execute(Self, FProfile, TblName, DBName);
end;

procedure TFrameObjectTree.mnuOpenQueryClick(Sender: TObject);
var
  Data: TTreeObjectData;
begin
  Data := GetNodeData(tvObjects.Selected);
  if Assigned(Data) and Assigned(FOnOpenQueryTab) then
    FOnOpenQueryTab(Self, Data.Profile, Data.DatabaseName, '');
end;

procedure TFrameObjectTree.mnuViewDataTop100Click(Sender: TObject);
var
  Data: TTreeObjectData;
  SQL: string;
begin
  Data := GetNodeData(tvObjects.Selected);
  if not Assigned(Data) then Exit;

  if (Data.NodeType = tntTable) and Assigned(FOnShowTableData) then
    FOnShowTableData(Self, Data.Profile, Data.DatabaseName, Data.SchemaName, Data.ObjectName)
  else if Assigned(FOnOpenQueryTab) then
  begin
    SQL := Format('SELECT * FROM %s LIMIT 100;', [Data.ObjectName]);
    FOnOpenQueryTab(Self, Data.Profile, Data.DatabaseName, SQL);
  end;
end;

procedure TFrameObjectTree.mnuViewDDLClick(Sender: TObject);
var
  Data: TTreeObjectData;
begin
  Data := GetNodeData(tvObjects.Selected);
  if Assigned(Data) and (Data.NodeType in [tntTable, tntView]) and Assigned(FOnShowTableDDL) then
    FOnShowTableDDL(Self, Data.Profile, Data.DatabaseName, Data.SchemaName, Data.ObjectName);
end;

procedure TFrameObjectTree.mnuDropObjectClick(Sender: TObject);
var
  Data: TTreeObjectData;
  SQL, TargetName: string;
begin
  Data := GetNodeData(tvObjects.Selected);
  if not Assigned(Data) then Exit;

  if Data.ObjectName <> '' then
    TargetName := Data.ObjectName
  else
    TargetName := Data.DatabaseName;

  if MessageDlg('Konfirmasi Hapus',
    Format('Yakin ingin MENGHAPUS objek "%s" secara permanen? Operasi ini tidak dapat dibatalkan.', [TargetName]),
    mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;

  case Data.NodeType of
    tntTable:     SQL := 'DROP TABLE ' + Data.ObjectName + ';';
    tntView:      SQL := 'DROP VIEW ' + Data.ObjectName + ';';
    tntProcedure: SQL := 'DROP PROCEDURE ' + Data.ObjectName + ';';
    tntFunction:  SQL := 'DROP FUNCTION ' + Data.ObjectName + ';';
    tntTrigger:   SQL := 'DROP TRIGGER ' + Data.ObjectName + ';';
    tntDatabase:  SQL := 'DROP DATABASE ' + Data.DatabaseName + ';';
    else Exit;
  end;

  if ExecuteDirectSQL(SQL, Data.DatabaseName) then
  begin
    RefreshNode(tvObjects.Selected.Parent);
    MessageDlg('Sukses', Format('Objek "%s" berhasil dihapus.', [TargetName]), mtInformation, [mbOK], 0);
  end;
end;

procedure TFrameObjectTree.mnuTruncateTableClick(Sender: TObject);
var
  Data: TTreeObjectData;
  SQL: string;
begin
  Data := GetNodeData(tvObjects.Selected);
  if not Assigned(Data) or (Data.NodeType <> tntTable) then Exit;

  if MessageDlg('Konfirmasi Kosongkan Tabel',
    Format('Yakin ingin MENGOSONGKAN seluruh baris pada tabel "%s"?', [Data.ObjectName]),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

  if FProfile.DriverType = dtSQLite then
    SQL := 'DELETE FROM ' + Data.ObjectName + ';'
  else
    SQL := 'TRUNCATE TABLE ' + Data.ObjectName + ';';

  if ExecuteDirectSQL(SQL, Data.DatabaseName) then
    MessageDlg('Sukses', Format('Tabel "%s" berhasil dikosongkan.', [Data.ObjectName]), mtInformation, [mbOK], 0);
end;

procedure TFrameObjectTree.mnuNewDatabaseClick(Sender: TObject);
var
  NewDBName: string;
begin
  if InputQuery('Buat Database Baru', 'Masukkan nama database:', NewDBName) then
  begin
    if Trim(NewDBName) = '' then Exit;
    if ExecuteDirectSQL('CREATE DATABASE ' + Trim(NewDBName) + ';') then
    begin
      RefreshTree;
      MessageDlg('Sukses', 'Database baru berhasil dibuat.', mtInformation, [mbOK], 0);
    end;
  end;
end;

procedure TFrameObjectTree.mnuNewTableClick(Sender: TObject);
begin
  TFormTableBuilder.Execute(Self, FProfile, '');
end;

procedure TFrameObjectTree.mnuNewCopyTableClick(Sender: TObject);
var
  Data: TTreeObjectData;
  NewTbl, SQL: string;
begin
  Data := GetNodeData(tvObjects.Selected);
  if not Assigned(Data) or (Data.NodeType <> tntTable) then Exit;

  NewTbl := Data.ObjectName + '_copy';
  if InputQuery('Salin Tabel', 'Nama tabel baru:', NewTbl) and (Trim(NewTbl) <> '') then
  begin
    SQL := Format('CREATE TABLE %s AS SELECT * FROM %s;', [Trim(NewTbl), Data.ObjectName]);
    if ExecuteDirectSQL(SQL, Data.DatabaseName) then
    begin
      RefreshNode(tvObjects.Selected.Parent);
      MessageDlg('Sukses', Format('Tabel "%s" berhasil disalin ke "%s".', [Data.ObjectName, Trim(NewTbl)]), mtInformation, [mbOK], 0);
    end;
  end;
end;

procedure TFrameObjectTree.mnuNewViewClick(Sender: TObject);
var
  Data: TTreeObjectData;
  SQL, DBName: string;
begin
  Data := GetNodeData(tvObjects.Selected);
  if Assigned(Data) then DBName := Data.DatabaseName else DBName := '';
  SQL := 'CREATE VIEW v_nama_view AS' + LineEnding + 'SELECT * FROM nama_tabel' + LineEnding + 'WHERE 1=1;';
  if Assigned(FOnOpenQueryTab) then
    FOnOpenQueryTab(Self, FProfile, DBName, SQL);
end;

procedure TFrameObjectTree.mnuNewProcedureClick(Sender: TObject);
var
  Data: TTreeObjectData;
  SQL, DBName: string;
begin
  Data := GetNodeData(tvObjects.Selected);
  if Assigned(Data) then DBName := Data.DatabaseName else DBName := '';
  SQL :=
    'DELIMITER $$' + LineEnding +
    'CREATE PROCEDURE sp_nama_prosedur()' + LineEnding +
    'BEGIN' + LineEnding +
    '  -- Tulis logika kueri' + LineEnding +
    'END $$' + LineEnding +
    'DELIMITER ;';
  if Assigned(FOnOpenQueryTab) then
    FOnOpenQueryTab(Self, FProfile, DBName, SQL);
end;

procedure TFrameObjectTree.mnuNewFunctionClick(Sender: TObject);
var
  Data: TTreeObjectData;
  SQL, DBName: string;
begin
  Data := GetNodeData(tvObjects.Selected);
  if Assigned(Data) then DBName := Data.DatabaseName else DBName := '';
  SQL :=
    'DELIMITER $$' + LineEnding +
    'CREATE FUNCTION fn_nama_fungsi()' + LineEnding +
    'RETURNS INTEGER' + LineEnding +
    'DETERMINISTIC' + LineEnding +
    'BEGIN' + LineEnding +
    '  RETURN 1;' + LineEnding +
    'END $$' + LineEnding +
    'DELIMITER ;';
  if Assigned(FOnOpenQueryTab) then
    FOnOpenQueryTab(Self, FProfile, DBName, SQL);
end;

procedure TFrameObjectTree.mnuNewTriggerClick(Sender: TObject);
var
  Data: TTreeObjectData;
  SQL, DBName, TblTarget: string;
begin
  Data := GetNodeData(tvObjects.Selected);
  if Assigned(Data) then
  begin
    DBName := Data.DatabaseName;
    if Data.NodeType = tntTable then
      TblTarget := Data.ObjectName
    else
      TblTarget := 'nama_tabel';
  end
  else
  begin
    DBName := '';
    TblTarget := 'nama_tabel';
  end;

  SQL :=
    'CREATE TRIGGER trg_nama_trigger' + LineEnding +
    'AFTER INSERT ON ' + TblTarget + LineEnding +
    'FOR EACH ROW' + LineEnding +
    'BEGIN' + LineEnding +
    '  -- Logika trigger' + LineEnding +
    'END;';
  if Assigned(FOnOpenQueryTab) then
    FOnOpenQueryTab(Self, FProfile, DBName, SQL);
end;

procedure TFrameObjectTree.mnuMaintOptimizeClick(Sender: TObject);
var
  Data: TTreeObjectData;
begin
  Data := GetNodeData(tvObjects.Selected);
  if Assigned(Data) then
    ExecuteMaintenanceCommand('OPTIMIZE', Data.ObjectName);
end;

procedure TFrameObjectTree.mnuMaintAnalyzeClick(Sender: TObject);
var
  Data: TTreeObjectData;
begin
  Data := GetNodeData(tvObjects.Selected);
  if Assigned(Data) then
    ExecuteMaintenanceCommand('ANALYZE', Data.ObjectName);
end;

procedure TFrameObjectTree.mnuMaintCheckClick(Sender: TObject);
var
  Data: TTreeObjectData;
begin
  Data := GetNodeData(tvObjects.Selected);
  if Assigned(Data) then
    ExecuteMaintenanceCommand('CHECK', Data.ObjectName);
end;

procedure TFrameObjectTree.mnuExportSQLClick(Sender: TObject);
var
  Data: TTreeObjectData;
  SQL, TblName: string;
begin
  Data := GetNodeData(tvObjects.Selected);
  if not Assigned(Data) or not Assigned(FProfile) then Exit;

  if Data.NodeType = tntTable then
  begin
    TblName := Data.ObjectName;
    SQL := Format('SELECT * FROM %s;', [TblName]);

    // Buka wizard ekspor data tabel
    TFormExportDialog.ExecuteDialog(Self, FProfile, SQL, TblName, Data.DatabaseName);
  end
  else if Assigned(FOnOpenQueryTab) then
  begin
    FOnOpenQueryTab(Self, FProfile, Data.DatabaseName, '-- Ekspor skrip DDL Database');
  end;
end;

procedure TFrameObjectTree.mnuCopyNameClick(Sender: TObject);
var
  Data: TTreeObjectData;
begin
  Data := GetNodeData(tvObjects.Selected);
  if Assigned(Data) then
  begin
    if Data.ObjectName <> '' then
      Clipboard.AsText := Data.ObjectName
    else if Data.DatabaseName <> '' then
      Clipboard.AsText := Data.DatabaseName
    else
      Clipboard.AsText := tvObjects.Selected.Text;
  end;
end;

procedure TFrameObjectTree.mnuRefreshNodeClick(Sender: TObject);
begin
  RefreshNode(tvObjects.Selected);
end;

procedure TFrameObjectTree.mnuExpandAllClick(Sender: TObject);
begin
  if Assigned(tvObjects.Selected) then
    tvObjects.Selected.Expand(True)
  else
    tvObjects.FullExpand;
end;

procedure TFrameObjectTree.mnuCollapseAllClick(Sender: TObject);
begin
  if Assigned(tvObjects.Selected) then
    tvObjects.Selected.Collapse(True)
  else
    tvObjects.FullCollapse;
end;

end.
