unit uFormRESTGeneratorWizard;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  ComCtrls, StdCtrls, CheckLst, Buttons, Grids,
  uAppTypes, uDBTypes, uModelConnection, uDBDriverBase, uDBConnectionFactory,
  uModelSchemaObject, uModelRESTConfig, uRESTGeneratorNodeJS, uRESTGeneratorFastAPI,
  uRESTGeneratorGoFiber,uRESTGeneratorPHP;

type
  { TFormRESTGeneratorWizard }
  TFormRESTGeneratorWizard = class(TForm)
    pnlTop: TPanel;
    lblTitle: TLabel;
    lblSubtitle: TLabel;

    pgcSteps: TPageControl;
    tabTables: TTabSheet;
    tabOperations: TTabSheet;
    tabSettings: TTabSheet;

    // Tab 1: Pilihan Framework & Seleksi Tabel
    pnlFrameworkSelection: TPanel;
    lblSelectFramework: TLabel;
    cboFramework: TComboBox;
    pnlTableFilter: TPanel;
    edtFilterTable: TEdit;
    btnSelectAll: TSpeedButton;
    btnDeselectAll: TSpeedButton;
    clbTables: TCheckListBox;

    // Tab 2: Matriks Operasi CRUD
    pnlOpToolbar: TPanel;
    lblOpInfo: TLabel;
    gridOperations: TStringGrid;

    // Tab 3: Pengaturan Proyek
    lblPort: TLabel;
    edtPort: TEdit;
    lblBaseRoute: TLabel;
    edtBaseRoute: TEdit;
    chkEnableAuth: TCheckBox;
    lblApiKey: TLabel;
    edtApiKey: TEdit;
    lblOutDir: TLabel;
    edtOutDir: TEdit;
    btnBrowseDir: TSpeedButton;
    SelectDirectoryDialog: TSelectDirectoryDialog;

    // Footer Navigasi Wizard
    pnlBottom: TPanel;
    btnBack: TBitBtn;
    btnNext: TBitBtn;
    btnCancel: TBitBtn;

    procedure FormShow(Sender: TObject);
    procedure cboFrameworkChange(Sender: TObject);
    procedure edtFilterTableChange(Sender: TObject);
    procedure btnSelectAllClick(Sender: TObject);
    procedure btnDeselectAllClick(Sender: TObject);
    procedure chkEnableAuthChange(Sender: TObject);
    procedure btnBrowseDirClick(Sender: TObject);
    procedure btnNextClick(Sender: TObject);
    procedure btnBackClick(Sender: TObject);
  private
    FProfile: TConnectionProfile;
    FDatabaseName: string;
    FAllTables: TSchemaObjectList;
    FProjectConfig: TRestProjectConfig;

    procedure LoadTablesFromDatabase;
    procedure PopulateTableChecklist;
    procedure PopulateOperationsGrid;
    procedure SyncOperationsFromGrid;
    procedure DoGenerateBackend;
    procedure UpdateFrameworkUI;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    class procedure Execute(
      AOwner: TComponent;
      AProfile: TConnectionProfile;
      const ADBName: string
    );
  end;

implementation

{$R *.lfm}

{ TFormRESTGeneratorWizard }

constructor TFormRESTGeneratorWizard.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAllTables := TSchemaObjectList.Create(True);
  FProjectConfig := TRestProjectConfig.Create;
end;

destructor TFormRESTGeneratorWizard.Destroy;
begin
  FreeAndNil(FAllTables);
  FreeAndNil(FProjectConfig);
  inherited Destroy;
end;

class procedure TFormRESTGeneratorWizard.Execute(
  AOwner: TComponent;
  AProfile: TConnectionProfile;
  const ADBName: string
);
var
  Frm: TFormRESTGeneratorWizard;
begin
  if not Assigned(AProfile) then
  begin
    MessageDlg('Peringatan', 'Profil koneksi database aktif tidak ditemukan.', mtWarning, [mbOK], 0);
    Exit;
  end;

  Frm := TFormRESTGeneratorWizard.Create(AOwner);
  try
    Frm.FProfile := AProfile;
    Frm.FDatabaseName := ADBName;
    Frm.FProjectConfig.Profile := AProfile;
    Frm.FProjectConfig.DatabaseName := ADBName;
    Frm.ShowModal;
  finally
    Frm.Free;
  end;
end;

procedure TFormRESTGeneratorWizard.UpdateFrameworkUI;
begin
  if not Assigned(cboFramework) then Exit;

  case cboFramework.ItemIndex of
    0: // Node.js
    begin
      Caption := 'REST API Generator - Node.js (Express)';
      lblTitle.Caption := '🌐 Node.js (Express) REST API Generator';
      lblSubtitle.Caption := 'Menghasilkan backend Express.js modular, middleware keamanan, dan query pool siap pakai.';
      if Assigned(edtPort) and ((edtPort.Text = '8000') or (edtPort.Text = '8080') or (edtPort.Text = '80')) then
        edtPort.Text := '3000';
    end;
    1: // Python FastAPI
    begin
      Caption := 'REST API Generator - Python (FastAPI + Swagger Docs)';
      lblTitle.Caption := '🐍 Python (FastAPI) REST API Generator';
      lblSubtitle.Caption := 'Menghasilkan arsitektur backend asynchronous Python lengkap dengan dokumentasi OpenAPI Swagger UI.';
      if Assigned(edtPort) and ((edtPort.Text = '3000') or (edtPort.Text = '8080') or (edtPort.Text = '80')) then
        edtPort.Text := '8000';
    end;
    2: // Go Fiber
    begin
      Caption := 'REST API Generator - Go (Fiber High Performance)';
      lblTitle.Caption := '🚀 Go (Fiber) REST API Generator';
      lblSubtitle.Caption := 'Menghasilkan backend Go berkecepatan tinggi, concurrency ringan, dan siap build single binary executable.';
      if Assigned(edtPort) and ((edtPort.Text = '3000') or (edtPort.Text = '8000') or (edtPort.Text = '80')) then
        edtPort.Text := '8080';
    end;
    3: // PHP PDO
    begin
      Caption := 'REST API Generator - PHP (Native PDO)';
      lblTitle.Caption := '🐘 PHP (Native PDO) REST API Generator';
      lblSubtitle.Caption := 'Menghasilkan backend PHP murni tanpa composer dependensi, siap deploy langsung ke cPanel / Apache.';
      if Assigned(edtPort) and ((edtPort.Text = '3000') or (edtPort.Text = '8000') or (edtPort.Text = '8080')) then
        edtPort.Text := '80';
    end;
  end;
end;

procedure TFormRESTGeneratorWizard.FormShow(Sender: TObject);
begin
  pgcSteps.ActivePageIndex := 0;
  btnBack.Enabled := False;
  btnNext.Caption := 'Lanjut ➔';

  if Assigned(cboFramework) then
  begin
    cboFramework.Items.Clear;
    cboFramework.Items.Add('Node.js (Express.js)');
    cboFramework.Items.Add('Python (FastAPI + Swagger OpenAPI)');
    cboFramework.Items.Add('Go (Fiber Clean Architecture)');
    cboFramework.Items.Add('PHP (Native PDO / Zero-Dependency cPanel)');
    cboFramework.ItemIndex := 0;
    UpdateFrameworkUI;
  end;

  if Assigned(gridOperations) then
  begin
    gridOperations.ColCount := 7;
    gridOperations.RowCount := 1;
    gridOperations.Cells[0, 0] := 'Nama Tabel';
    gridOperations.Cells[1, 0] := 'Rute URL';
    gridOperations.Cells[2, 0] := 'GET List (1/0)';
    gridOperations.Cells[3, 0] := 'GET Detail (1/0)';
    gridOperations.Cells[4, 0] := 'POST (1/0)';
    gridOperations.Cells[5, 0] := 'PUT (1/0)';
    gridOperations.Cells[6, 0] := 'DELETE (1/0)';

    gridOperations.ColWidths[0] := 140;
    gridOperations.ColWidths[1] := 140;
    gridOperations.ColWidths[2] := 80;
    gridOperations.ColWidths[3] := 80;
    gridOperations.ColWidths[4] := 80;
    gridOperations.ColWidths[5] := 80;
    gridOperations.ColWidths[6] := 80;
  end;

  LoadTablesFromDatabase;
end;

procedure TFormRESTGeneratorWizard.cboFrameworkChange(Sender: TObject);
begin
  UpdateFrameworkUI;
end;

procedure TFormRESTGeneratorWizard.LoadTablesFromDatabase;
var
  Driver: TDBDriverBase;
begin
  if not Assigned(FAllTables) then Exit;
  FAllTables.Clear;
  if not Assigned(FProfile) then Exit;

  Driver := nil;
  try
    try
      Driver := TDBConnectionFactory.CreateDriver(FProfile);
      if Assigned(Driver) then
      begin
        Driver.ExtractTables(FDatabaseName, '', FAllTables);
        PopulateTableChecklist;
      end;
    except
      on E: Exception do
        MessageDlg('Gagal Membaca Skema', 'Kesalahan membaca daftar tabel: ' + E.Message, mtError, [mbOK], 0);
    end;
  finally
    if Assigned(Driver) then Driver.Free;
  end;
end;

procedure TFormRESTGeneratorWizard.PopulateTableChecklist;
var
  I: Integer;
  FilterText: string;
begin
  if not Assigned(clbTables) or not Assigned(FAllTables) then Exit;
  clbTables.Items.Clear;

  if Assigned(edtFilterTable) then
    FilterText := LowerCase(Trim(edtFilterTable.Text))
  else
    FilterText := '';

  for I := 0 to FAllTables.Count - 1 do
  begin
    if Assigned(FAllTables[I]) then
    begin
      if (FilterText = '') or (Pos(FilterText, LowerCase(FAllTables[I].Name)) > 0) then
        clbTables.Items.AddObject(FAllTables[I].Name, FAllTables[I]);
    end;
  end;
end;

procedure TFormRESTGeneratorWizard.edtFilterTableChange(Sender: TObject);
begin
  PopulateTableChecklist;
end;

procedure TFormRESTGeneratorWizard.btnSelectAllClick(Sender: TObject);
var
  I: Integer;
begin
  if Assigned(clbTables) then
    for I := 0 to clbTables.Items.Count - 1 do
      clbTables.Checked[I] := True;
end;

procedure TFormRESTGeneratorWizard.btnDeselectAllClick(Sender: TObject);
var
  I: Integer;
begin
  if Assigned(clbTables) then
    for I := 0 to clbTables.Items.Count - 1 do
      clbTables.Checked[I] := False;
end;

procedure TFormRESTGeneratorWizard.chkEnableAuthChange(Sender: TObject);
begin
  if Assigned(edtApiKey) and Assigned(chkEnableAuth) then
    edtApiKey.Enabled := chkEnableAuth.Checked;
end;

procedure TFormRESTGeneratorWizard.btnBrowseDirClick(Sender: TObject);
begin
  if Assigned(SelectDirectoryDialog) and SelectDirectoryDialog.Execute then
  begin
    if Assigned(edtOutDir) then
      edtOutDir.Text := SelectDirectoryDialog.FileName;
  end;
end;

procedure TFormRESTGeneratorWizard.PopulateOperationsGrid;
var
  I, R: Integer;
  Obj: TSchemaObject;
  TblCfg: TRestTableConfig;
  IsViewObj: Boolean;
begin
  if not Assigned(FProjectConfig) or not Assigned(gridOperations) or not Assigned(clbTables) then Exit;

  FProjectConfig.Clear;
  gridOperations.RowCount := 1;

  for I := 0 to clbTables.Items.Count - 1 do
  begin
    if clbTables.Checked[I] and Assigned(clbTables.Items.Objects[I]) then
    begin
      Obj := TSchemaObject(clbTables.Items.Objects[I]);
      IsViewObj := (Obj.ObjectType = sotView);
      TblCfg := FProjectConfig.AddTable(Obj.Name, IsViewObj);

      gridOperations.RowCount := gridOperations.RowCount + 1;
      R := gridOperations.RowCount - 1;
      gridOperations.Cells[0, R] := TblCfg.TableName;
      gridOperations.Cells[1, R] := TblCfg.CustomRoute;

      gridOperations.Cells[2, R] := '1';
      gridOperations.Cells[3, R] := '1';
      if TblCfg.IsView then
      begin
        gridOperations.Cells[4, R] := '0';
        gridOperations.Cells[5, R] := '0';
        gridOperations.Cells[6, R] := '0';
      end
      else
      begin
        gridOperations.Cells[4, R] := '1';
        gridOperations.Cells[5, R] := '1';
        gridOperations.Cells[6, R] := '1';
      end;
    end;
  end;
end;

procedure TFormRESTGeneratorWizard.SyncOperationsFromGrid;
var
  I: Integer;
  TblCfg: TRestTableConfig;
  Ops: TRestOperations;
begin
  if not Assigned(FProjectConfig) or not Assigned(gridOperations) then Exit;

  for I := 1 to gridOperations.RowCount - 1 do
  begin
    if (I - 1) < FProjectConfig.TableCount then
    begin
      TblCfg := FProjectConfig.Tables[I - 1];
      TblCfg.CustomRoute := Trim(gridOperations.Cells[1, I]);
      Ops := [];
      if Trim(gridOperations.Cells[2, I]) = '1' then Include(Ops, roList);
      if Trim(gridOperations.Cells[3, I]) = '1' then Include(Ops, roDetail);
      if Trim(gridOperations.Cells[4, I]) = '1' then Include(Ops, roCreate);
      if Trim(gridOperations.Cells[5, I]) = '1' then Include(Ops, roUpdate);
      if Trim(gridOperations.Cells[6, I]) = '1' then Include(Ops, roDelete);
      TblCfg.AllowedOperations := Ops;
    end;
  end;
end;

procedure TFormRESTGeneratorWizard.btnNextClick(Sender: TObject);
var
  CheckedCount, I: Integer;
begin
  if pgcSteps.ActivePageIndex = 0 then
  begin
    CheckedCount := 0;
    if Assigned(clbTables) then
    begin
      for I := 0 to clbTables.Items.Count - 1 do
        if clbTables.Checked[I] then Inc(CheckedCount);
    end;

    if CheckedCount = 0 then
    begin
      MessageDlg('Peringatan', 'Pilih minimal 1 tabel atau view untuk digenerate.', mtWarning, [mbOK], 0);
      Exit;
    end;

    PopulateOperationsGrid;
    pgcSteps.ActivePageIndex := 1;
    btnBack.Enabled := True;
  end
  else if pgcSteps.ActivePageIndex = 1 then
  begin
    SyncOperationsFromGrid;
    pgcSteps.ActivePageIndex := 2;
    btnNext.Caption := '⚡ Generate Proyek';
  end
  else if pgcSteps.ActivePageIndex = 2 then
  begin
    DoGenerateBackend;
  end;
end;

procedure TFormRESTGeneratorWizard.btnBackClick(Sender: TObject);
begin
  if pgcSteps.ActivePageIndex > 0 then
  begin
    pgcSteps.ActivePageIndex := pgcSteps.ActivePageIndex - 1;
    btnNext.Caption := 'Lanjut ➔';
    btnBack.Enabled := (pgcSteps.ActivePageIndex > 0);
  end;
end;

procedure TFormRESTGeneratorWizard.DoGenerateBackend;
var
  ErrMsg, FrameworkName: string;
  Success: Boolean;
begin
  if not Assigned(FProjectConfig) then Exit;

  if Trim(edtOutDir.Text) = '' then
  begin
    MessageDlg('Peringatan', 'Tentukan folder tujuan penyimpanan proyek.', mtWarning, [mbOK], 0);
    Exit;
  end;

  FProjectConfig.ServerPort := StrToIntDef(edtPort.Text, 80);
  FProjectConfig.BaseRoute := Trim(edtBaseRoute.Text);
  FProjectConfig.EnableAuth := chkEnableAuth.Checked;
  FProjectConfig.ApiKey := Trim(edtApiKey.Text);
  FProjectConfig.OutputDirectory := Trim(edtOutDir.Text);

  Screen.Cursor := crHourGlass;
  try
    case cboFramework.ItemIndex of
      1:
      begin
        FrameworkName := 'Python (FastAPI)';
        FProjectConfig.TargetFramework := 'fastapi';
        Success := TRESTEngineFastAPI.GenerateProject(FProjectConfig, ErrMsg);
      end;
      2:
      begin
        FrameworkName := 'Go (Fiber)';
        FProjectConfig.TargetFramework := 'go_fiber';
        Success := TRESTEngineGoFiber.GenerateProject(FProjectConfig, ErrMsg);
      end;
      3:
      begin
        FrameworkName := 'PHP (Native PDO)';
        FProjectConfig.TargetFramework := 'php_pdo';
        Success := TRESTEnginePHP.GenerateProject(FProjectConfig, ErrMsg);
      end;
      else
      begin
        FrameworkName := 'Node.js (Express)';
        FProjectConfig.TargetFramework := 'node_express';
        Success := TRESTEngineNodeJS.GenerateProject(FProjectConfig, ErrMsg);
      end;
    end;

    if Success then
    begin
      MessageDlg('Sukses', Format('Proyek %s REST API berhasil digenerate di:%s%s', [FrameworkName, LineEnding, FProjectConfig.OutputDirectory]), mtInformation, [mbOK], 0);
      ModalResult := mrOk;
    end
    else
      MessageDlg('Gagal Generate', ErrMsg, mtError, [mbOK], 0);
  finally
    Screen.Cursor := crDefault;
  end;
end;

end.
