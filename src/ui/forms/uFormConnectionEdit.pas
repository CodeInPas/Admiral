unit uFormConnectionEdit;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Buttons, ComCtrls, ColorBox,
  uAppConst, uAppTypes, uDBTypes, uModelConnection, uDBConnectionFactory;

type
  { TFormConnectionEdit }
  TFormConnectionEdit = class(TForm)
    pnlBottom: TPanel;
    btnTest: TBitBtn;
    btnSave: TBitBtn;
    btnCancel: TBitBtn;

    pgcMain: TPageControl;
    tabGeneral: TTabSheet;
    tabAdvanced: TTabSheet;

    // Tab General
    lblConnName: TLabel;
    edtConnName: TEdit;
    lblDriverType: TLabel;
    cboDriverType: TComboBox;
    lblHost: TLabel;
    edtHost: TEdit;
    lblPort: TLabel;
    edtPort: TEdit;
    btnDefaultPort: TSpeedButton;
    lblDatabase: TLabel;
    edtDatabase: TEdit;
    btnBrowseDB: TSpeedButton;
    lblUsername: TLabel;
    edtUsername: TEdit;
    lblPassword: TLabel;
    edtPassword: TEdit;
    chkSavePassword: TCheckBox;

    // Tab Advanced
    lblCharset: TLabel;
    cboCharset: TComboBox;
    lblSSLMode: TLabel;
    cboSSLMode: TComboBox;
    lblTimeout: TLabel;
    edtTimeout: TEdit;
    lblGroup: TLabel;
    edtGroup: TEdit;
    lblColorTag: TLabel;
    colBoxTag: TColorBox;

    openDialog: TOpenDialog;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure cboDriverTypeChange(Sender: TObject);
    procedure btnDefaultPortClick(Sender: TObject);
    procedure btnBrowseDBClick(Sender: TObject);
    procedure btnTestClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
  private
    FProfile: TConnectionProfile;
    FIsEditMode: Boolean;

    procedure PopulateDriverList;
    procedure PopulateCharsetList;
    procedure PopulateSSLModes;
    procedure UpdateUIForDriver(const ADriverType: TDBDriverType);
    function GetSelectedDriverType: TDBDriverType;
    function GetSelectedSSLMode: TSSLMode;
    procedure LoadFromProfile(AProfile: TConnectionProfile);
    function ValidateInputs: Boolean;
  public
    procedure SetupNewConnection;
    procedure SetupEditConnection(AProfile: TConnectionProfile);
    procedure ApplyToProfile(AProfile: TConnectionProfile);

    class function CreateConnection(AOwner: TComponent; out AProfile: TConnectionProfile): Boolean;
    class function EditConnection(AOwner: TComponent; AProfile: TConnectionProfile): Boolean;

    property Profile: TConnectionProfile read FProfile;
    property IsEditMode: Boolean read FIsEditMode;
  end;

var
  FormConnectionEdit: TFormConnectionEdit;

implementation

{$R *.lfm}

{ TFormConnectionEdit }

class function TFormConnectionEdit.CreateConnection(AOwner: TComponent; out AProfile: TConnectionProfile): Boolean;
var
  Dlg: TFormConnectionEdit;
begin
  Result := False;
  AProfile := nil;
  Dlg := TFormConnectionEdit.Create(AOwner);
  try
    Dlg.SetupNewConnection;
    if Dlg.ShowModal = mrOk then
    begin
      AProfile := TConnectionProfile.Create;
      Dlg.ApplyToProfile(AProfile);
      Result := True;
    end;
  finally
    Dlg.Free;
  end;
end;

class function TFormConnectionEdit.EditConnection(AOwner: TComponent; AProfile: TConnectionProfile): Boolean;
var
  Dlg: TFormConnectionEdit;
begin
  Result := False;
  if not Assigned(AProfile) then Exit;

  Dlg := TFormConnectionEdit.Create(AOwner);
  try
    Dlg.SetupEditConnection(AProfile);
    if Dlg.ShowModal = mrOk then
    begin
      Dlg.ApplyToProfile(AProfile);
      Result := True;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TFormConnectionEdit.FormCreate(Sender: TObject);
begin
  FProfile := TConnectionProfile.Create;
  FIsEditMode := False;

  PopulateDriverList;
  PopulateCharsetList;
  PopulateSSLModes;
  pgcMain.ActivePage := tabGeneral;
end;

procedure TFormConnectionEdit.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FProfile);
end;

procedure TFormConnectionEdit.PopulateDriverList;
begin
  cboDriverType.Items.Clear;
  cboDriverType.Items.AddObject('SQLite 3', TObject(IntPtr(dtSQLite)));
  cboDriverType.Items.AddObject('MySQL', TObject(IntPtr(dtMySQL)));
  cboDriverType.Items.AddObject('MariaDB', TObject(IntPtr(dtMariaDB)));
  cboDriverType.Items.AddObject('Firebird', TObject(IntPtr(dtFirebird)));
  cboDriverType.Items.AddObject('PostgreSQL', TObject(IntPtr(dtPostgreSQL)));
  cboDriverType.ItemIndex := 0;
end;

procedure TFormConnectionEdit.PopulateCharsetList;
begin
  cboCharset.Items.Clear;
  cboCharset.Items.Add('UTF8');
  cboCharset.Items.Add('utf8mb4');
  cboCharset.Items.Add('LATIN1');
  cboCharset.Items.Add('WIN1251');
  cboCharset.Items.Add('WIN1252');
  cboCharset.Items.Add('NONE');
  cboCharset.ItemIndex := 0;
end;

procedure TFormConnectionEdit.PopulateSSLModes;
begin
  cboSSLMode.Items.Clear;
  cboSSLMode.Items.AddObject('Disabled', TObject(IntPtr(sslDisable)));
  cboSSLMode.Items.AddObject('Require', TObject(IntPtr(sslRequire)));
  cboSSLMode.Items.AddObject('Verify CA', TObject(IntPtr(sslVerifyCA)));
  cboSSLMode.Items.AddObject('Verify Full', TObject(IntPtr(sslVerifyFull)));
  cboSSLMode.ItemIndex := 0;
end;

function TFormConnectionEdit.GetSelectedDriverType: TDBDriverType;
begin
  if cboDriverType.ItemIndex >= 0 then
    Result := TDBDriverType(IntPtr(cboDriverType.Items.Objects[cboDriverType.ItemIndex]))
  else
    Result := dtSQLite;
end;

function TFormConnectionEdit.GetSelectedSSLMode: TSSLMode;
begin
  if cboSSLMode.ItemIndex >= 0 then
    Result := TSSLMode(IntPtr(cboSSLMode.Items.Objects[cboSSLMode.ItemIndex]))
  else
    Result := sslDisable;
end;

procedure TFormConnectionEdit.UpdateUIForDriver(const ADriverType: TDBDriverType);
var
  IsFileBased: Boolean;
begin
  IsFileBased := (ADriverType = dtSQLite);

  edtHost.Enabled := not IsFileBased;
  lblHost.Enabled := edtHost.Enabled;
  edtPort.Enabled := not IsFileBased;
  lblPort.Enabled := edtPort.Enabled;
  btnDefaultPort.Enabled := not IsFileBased;

  edtUsername.Enabled := not IsFileBased;
  lblUsername.Enabled := edtUsername.Enabled;
  edtPassword.Enabled := not IsFileBased;
  lblPassword.Enabled := edtPassword.Enabled;
  chkSavePassword.Enabled := not IsFileBased;

  cboSSLMode.Enabled := ADriverType in [dtMySQL, dtMariaDB, dtPostgreSQL];
  lblSSLMode.Enabled := cboSSLMode.Enabled;

  if IsFileBased then
    lblDatabase.Caption := 'Path Database (*.db;*.sqlite):'
  else if ADriverType = dtFirebird then
    lblDatabase.Caption := 'Path Database / Alias (.fdb):'
  else
    lblDatabase.Caption := 'Nama Database:';

  btnBrowseDB.Visible := ADriverType in [dtSQLite, dtFirebird];
end;

procedure TFormConnectionEdit.SetupNewConnection;
begin
  FIsEditMode := False;
  Caption := 'Tambah Profil Koneksi Database';
  edtConnName.Text := 'Koneksi Baru';
  cboDriverType.ItemIndex := 0;
  edtHost.Text := '127.0.0.1';
  edtPort.Text := '0';
  edtDatabase.Text := '';
  edtUsername.Text := '';
  edtPassword.Text := '';
  chkSavePassword.Checked := True;
  cboCharset.Text := 'UTF8';
  cboSSLMode.ItemIndex := 0;
  edtTimeout.Text := '15';
  edtGroup.Text := '';
  colBoxTag.Selected := clNone;

  cboDriverTypeChange(Self);
end;

procedure TFormConnectionEdit.SetupEditConnection(AProfile: TConnectionProfile);
begin
  FIsEditMode := True;
  Caption := Format('Edit Profil: %s', [AProfile.ConnectionName]);
  LoadFromProfile(AProfile);
end;

procedure TFormConnectionEdit.LoadFromProfile(AProfile: TConnectionProfile);
var
  I: Integer;
begin
  FProfile.Assign(AProfile);
  edtConnName.Text := FProfile.ConnectionName;

  for I := 0 to cboDriverType.Items.Count - 1 do
  begin
    if TDBDriverType(IntPtr(cboDriverType.Items.Objects[I])) = FProfile.DriverType then
    begin
      cboDriverType.ItemIndex := I;
      Break;
    end;
  end;

  edtHost.Text := FProfile.Host;
  edtPort.Text := IntToStr(FProfile.Port);
  edtDatabase.Text := FProfile.DatabaseName;
  edtUsername.Text := FProfile.Username;
  edtPassword.Text := FProfile.Password;
  chkSavePassword.Checked := FProfile.SavePassword;

  cboCharset.Text := FProfile.Charset;
  for I := 0 to cboSSLMode.Items.Count - 1 do
  begin
    if TSSLMode(IntPtr(cboSSLMode.Items.Objects[I])) = FProfile.SSLMode then
    begin
      cboSSLMode.ItemIndex := I;
      Break;
    end;
  end;

  edtTimeout.Text := IntToStr(FProfile.TimeoutSec);
  edtGroup.Text := FProfile.GroupFolder;

  if FProfile.ColorTag <> '' then
    colBoxTag.Selected := StringToColorDef(FProfile.ColorTag, clNone)
  else
    colBoxTag.Selected := clNone;

  UpdateUIForDriver(FProfile.DriverType);
end;

procedure TFormConnectionEdit.ApplyToProfile(AProfile: TConnectionProfile);
begin
  if not Assigned(AProfile) then Exit;

  AProfile.ConnectionName := Trim(edtConnName.Text);
  AProfile.DriverType := GetSelectedDriverType;
  AProfile.Host := Trim(edtHost.Text);
  AProfile.Port := StrToIntDef(Trim(edtPort.Text), 0);
  AProfile.DatabaseName := Trim(edtDatabase.Text);
  AProfile.Username := Trim(edtUsername.Text);

  AProfile.SavePassword := chkSavePassword.Checked;
  if AProfile.SavePassword then
    AProfile.Password := edtPassword.Text
  else
    AProfile.Password := '';

  AProfile.Charset := Trim(cboCharset.Text);
  AProfile.SSLMode := GetSelectedSSLMode;
  AProfile.TimeoutSec := StrToIntDef(Trim(edtTimeout.Text), 15);
  AProfile.GroupFolder := Trim(edtGroup.Text);

  if colBoxTag.Selected <> clNone then
    AProfile.ColorTag := ColorToString(colBoxTag.Selected)
  else
    AProfile.ColorTag := '';
end;

function TFormConnectionEdit.ValidateInputs: Boolean;
var
  Drv: TDBDriverType;
begin
  Result := False;

  if Trim(edtConnName.Text) = '' then
  begin
    MessageDlg('Validasi', 'Nama koneksi tidak boleh kosong.', mtWarning, [mbOK], 0);
    edtConnName.SetFocus;
    Exit;
  end;

  Drv := GetSelectedDriverType;

  if Drv = dtSQLite then
  begin
    if Trim(edtDatabase.Text) = '' then
    begin
      MessageDlg('Validasi', 'Lokasi berkas database SQLite harus ditentukan.', mtWarning, [mbOK], 0);
      edtDatabase.SetFocus;
      Exit;
    end;
  end
  else
  begin
    if Trim(edtHost.Text) = '' then
    begin
      MessageDlg('Validasi', 'Host / alamat server tidak boleh kosong.', mtWarning, [mbOK], 0);
      edtHost.SetFocus;
      Exit;
    end;
  end;

  Result := True;
end;

procedure TFormConnectionEdit.cboDriverTypeChange(Sender: TObject);
var
  Drv: TDBDriverType;
begin
  Drv := GetSelectedDriverType;
  UpdateUIForDriver(Drv);

  if not FIsEditMode or (Trim(edtPort.Text) = '0') then
    edtPort.Text := IntToStr(TDBConnectionFactory.GetDefaultPort(Drv));
end;

procedure TFormConnectionEdit.btnDefaultPortClick(Sender: TObject);
begin
  edtPort.Text := IntToStr(TDBConnectionFactory.GetDefaultPort(GetSelectedDriverType));
end;

procedure TFormConnectionEdit.btnBrowseDBClick(Sender: TObject);
var
  Drv: TDBDriverType;
begin
  Drv := GetSelectedDriverType;
  if Drv = dtSQLite then
    openDialog.Filter := 'SQLite Database (*.db;*.sqlite;*.sqlite3;*.db3)|*.db;*.sqlite;*.sqlite3;*.db3|All Files (*.*)|*.*'
  else if Drv = dtFirebird then
    openDialog.Filter := 'Firebird Database (*.fdb;*.gdb)|*.fdb;*.gdb|All Files (*.*)|*.*'
  else
    openDialog.Filter := 'All Files (*.*)|*.*';

  if openDialog.Execute then
    edtDatabase.Text := openDialog.FileName;
end;

procedure TFormConnectionEdit.btnTestClick(Sender: TObject);
var
  TempProfile: TConnectionProfile;
  ErrMsg: string;
  IsOk: Boolean;
begin
  if not ValidateInputs then Exit;

  TempProfile := TConnectionProfile.Create;
  try
    ApplyToProfile(TempProfile);
    Screen.Cursor := crHourGlass;
    try
      IsOk := TDBConnectionFactory.TestConnection(TempProfile, ErrMsg);
    finally
      Screen.Cursor := crDefault;
    end;

    if IsOk then
      MessageDlg('Uji Koneksi', 'Koneksi ke database server berhasil terhubung!', mtInformation, [mbOK], 0)
    else
      MessageDlg('Uji Koneksi Gagal', Format('Gagal terhubung ke database:%s%s', [LineEnding, ErrMsg]), mtError, [mbOK], 0);
  finally
    TempProfile.Free;
  end;
end;

procedure TFormConnectionEdit.btnSaveClick(Sender: TObject);
begin
  if ValidateInputs then
    ModalResult := mrOk;
end;

end.