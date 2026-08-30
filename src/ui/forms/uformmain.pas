unit uFormMain;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Classes,
  StrUtils,
  Forms,
  Controls,
  Graphics,
  Dialogs,
  Menus,
  ComCtrls,
  ExtCtrls,
  StdCtrls,
  Buttons,
  ActnList,
  Clipbrd,
  ZConnection,
  ColorSpeedButton,
  cyPageControl,
  uAppConst,
  uAppTypes,
  uDBTypes,
  uModelConnection,
  uLocalStorage,
  uHistoryService,
  uExportService,
  uSSHTunnelService,
  uDBConnectionFactory,
  uFormDataTransfer,
  uFormSchemaDiff,
  uFormConnectionEdit,
  uFormExportDialog,
  uFrameObjectTree,
  uFormERDViewer,
  uFrameQueryTab,
  uFrameDataGrid,
  uFrameTableDDL,
  uFormUserManager,
  uFormProcessManager,
  uFormGridSettings,
  uFrameSQLLog,
  uSQLLoggerService,
  uFormBackupRestore,
  uFormLiveMetrics,
  uFormServerVariables,
  uFormRecordView,
  uFormImportData,
  uFormTableBuilder,
  uFormAISettings,
  uFormAbout,
  uFrameWelcomeDashboard,
  uFormCrosstabBuilder,
  uFormRESTGeneratorWizard,
  uFrameDBTerminal,
  uFormExtensionManager;

type
  { TFormMain }
  TFormMain = class(TForm)
    btnERD: TColorSpeedButton;
    btnExecute: TColorSpeedButton;
    btnDisconnect: TColorSpeedButton;
    btnDeleteConn: TColorSpeedButton;
    btnConnect: TColorSpeedButton;
    btnCancelExec: TColorSpeedButton;
    btnMetric: TColorSpeedButton;
    btnLog2: TColorSpeedButton;
    btnNewQuery: TColorSpeedButton;
    btnNewCon: TColorSpeedButton;
    btnEditConn: TColorSpeedButton;
    btnCloseTab: TColorSpeedButton;
    cboConnections: TComboBox;
    mnuDBExtensions: TMenuItem;
    pnlMetricsContainer: TPanel;
    pgMain: TcyPageControl;
    mnExit: TMenuItem;
    MenuItem3: TMenuItem;
    mnuRESTGenerator: TMenuItem;
    mnuCrosstabWizard: TMenuItem;
    mnuTableBuilder: TMenuItem;
    mnuDBProcessList: TMenuItem;
    mnuDBServerVariables: TMenuItem;
    mnuToolsSchemaDiff: TMenuItem;
    mnUserManagement: TMenuItem;
    mnuFileNewCon: TMenuItem;
    mnuToolsBackupRestore: TMenuItem;
    mnuToolsDataTransfer: TMenuItem;
    mnuToolsAISettings: TMenuItem;
    mnAIFeature: TMenuItem;
    mnuToolsImportData: TMenuItem;
    MenuItem2: TMenuItem;

    // Menu Utama
    mnuMain: TMainMenu;
    mnuFile: TMenuItem;
    mnuFileNewQuery: TMenuItem;
    mnuDatabase: TMenuItem;
    mnuDBConnect: TMenuItem;
    mnuDBDisconnect: TMenuItem;
    mnuDBSep1: TMenuItem;
    mnuDBEditConn: TMenuItem;
    mnuDBDeleteConn: TMenuItem;
    mnuQuery: TMenuItem;
    mnuQueryExecute: TMenuItem;
    mnuQueryExplain: TMenuItem;
    mnuQueryCancel: TMenuItem;
    mnuHelp: TMenuItem;
    mnuHelpAbout: TMenuItem;

    // Action List
    alMain: TActionList;
    actNewConnection: TAction;
    actEditConnection: TAction;
    actDeleteConnection: TAction;
    actConnect: TAction;
    actDisconnect: TAction;
    actNewQueryTab: TAction;
    actCloseTab: TAction;
    actExecuteQuery: TAction;
    actCancelQuery: TAction;
    actExplainPlan: TAction;
    pgcWorkspaces: TPageControl;
    pnlBottomLog: TPanel;

    // Toolbar Atas
    pnlToolbar: TPanel;
    Separator1: TMenuItem;
    Separator2: TMenuItem;
    Separator3: TMenuItem;
    Separator5: TMenuItem;
    sepTool2: TBevel;

    // Layout Panel Kiri dan Kanan
    pnlLeft: TPanel;
    Splitter1: TSplitter;
    splMain: TSplitter;
    pnlClient: TPanel;

    // Objek Tree di Sisi Kiri
    pnlTreeContainer: TPanel;

    popTabs: TPopupMenu;
    mnuTabClose: TMenuItem;
    mnuTabCloseOthers: TMenuItem;
    mnuTabCloseAll: TMenuItem;
    mnuGridSettings: TMenuItem;

    // Status Bar
    sbStatus: TStatusBar;
    splBottomLog: TSplitter;
    tbsMetric: TTabSheet;
    tbsERD: TTabSheet;
    tbsQuery: TTabSheet;
    tbsLog: TTabSheet;

    procedure btnERDClick(Sender: TObject);
    procedure btnLog2Click(Sender: TObject);
    procedure btnMetricClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);

    // Handler Actions
    procedure actNewConnectionExecute(Sender: TObject);
    procedure actEditConnectionExecute(Sender: TObject);
    procedure actDeleteConnectionExecute(Sender: TObject);
    procedure actConnectExecute(Sender: TObject);
    procedure actDisconnectExecute(Sender: TObject);
    procedure actNewQueryTabExecute(Sender: TObject);
    procedure actCloseTabExecute(Sender: TObject);
    procedure actExecuteQueryExecute(Sender: TObject);
    procedure actCancelQueryExecute(Sender: TObject);
    procedure actExplainPlanExecute(Sender: TObject);
    procedure MenuItem2Click(Sender: TObject);
    procedure mnExitClick(Sender: TObject);
    procedure mnOpenTerminalClick(Sender: TObject);
    procedure mnuDBExtensionsClick(Sender: TObject);
    procedure mnuDBProcessClick(Sender: TObject);
    procedure mnUserManagementClick(Sender: TObject);
    procedure mnuHelpAboutClick(Sender: TObject);
    procedure mnuFileExitClick(Sender: TObject);
    procedure mnuDBUserManagerClick(Sender: TObject);
    procedure cboConnectionsChange(Sender: TObject);
    procedure pgcWorkspacesMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure mnuTabCloseOthersClick(Sender: TObject);
    procedure mnuTabCloseAllClick(Sender: TObject);
    procedure mnuDBProcessListClick(Sender: TObject);
    procedure mnuDBServerVariablesClick(Sender: TObject);
    procedure mnuDBERDViewerClick(Sender: TObject);
    procedure mnuToolsImportDataClick(Sender: TObject);
    procedure mnuTableBuilderClick(Sender: TObject);
    procedure mnuToolsSchemaDiffClick(Sender: TObject);
    procedure mnuToolsAISettingsClick(Sender: TObject);
    procedure mnuToolsDataTransferClick(Sender: TObject);
    procedure mnuGridSettingsClick(Sender: TObject);
    procedure mnuToolsBackupRestoreClick(Sender: TObject);
    procedure mnuDBMetricsDashboardClick(Sender: TObject);
    procedure mnuCrosstabWizardClick(Sender: TObject);
    procedure mnuRESTGeneratorClick(Sender: TObject);
  private
    FConnections: TConnectionProfileList;
    FCurrentProfile: TConnectionProfile;
    FIsConnected: Boolean;
    FFrameObjectTree: TFrameObjectTree;
    FTabCounter: Integer;
    FIsClosing: Boolean;
    FFrameSQLLog: TFrameSQLLog;
    FFrameDashboard: TFrameWelcomeDashboard;
    FActiveTunnel: TSSHTunnel;

    // Show Feature In Tab
    FFERDViewer: TFormERDViewer;
    FMetricsForm: TFormLiveMetrics;
    FTerminalFrame: TFrameDBTerminal;

    procedure StartSSHTunnelIfNeeded(AProfile: TConnectionProfile);
    procedure StopActiveSSHTunnel;

    procedure InitWelcomeDashboard;
    procedure ShowWelcomeDashboard;
    procedure HideWelcomeDashboard;

    procedure HandleDashboardConnectProfile(Sender: TObject; AProfile: TConnectionProfile);
    procedure HandleDashboardNL2SQL(Sender: TObject);
    procedure HandleDashboardPHPCRUD(Sender: TObject);
    procedure HandleDashboardRoutineGen(Sender: TObject);

    procedure ReloadConnectionProfiles;
    function GetSelectedProfile: TConnectionProfile;
    function GetActiveQueryFrame: TFrameQueryTab;
    procedure UpdateActionsState;
    procedure UpdateStatusBar(const AMessage: string = '');
    procedure OpenDBTerminalTab;

    // Event Sink dari Frame Tree
    procedure HandleTreeOpenQuery(Sender: TObject; AProfile: TConnectionProfile; const ADBName, AInitialSQL: string);
    procedure HandleTreeShowData(Sender: TObject; AProfile: TConnectionProfile; const ADBName, ASchema, ATableName: string);
    procedure HandleTreeShowDDL(Sender: TObject; AProfile: TConnectionProfile; const ADBName, ASchema, ATableName: string);
  public
    function CreateQueryTab(AProfile: TConnectionProfile; const ADBName: string = ''; const AInitialSQL: string = ''): TFrameQueryTab;
    procedure CloseTabByIndex(const AIndex: Integer);
  end;

var
  FormMain: TFormMain;

implementation

{$R *.lfm}

{ TFormMain }

procedure TFormMain.FormCreate(Sender: TObject);
begin
  FIsClosing := False;
  FIsConnected := False;
  FConnections := TConnectionProfileList.Create(True);
  FCurrentProfile := nil;
  FActiveTunnel := nil;
  FTabCounter := 0;

  FFrameSQLLog := TFrameSQLLog.Create(Self);
  FFrameSQLLog.Parent := pnlBottomLog;
  FFrameSQLLog.Align := alClient;

  SQLLogger.LogComment(Format('Admiral v%s Started.', [APP_VERSION]));

  FFrameObjectTree := TFrameObjectTree.Create(Self);
  FFrameObjectTree.Parent := pnlTreeContainer;
  FFrameObjectTree.Align := alClient;
  FFrameObjectTree.OnOpenQueryTab := @HandleTreeOpenQuery;
  FFrameObjectTree.OnShowTableData := @HandleTreeShowData;
  FFrameObjectTree.OnShowTableDDL := @HandleTreeShowDDL;

  ReloadConnectionProfiles;
  UpdateActionsState;
  UpdateStatusBar('Ready.');

  InitWelcomeDashboard;
  ShowWelcomeDashboard;

  WindowState := wsMaximized;
end;

procedure TFormMain.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
end;

procedure TFormMain.btnERDClick(Sender: TObject);
begin
  tbsERD.Show;
end;

procedure TFormMain.btnLog2Click(Sender: TObject);
begin
  tbsLog.Show;
end;

procedure TFormMain.btnMetricClick(Sender: TObject);
begin
  tbsMetric.Show;
end;

procedure TFormMain.StartSSHTunnelIfNeeded(AProfile: TConnectionProfile);
var
  SSHErr: string;
begin
  StopActiveSSHTunnel;

  if Assigned(AProfile) and AProfile.SSHEnabled and (AProfile.DriverType <> dtSQLite) then
  begin
    UpdateStatusBar(Format('Open SSH Tunnel to %s...', [AProfile.SSHHost]));
    Application.ProcessMessages;

    FActiveTunnel := TSSHTunnelManager.OpenTunnel(AProfile, SSHErr);
    if not Assigned(FActiveTunnel) then
      raise Exception.Create('Failed to initialize SSH tunnel: ' + SSHErr);
  end;
end;

procedure TFormMain.StopActiveSSHTunnel;
begin
  if Assigned(FActiveTunnel) then
  begin
    TSSHTunnelManager.CloseTunnel(FActiveTunnel);
    FActiveTunnel := nil;
  end;
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  FIsClosing := True;
  alMain.State := asSuspended;
  StopActiveSSHTunnel;
  FreeAndNil(FConnections);
  inherited Destroy;
end;

procedure TFormMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  I, J: Integer;
  Tab: TTabSheet;
begin
  FIsClosing := True;
  alMain.State := asSuspended;
  ActiveControl := nil;

  if Assigned(FFrameObjectTree) then
  begin
    FFrameObjectTree.OnOpenQueryTab := nil;
    FFrameObjectTree.OnShowTableData := nil;
    FFrameObjectTree.OnShowTableDDL := nil;
  end;

  if Assigned(ExportService) then
    ExportService.CancelAllExports;

  if Assigned(pgcWorkspaces) then
  begin
    for I := 0 to pgcWorkspaces.PageCount - 1 do
    begin
      Tab := pgcWorkspaces.Pages[I];
      if Assigned(Tab) then
      begin
        for J := 0 to Tab.ControlCount - 1 do
        begin
          if Tab.Controls[J] is TFrameQueryTab then
            TFrameQueryTab(Tab.Controls[J]).CancelExecution;
        end;
      end;
    end;
  end;

  CanClose := True;
end;

procedure TFormMain.InitWelcomeDashboard;
begin
  if not Assigned(FFrameDashboard) then
  begin
    FFrameDashboard := TFrameWelcomeDashboard.Create(Self);
    FFrameDashboard.Parent := pnlClient;
    FFrameDashboard.Align := alClient;

    FFrameDashboard.OnNewQuery := @actNewQueryTabExecute;
    FFrameDashboard.OnNL2SQL := @HandleDashboardNL2SQL;
    FFrameDashboard.OnBackupRestore := @mnuToolsBackupRestoreClick;
    FFrameDashboard.OnLiveMetrics := @mnuDBMetricsDashboardClick;
    FFrameDashboard.OnTableBuilder := @mnuTableBuilderClick;
    FFrameDashboard.OnPHPCRUD := @HandleDashboardPHPCRUD;
    FFrameDashboard.OnRoutineGen := @HandleDashboardRoutineGen;
    FFrameDashboard.OnSchemaDiff := @mnuToolsSchemaDiffClick;
    FFrameDashboard.OnNewConnection := @actNewConnectionExecute;
    FFrameDashboard.OnConnectProfile := @HandleDashboardConnectProfile;
  end;

  FFrameDashboard.RefreshConnectionList(FConnections);
end;

procedure TFormMain.ShowWelcomeDashboard;
begin
  if Assigned(FFrameDashboard) then
  begin
    pgcWorkspaces.Visible := False;
    FFrameDashboard.RefreshConnectionList(FConnections);
    FFrameDashboard.Visible := True;
    FFrameDashboard.BringToFront;
  end;
end;

procedure TFormMain.HideWelcomeDashboard;
begin
  if Assigned(FFrameDashboard) then
    FFrameDashboard.Visible := False;
  pgcWorkspaces.Visible := True;
  pgcWorkspaces.BringToFront;
end;

procedure TFormMain.HandleDashboardConnectProfile(Sender: TObject; AProfile: TConnectionProfile);
var
  Idx: Integer;
begin
  if Assigned(AProfile) then
  begin
    Idx := FConnections.IndexOf(AProfile);
    if Idx >= 0 then
    begin
      cboConnections.ItemIndex := Idx;
      cboConnectionsChange(Self);
      actConnectExecute(Self);
      actNewQueryTabExecute(Self);
    end;
  end;
end;

procedure TFormMain.HandleDashboardNL2SQL(Sender: TObject);
begin
  if FIsConnected then
    actNewQueryTabExecute(Self);
end;

procedure TFormMain.HandleDashboardPHPCRUD(Sender: TObject);
begin
  // Placeholder modul PHP CRUD
end;

procedure TFormMain.HandleDashboardRoutineGen(Sender: TObject);
begin
  // Placeholder modul Routine Generator
end;

procedure TFormMain.ReloadConnectionProfiles;
var
  I: Integer;
  Profile: TConnectionProfile;
begin
  cboConnections.Items.Clear;
  LocalStorage.LoadProfiles(FConnections);

  for I := 0 to FConnections.Count - 1 do
  begin
    Profile := FConnections[I];
    cboConnections.Items.AddObject(Profile.GetDisplayName, Profile);
  end;

  if cboConnections.Items.Count > 0 then
  begin
    cboConnections.ItemIndex := 0;
    FCurrentProfile := GetSelectedProfile;
  end
  else
    FCurrentProfile := nil;

  FIsConnected := False;

  if Assigned(FFrameDashboard) then
    FFrameDashboard.RefreshConnectionList(FConnections);

  UpdateActionsState;
end;

function TFormMain.GetSelectedProfile: TConnectionProfile;
begin
  if (cboConnections.ItemIndex >= 0) and (cboConnections.ItemIndex < FConnections.Count) then
    Result := TConnectionProfile(cboConnections.Items.Objects[cboConnections.ItemIndex])
  else
    Result := nil;
end;

function TFormMain.GetActiveQueryFrame: TFrameQueryTab;
var
  CurSheet: TTabSheet;
  I: Integer;
begin
  Result := nil;
  if FIsClosing or (csDestroying in ComponentState) then Exit;
  if not Assigned(pgcWorkspaces) or (pgcWorkspaces.PageCount = 0) then Exit;

  try
    CurSheet := pgcWorkspaces.ActivePage;
    if not Assigned(CurSheet) or (csDestroying in CurSheet.ComponentState) then Exit;

    for I := 0 to CurSheet.ControlCount - 1 do
    begin
      if (CurSheet.Controls[I] is TFrameQueryTab) and not (csDestroying in CurSheet.Controls[I].ComponentState) then
      begin
        Result := TFrameQueryTab(CurSheet.Controls[I]);
        Break;
      end;
    end;
  except
    Result := nil;
  end;
end;

procedure TFormMain.UpdateActionsState;
var
  HasProfile: Boolean;
  QueryFrame: TFrameQueryTab;
  IsExec: Boolean;
begin
  if FIsClosing or (csDestroying in ComponentState) then Exit;

  HasProfile := Assigned(GetSelectedProfile);
  QueryFrame := GetActiveQueryFrame;
  IsExec := Assigned(QueryFrame) and QueryFrame.IsExecuting;

  actEditConnection.Enabled := HasProfile;
  actDeleteConnection.Enabled := HasProfile;
  actConnect.Enabled := HasProfile and (not FIsConnected);
  actDisconnect.Enabled := FIsConnected;

  // Tombol Kueri Baru hanya aktif jika database sudah terhubung
  actNewQueryTab.Enabled := FIsConnected;

  // Tutup tab hanya aktif jika ada LEBIH DARI 1 tab
  actCloseTab.Enabled := Assigned(pgcWorkspaces) and (pgcWorkspaces.PageCount > 1);
  mnuTabClose.Enabled := actCloseTab.Enabled;
  mnuTabCloseOthers.Enabled := actCloseTab.Enabled;
  mnuTabCloseAll.Enabled := actCloseTab.Enabled;

  actExecuteQuery.Enabled := Assigned(QueryFrame) and not IsExec;
  actCancelQuery.Enabled := Assigned(QueryFrame) and IsExec;
  actExplainPlan.Enabled := Assigned(QueryFrame) and not IsExec;

  btnLog2.Enabled := FIsConnected;
  btnERD.Enabled := FIsConnected;
  btnMetric.Enabled := FIsConnected;

  tbsQuery.Show;
end;

procedure TFormMain.UpdateStatusBar(const AMessage: string);
var
  SSHInfo: string;
begin
  if AMessage <> '' then
    sbStatus.Panels[0].Text := AMessage;

  if FIsConnected and Assigned(FCurrentProfile) then
  begin
    if FCurrentProfile.SSHEnabled and Assigned(FActiveTunnel) then
      SSHInfo := Format(' [🔒 SSH: %s:%d]', [FCurrentProfile.SSHHost, FCurrentProfile.ActiveLocalPort])
    else
      SSHInfo := '';

    sbStatus.Panels[1].Text := Format('Connection: %s%s', [FCurrentProfile.ConnectionName, SSHInfo]);
    sbStatus.Panels[2].Text := Format('DBMS: %s', [FCurrentProfile.GetDisplayName]);
  end
  else
  begin
    sbStatus.Panels[1].Text := 'Not Connected';
    sbStatus.Panels[2].Text := '-';
  end;
end;

function TFormMain.CreateQueryTab(AProfile: TConnectionProfile; const ADBName: string; const AInitialSQL: string): TFrameQueryTab;
var
  Tab: TTabSheet;
  TargetName: string;
begin
  HideWelcomeDashboard;

  Inc(FTabCounter);
  Tab := TTabSheet.Create(pgcWorkspaces);
  Tab.PageControl := pgcWorkspaces;

  if ADBName <> '' then
    TargetName := ADBName
  else
    TargetName := AProfile.ConnectionName;

  Tab.Caption := Format('Query %d (%s)', [FTabCounter, TargetName]);
  Tab.PopupMenu := popTabs;

  Result := TFrameQueryTab.Create(Tab);
  Result.Parent := Tab;
  Result.Align := alClient;
  Result.InitConnection(AProfile, ADBName);

  if AInitialSQL <> '' then
    Result.SetSQLText(AInitialSQL);

  pgcWorkspaces.ActivePage := Tab;
  UpdateActionsState;
end;

procedure TFormMain.CloseTabByIndex(const AIndex: Integer);
var
  Tab: TTabSheet;
  I: Integer;
  QTab: TFrameQueryTab;
begin
  try
    if FIsClosing or (csDestroying in ComponentState) then Exit;
    if (pgcWorkspaces.PageCount <= 1) then Exit;
    if (AIndex < 0) or (AIndex >= pgcWorkspaces.PageCount) then Exit;

    Tab := pgcWorkspaces.Pages[AIndex];
    if not Assigned(Tab) or (csDestroying in Tab.ComponentState) then Exit;

    Self.SetFocus;

    for I := 0 to Tab.ControlCount - 1 do
    begin
      if Tab.Controls[I] is TFrameQueryTab then
      begin
        QTab := TFrameQueryTab(Tab.Controls[I]);
        QTab.CancelExecution;
      end;
    end;

    Tab.Visible := False;
    Tab.PageControl := nil;
    FreeAndNil(Tab);

    if (pgcWorkspaces.PageCount > 0) and (pgcWorkspaces.ActivePageIndex < 0) then
      pgcWorkspaces.ActivePageIndex := 0;

    UpdateActionsState;
  except
    on E: Exception do Exit;
  end;
end;

procedure TFormMain.actNewConnectionExecute(Sender: TObject);
var
  NewProf: TConnectionProfile;
begin
  if TFormConnectionEdit.CreateConnection(Self, NewProf) then
  begin
    LocalStorage.SaveProfile(NewProf);
    ReloadConnectionProfiles;
    NewProf.Free;
  end;
end;

procedure TFormMain.actEditConnectionExecute(Sender: TObject);
var
  Prof: TConnectionProfile;
begin
  Prof := GetSelectedProfile;
  if not Assigned(Prof) then Exit;

  if TFormConnectionEdit.EditConnection(Self, Prof) then
  begin
    LocalStorage.SaveProfile(Prof);
    ReloadConnectionProfiles;
  end;
end;

procedure TFormMain.actDeleteConnectionExecute(Sender: TObject);
var
  Prof: TConnectionProfile;
begin
  Prof := GetSelectedProfile;
  if not Assigned(Prof) then Exit;

  if MessageDlg('Delete Confimation', Format('Delete Connection Profile "%s"?', [Prof.ConnectionName]),
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    LocalStorage.DeleteProfile(Prof.ID);
    ReloadConnectionProfiles;
    FFrameObjectTree.Clear;
    FIsConnected := False;
    UpdateStatusBar('Connection Profile Deleted');
    UpdateActionsState;
  end;
end;

procedure TFormMain.actConnectExecute(Sender: TObject);
begin
  FCurrentProfile := GetSelectedProfile;
  if not Assigned(FCurrentProfile) then Exit;

  Screen.Cursor := crHourGlass;
  try
    // Inisiasi SSH Tunnel terlebih dahulu jika profil memerlukannya
    StartSSHTunnelIfNeeded(FCurrentProfile);

    FFrameObjectTree.SetConnectionProfile(FCurrentProfile);
    FIsConnected := True;

    mnuDBMetricsDashboardClick(Sender);
    mnuDBERDViewerClick(Sender);
    actNewQueryTabExecute(Sender);

    SQLLogger.LogComment(Format('Connected  to %s (%s). Host: %s, Database: %s', [
      FCurrentProfile.ConnectionName,
      FCurrentProfile.GetDisplayName,
      FCurrentProfile.Host,
      FCurrentProfile.DatabaseName
    ]));
    UpdateStatusBar(Format('Connected  to %s', [FCurrentProfile.ConnectionName]));
  except
    on E: Exception do
    begin
      StopActiveSSHTunnel;
      FIsConnected := False;
      UpdateStatusBar('Fail Connected');
      MessageDlg('Error Connected', E.Message, mtError, [mbOK], 0);
    end;
  end;
  Screen.Cursor := crDefault;
  UpdateActionsState;
end;

procedure TFormMain.actNewQueryTabExecute(Sender: TObject);
var
  Prof: TConnectionProfile;
begin
  if not FIsConnected then Exit;

  Prof := GetSelectedProfile;
  if Assigned(Prof) then
    CreateQueryTab(Prof);
end;

procedure TFormMain.actCloseTabExecute(Sender: TObject);
begin
  try
    if (pgcWorkspaces.PageCount > 1) and (pgcWorkspaces.ActivePageIndex >= 0) then
      CloseTabByIndex(pgcWorkspaces.ActivePageIndex);
  except
    on E: Exception do Exit;
  end;
end;

procedure TFormMain.actExecuteQueryExecute(Sender: TObject);
var
  QueryFrame: TFrameQueryTab;
begin
  QueryFrame := GetActiveQueryFrame;
  if Assigned(QueryFrame) then
  begin
    QueryFrame.ExecuteCurrentOrSelected;
    UpdateActionsState;
  end;
end;

procedure TFormMain.actCancelQueryExecute(Sender: TObject);
var
  QueryFrame: TFrameQueryTab;
begin
  QueryFrame := GetActiveQueryFrame;
  if Assigned(QueryFrame) then
  begin
    QueryFrame.CancelExecution;
    UpdateActionsState;
  end;
end;

procedure TFormMain.actExplainPlanExecute(Sender: TObject);
var
  QueryFrame: TFrameQueryTab;
begin
  QueryFrame := GetActiveQueryFrame;
  if Assigned(QueryFrame) then
    QueryFrame.btnExplainClick(Sender);
end;

procedure TFormMain.MenuItem2Click(Sender: TObject);
begin

end;

procedure TFormMain.mnExitClick(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TFormMain.mnOpenTerminalClick(Sender: TObject);
begin
  OpenDBTerminalTab();
end;

procedure TFormMain.mnuDBProcessClick(Sender: TObject);
begin
end;

procedure TFormMain.mnUserManagementClick(Sender: TObject);
begin
  mnuDBUserManagerClick(Sender);
end;

procedure TFormMain.cboConnectionsChange(Sender: TObject);
begin
  StopActiveSSHTunnel;
  FCurrentProfile := GetSelectedProfile;
  FIsConnected := False;
  FFrameObjectTree.Clear;
  UpdateStatusBar('Ready.');
  UpdateActionsState;
end;


procedure TFormMain.pgcWorkspacesMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  TabIndex: Integer;
begin
  if (Button = mbMiddle) and (pgcWorkspaces.PageCount > 1) then
  begin
    TabIndex := pgcWorkspaces.IndexOfTabAt(X, Y);
    if TabIndex >= 0 then
      CloseTabByIndex(TabIndex);
  end;
end;

procedure TFormMain.mnuTabCloseOthersClick(Sender: TObject);
var
  CurSheet: TTabSheet;
  I: Integer;
begin
  CurSheet := pgcWorkspaces.ActivePage;
  if not Assigned(CurSheet) then Exit;

  for I := pgcWorkspaces.PageCount - 1 downto 0 do
  begin
    if pgcWorkspaces.Pages[I] <> CurSheet then
      CloseTabByIndex(I);
  end;
end;

procedure TFormMain.mnuTabCloseAllClick(Sender: TObject);
begin
  while pgcWorkspaces.PageCount > 1 do
    CloseTabByIndex(0);
end;

procedure TFormMain.HandleTreeOpenQuery(Sender: TObject; AProfile: TConnectionProfile; const ADBName, AInitialSQL: string);
begin
  CreateQueryTab(AProfile, ADBName, AInitialSQL);
end;

procedure TFormMain.HandleTreeShowData(Sender: TObject; AProfile: TConnectionProfile; const ADBName, ASchema, ATableName: string);
var
  SQLText: string;
begin
  if ASchema <> '' then
    SQLText := Format('SELECT * FROM %s.%s LIMIT 100;', [ASchema, ATableName])
  else
    SQLText := Format('SELECT * FROM %s LIMIT 100;', [ATableName]);

  CreateQueryTab(AProfile, ADBName, SQLText);
  actExecuteQueryExecute(Self);
end;

procedure TFormMain.HandleTreeShowDDL(Sender: TObject; AProfile: TConnectionProfile; const ADBName, ASchema, ATableName: string);
var
  Tab: TTabSheet;
  FrameDDL: TFrameTableDDL;
begin
  HideWelcomeDashboard;

  Tab := TTabSheet.Create(pgcWorkspaces);
  Tab.PageControl := pgcWorkspaces;
  Tab.Caption := Format('DDL: %s', [ATableName]);
  Tab.PopupMenu := popTabs;

  FrameDDL := TFrameTableDDL.Create(Tab);
  FrameDDL.Parent := Tab;
  FrameDDL.Align := alClient;
  FrameDDL.LoadDDL(AProfile, ADBName, ASchema, ATableName);

  pgcWorkspaces.ActivePage := Tab;
  UpdateActionsState;
end;

procedure TFormMain.mnuFileExitClick(Sender: TObject);
begin
  Close;
end;

procedure TFormMain.mnuHelpAboutClick(Sender: TObject);
begin
  TFormAbout.Execute(Self);
end;

procedure TFormMain.mnuDBUserManagerClick(Sender: TObject);
var
  Prof: TConnectionProfile;
begin
  Prof := GetSelectedProfile;
  if not Assigned(Prof) then
  begin
    MessageDlg('Information', 'Please select one of the active connection profiles first.', mtInformation, [mbOK], 0);
    Exit;
  end;

  if Prof.DriverType = dtSQLite then
  begin
    MessageDlg('Information', 'SQLite does not support a centralized user authentication and privilege system.', mtInformation, [mbOK], 0);
    Exit;
  end;

  TFormUserManager.Execute(Self, Prof);
end;

procedure TFormMain.mnuDBProcessListClick(Sender: TObject);
var
  Prof: TConnectionProfile;
begin
  Prof := GetSelectedProfile;
  if not Assigned(Prof) then
  begin
    MessageDlg('Information', 'Please select one of the active connection profiles first.', mtInformation, [mbOK], 0);
    Exit;
  end;

  if Prof.DriverType = dtSQLite then
  begin
    MessageDlg('Information', 'SQLite operates embedded and does not have a server process list.', mtInformation, [mbOK], 0);
    Exit;
  end;

  TFormProcessManager.Execute(Self, Prof);
end;

procedure TFormMain.mnuDBServerVariablesClick(Sender: TObject);
var
  Prof: TConnectionProfile;
begin
  Prof := GetSelectedProfile;
  if not Assigned(Prof) then
  begin
    MessageDlg('Information', 'Please select one of the active connection profiles first.', mtInformation, [mbOK], 0);
    Exit;
  end;

  TFormServerVariables.Execute(Self, Prof);
end;

procedure TFormMain.mnuDBERDViewerClick(Sender: TObject);
var
  Prof: TConnectionProfile;
begin
  Prof := GetSelectedProfile;
  if not Assigned(Prof) then
  begin
    MessageDlg('Information', 'Please select one of the active connection profiles first.', mtInformation, [mbOK], 0);
    Exit;
  end;

  if Assigned(FFERDViewer) then FFERDViewer.Free;

  FFERDViewer := TFormERDViewer.Create(Self);
  FFERDViewer.Parent := tbsERD;
  FFERDViewer.Align := alClient;
  FFERDViewer.BorderStyle := bsNone;
  FFERDViewer.Profile := Prof;
  FFERDViewer.Show;
end;

procedure TFormMain.mnuToolsImportDataClick(Sender: TObject);
var
  Prof: TConnectionProfile;
begin
  Prof := GetSelectedProfile;
  if not Assigned(Prof) then
  begin
    MessageDlg('Information', 'Please select one of the active database connections first.', mtInformation, [mbOK], 0);
    Exit;
  end;

  TFormImportData.Execute(Self, Prof);
end;

procedure TFormMain.mnuTableBuilderClick(Sender: TObject);
var
  Prof: TConnectionProfile;
begin
  Prof := GetSelectedProfile;
  if not Assigned(Prof) then
  begin
    MessageDlg('Information', 'Please select one of the active database connections first.', mtInformation, [mbOK], 0);
    Exit;
  end;

  TFormTableBuilder.Execute(Self, Prof);
end;

procedure TFormMain.mnuToolsSchemaDiffClick(Sender: TObject);
begin
  if not Assigned(FConnections) or (FConnections.Count < 2) then
  begin
    MessageDlg('Information', 'At least 2 registered database connections are required to compare schemas.', mtInformation, [mbOK], 0);
    Exit;
  end;

  TFormSchemaDiff.Execute(Self, FConnections, GetSelectedProfile);
end;

procedure TFormMain.mnuToolsAISettingsClick(Sender: TObject);
begin
  TFormAISettings.Execute(Self);
end;

procedure TFormMain.mnuToolsDataTransferClick(Sender: TObject);
begin
  if not Assigned(FConnections) or (FConnections.Count < 2) then
  begin
    MessageDlg('Information', 'A minimum of 2 registered database connection profiles is required to perform a direct data transfer.', mtInformation, [mbOK], 0);
    Exit;
  end;

  TFormDataTransfer.Execute(Self, FConnections, GetSelectedProfile);
end;

procedure TFormMain.mnuGridSettingsClick(Sender: TObject);
begin
  if TFormGridSettings.Execute(Self) then
  begin
    if Assigned(GetActiveQueryFrame) then
      GetActiveQueryFrame.RefreshGridDisplay;
  end;
end;

procedure TFormMain.actDisconnectExecute(Sender: TObject);
begin
  if Assigned(FCurrentProfile) then
    SQLLogger.LogComment(Format('Connection to %s Closed.', [FCurrentProfile.ConnectionName]));

  StopActiveSSHTunnel;
  FIsConnected := False;
  FFrameObjectTree.Clear;
  UpdateStatusBar('Connection Closed.');
  UpdateActionsState;
end;

procedure TFormMain.mnuToolsBackupRestoreClick(Sender: TObject);
begin
  if not Assigned(FConnections) or (FConnections.Count = 0) then
  begin
    MessageDlg('Information', 'Please add a database connection profile first.', mtInformation, [mbOK], 0);
    Exit;
  end;

  TFormBackupRestore.Execute(Self, FConnections, GetSelectedProfile);
end;

procedure TFormMain.mnuDBMetricsDashboardClick(Sender: TObject);
begin
  if not Assigned(FConnections) or (FConnections.Count = 0) then
  begin
    MessageDlg('Information', 'Please add a database connection profile first.', mtInformation, [mbOK], 0);
    Exit;
  end;

  // 1. Buat instance jika belum ada
  if not Assigned(FMetricsForm) then
  begin
    FMetricsForm := TFormLiveMetrics.Create(Self);
    FMetricsForm.BorderStyle := bsNone;
    FMetricsForm.Parent := pnlMetricsContainer;
    FMetricsForm.Align := alClient;
  end;

  // 2. Kirim data koneksi aktif ke form metrics
  FMetricsForm.EmbedToPanel(Self, pnlMetricsContainer, FConnections, GetSelectedProfile);
end;

procedure TFormMain.mnuCrosstabWizardClick(Sender: TObject);
var
  Prof: TConnectionProfile;
  GeneratedSQL: string;
begin
  Prof := GetSelectedProfile;
  if not Assigned(Prof) or not FIsConnected then
  begin
    MessageDlg('Information', 'Please connect to a database first.', mtInformation, [mbOK], 0);
    Exit;
  end;

  if TFormCrosstabBuilder.Execute(Self, Prof, Prof.DatabaseName, GeneratedSQL) then
  begin
    CreateQueryTab(Prof, Prof.DatabaseName, GeneratedSQL);
    actExecuteQueryExecute(Self);
  end;
end;

procedure TFormMain.mnuRESTGeneratorClick(Sender: TObject);
var
  Prof: TConnectionProfile;
begin
  Prof := GetSelectedProfile;
  if not Assigned(Prof) or not FIsConnected then
  begin
    MessageDlg('Information', 'Please connect to the active database connection first.', mtInformation, [mbOK], 0);
    Exit;
  end;

  TFormRESTGeneratorWizard.Execute(Self, Prof, Prof.DatabaseName);
end;

procedure TFormMain.mnuDBExtensionsClick(Sender: TObject);
var
  Profile: TConnectionProfile;
begin
  Profile := GetSelectedProfile;
  if not Assigned(Profile) then
  begin
    MessageDlg('Warning', 'Please select an active connection profile first.', mtWarning, [mbOK], 0);
    Exit;
  end;

  TFormExtensionManager.Execute(Self, Profile, Profile.DatabaseName);
end;

procedure TFormMain.OpenDBTerminalTab;
var
  Profile: TConnectionProfile;
  NewTab: TTabSheet;
begin
  Profile := GetSelectedProfile;
  if not Assigned(Profile) or not FIsConnected then
  begin
    MessageDlg('Warning', 'Please connect to one of the database connections first.', mtWarning, [mbOK], 0);
    Exit;
  end;

  HideWelcomeDashboard;

  // Buat TabSheet baru untuk CLI Terminal di dalam pgcWorkspaces
  NewTab := TTabSheet.Create(pgcWorkspaces);
  NewTab.PageControl := pgcWorkspaces;
  NewTab.Caption := '💻 Terminal (' + Profile.ConnectionName + ')';
  NewTab.PopupMenu := popTabs;

  FTerminalFrame := TFrameDBTerminal.Create(NewTab);
  FTerminalFrame.Parent := NewTab;
  FTerminalFrame.Align := alClient;
  FTerminalFrame.InitTerminal(Profile, Profile.DatabaseName);

  pgcWorkspaces.ActivePage := NewTab;
  UpdateActionsState;
end;



end.
