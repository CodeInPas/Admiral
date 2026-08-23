unit uFormUserManager;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  ComCtrls, StdCtrls, Buttons, Menus, SynEdit, SynHighlighterSQL,
  uAppTypes, uDBTypes, uModelConnection, uDBUserManagerService;

type
  { TFormUserManager }
  TFormUserManager = class(TForm)
    pnlLeft: TPanel;
    splMain: TSplitter;
    pnlClient: TPanel;

    // Toolbar Kiri
    pnlLeftToolbar: TPanel;
    btnNewUser: TSpeedButton;
    btnDeleteUser: TSpeedButton;
    btnChangePass: TSpeedButton;
    btnRefreshUsers: TSpeedButton;
    lvUsers: TListView;

    // Header Detail Kanan
    pnlUserDetailHeader: TPanel;
    lblSelectedUser: TLabel;
    lblUserMeta: TLabel;

    // Workspace Kanan
    pgcDetail: TPageControl;
    tabPrivileges: TTabSheet;
    tabActiveGrants: TTabSheet;
    tabSQLPreview: TTabSheet;

    // Kontrol Hak Akses
    pnlPrivTop: TPanel;
    lblTargetDB: TLabel;
    cboTargetDB: TComboBox;
    chkGrantOption: TCheckBox;

    gbPrivileges: TGroupBox;
    chkSelect: TCheckBox;
    chkInsert: TCheckBox;
    chkUpdate: TCheckBox;
    chkDelete: TCheckBox;
    chkCreate: TCheckBox;
    chkDrop: TCheckBox;
    chkAlter: TCheckBox;
    chkExecute: TCheckBox;
    chkReferences: TCheckBox;

    pnlPrivActions: TPanel;
    btnSelectAllPrivs: TBitBtn;
    btnClearAllPrivs: TBitBtn;
    btnApplyGrant: TBitBtn;
    btnApplyRevoke: TBitBtn;

    // List Grants Aktif & SQL Preview
    memGrants: TMemo;
    synSQLPreview: TSynEdit;
    synSQLSyn: TSynSQLSyn;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);

    procedure btnRefreshUsersClick(Sender: TObject);
    procedure lvUsersSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure btnNewUserClick(Sender: TObject);
    procedure btnDeleteUserClick(Sender: TObject);
    procedure btnChangePassClick(Sender: TObject);

    procedure btnSelectAllPrivsClick(Sender: TObject);
    procedure btnClearAllPrivsClick(Sender: TObject);
    procedure btnApplyGrantClick(Sender: TObject);
    procedure btnApplyRevokeClick(Sender: TObject);
    procedure chkPrivChange(Sender: TObject);
  private
    FProfile: TConnectionProfile;
    FUserList: TList;
    FCurrentUserInfo: TDBUserInfo;

    procedure ClearUserList;
    procedure ReloadUsers;
    procedure LoadUserDetail(AUser: TDBUserInfo);
    procedure UpdateSQLPreview;
    function CollectSelectedPrivileges: TStringList;
  public
    class procedure Execute(AOwner: TComponent; AProfile: TConnectionProfile);
    property Profile: TConnectionProfile read FProfile write FProfile;
  end;

implementation

{$R *.lfm}

{ TFormUserManager }

class procedure TFormUserManager.Execute(AOwner: TComponent; AProfile: TConnectionProfile);
var
  Frm: TFormUserManager;
begin
  Frm := TFormUserManager.Create(AOwner);
  try
    Frm.Profile := AProfile;
    Frm.ShowModal;
  finally
    Frm.Free;
  end;
end;

procedure TFormUserManager.FormCreate(Sender: TObject);
begin
  FUserList := TList.Create;
  FCurrentUserInfo := nil;
  synSQLPreview.Highlighter := synSQLSyn;
  synSQLPreview.ReadOnly := True;
end;

procedure TFormUserManager.FormDestroy(Sender: TObject);
begin
  ClearUserList;
  FUserList.Free;
end;

procedure TFormUserManager.FormShow(Sender: TObject);
begin
  if Assigned(FProfile) then
  begin
    Caption := Format('Manajemen Pengguna & Hak Akses - %s (%s)', [FProfile.ConnectionName, FProfile.GetDisplayName]);
    ReloadUsers;
  end;
end;

procedure TFormUserManager.ClearUserList;
var
  I: Integer;
begin
  for I := 0 to FUserList.Count - 1 do
    TDBUserInfo(FUserList[I]).Free;
  FUserList.Clear;
  lvUsers.Items.Clear;
  FCurrentUserInfo := nil;
end;

procedure TFormUserManager.ReloadUsers;
var
  Err: string;
  I: Integer;
  UInfo: TDBUserInfo;
  ListItem: TListItem;
begin
  ClearUserList;
  Screen.Cursor := crHourGlass;
  try
    if not TDBUserManagerService.FetchUsers(FProfile, FUserList, Err) then
    begin
      MessageDlg('Perhatian', Err, mtWarning, [mbOK], 0);
      Exit;
    end;

    lvUsers.Items.BeginUpdate;
    try
      for I := 0 to FUserList.Count - 1 do
      begin
        UInfo := TDBUserInfo(FUserList[I]);
        ListItem := lvUsers.Items.Add;
        ListItem.Caption := UInfo.Username;
        ListItem.SubItems.Add(UInfo.Host);
        if UInfo.IsSuperUser then
          ListItem.SubItems.Add('Ya')
        else
          ListItem.SubItems.Add('Tidak');
        ListItem.Data := UInfo;
      end;
    finally
      lvUsers.Items.EndUpdate;
    end;

    if lvUsers.Items.Count > 0 then
      lvUsers.ItemIndex := 0;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFormUserManager.lvUsersSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  if Selected and Assigned(Item) and Assigned(Item.Data) then
  begin
    FCurrentUserInfo := TDBUserInfo(Item.Data);
    LoadUserDetail(FCurrentUserInfo);
  end
  else
  begin
    FCurrentUserInfo := nil;
    lblSelectedUser.Caption := 'Tidak ada user yang dipilih';
    lblUserMeta.Caption := '';
    memGrants.Clear;
    synSQLPreview.Clear;
  end;
end;

procedure TFormUserManager.LoadUserDetail(AUser: TDBUserInfo);
var
  Grants: TStringList;
  Err: string;
begin
  lblSelectedUser.Caption := Format('User: %s (Host: %s)', [AUser.Username, AUser.Host]);
  if AUser.IsSuperUser then
    lblUserMeta.Caption := 'Role: SUPERUSER / ADMINISTRATOR'
  else
    lblUserMeta.Caption := 'Role: Standard User';

  Grants := TStringList.Create;
  try
    if TDBUserManagerService.FetchUserGrants(FProfile, AUser.Username, AUser.Host, Grants, Err) then
      memGrants.Lines.Assign(Grants)
    else
      memGrants.Lines.Text := '-- Gagal memuat hak akses: ' + Err;
  finally
    Grants.Free;
  end;

  UpdateSQLPreview;
end;

function TFormUserManager.CollectSelectedPrivileges: TStringList;
begin
  Result := TStringList.Create;
  if chkSelect.Checked then Result.Add('SELECT');
  if chkInsert.Checked then Result.Add('INSERT');
  if chkUpdate.Checked then Result.Add('UPDATE');
  if chkDelete.Checked then Result.Add('DELETE');
  if chkCreate.Checked then Result.Add('CREATE');
  if chkDrop.Checked then Result.Add('DROP');
  if chkAlter.Checked then Result.Add('ALTER');
  if chkExecute.Checked then Result.Add('EXECUTE');
  if chkReferences.Checked then Result.Add('REFERENCES');
end;

procedure TFormUserManager.UpdateSQLPreview;
var
  Privs: TStringList;
  PrivsStr, Target, UserName: string;
  I: Integer;
begin
  if not Assigned(FCurrentUserInfo) then
  begin
    synSQLPreview.Clear;
    Exit;
  end;

  Privs := CollectSelectedPrivileges;
  try
    PrivsStr := '';
    for I := 0 to Privs.Count - 1 do
    begin
      if I > 0 then PrivsStr := PrivsStr + ', ';
      PrivsStr := PrivsStr + Privs[I];
    end;

    if PrivsStr = '' then PrivsStr := '[PILIH_PRIVILEGE]';

    Target := Trim(cboTargetDB.Text);
    if Target = '' then Target := '*.*';
    UserName := FCurrentUserInfo.Username;

    synSQLPreview.Lines.Clear;
    synSQLPreview.Lines.Add('-- Contoh Query GRANT:');
    if FProfile.DriverType in [dtMySQL, dtMariaDB] then
    begin
      synSQLPreview.Lines.Add(Format('GRANT %s ON %s TO ''%s''@''%s'';', [PrivsStr, Target, UserName, FCurrentUserInfo.Host]));
      synSQLPreview.Lines.Add('FLUSH PRIVILEGES;');
      synSQLPreview.Lines.Add('');
      synSQLPreview.Lines.Add('-- Contoh Query REVOKE:');
      synSQLPreview.Lines.Add(Format('REVOKE %s ON %s FROM ''%s''@''%s'';', [PrivsStr, Target, UserName, FCurrentUserInfo.Host]));
      synSQLPreview.Lines.Add('FLUSH PRIVILEGES;');
    end
    else
    begin
      synSQLPreview.Lines.Add(Format('GRANT %s ON %s TO "%s";', [PrivsStr, Target, UserName]));
      synSQLPreview.Lines.Add('');
      synSQLPreview.Lines.Add('-- Contoh Query REVOKE:');
      synSQLPreview.Lines.Add(Format('REVOKE %s ON %s FROM "%s";', [PrivsStr, Target, UserName]));
    end;
  finally
    Privs.Free;
  end;
end;

procedure TFormUserManager.chkPrivChange(Sender: TObject);
begin
  UpdateSQLPreview;
end;

procedure TFormUserManager.btnSelectAllPrivsClick(Sender: TObject);
begin
  chkSelect.Checked := True;
  chkInsert.Checked := True;
  chkUpdate.Checked := True;
  chkDelete.Checked := True;
  chkCreate.Checked := True;
  chkDrop.Checked := True;
  chkAlter.Checked := True;
  chkExecute.Checked := True;
  chkReferences.Checked := True;
  UpdateSQLPreview;
end;

procedure TFormUserManager.btnClearAllPrivsClick(Sender: TObject);
begin
  chkSelect.Checked := False;
  chkInsert.Checked := False;
  chkUpdate.Checked := False;
  chkDelete.Checked := False;
  chkCreate.Checked := False;
  chkDrop.Checked := False;
  chkAlter.Checked := False;
  chkExecute.Checked := False;
  chkReferences.Checked := False;
  UpdateSQLPreview;
end;

procedure TFormUserManager.btnApplyGrantClick(Sender: TObject);
var
  Privs: TStringList;
  Err: string;
begin
  if not Assigned(FCurrentUserInfo) then Exit;

  Privs := CollectSelectedPrivileges;
  try
    if Privs.Count = 0 then
    begin
      MessageDlg('Peringatan', 'Pilih minimal satu hak akses yang ingin diberikan.', mtWarning, [mbOK], 0);
      Exit;
    end;

    Screen.Cursor := crHourGlass;
    try
      if TDBUserManagerService.ApplyPrivileges(FProfile, FCurrentUserInfo.Username, FCurrentUserInfo.Host,
        Trim(cboTargetDB.Text), Privs, True, chkGrantOption.Checked, Err) then
      begin
        MessageDlg('Sukses', 'Hak akses (GRANT) berhasil diterapkan.', mtInformation, [mbOK], 0);
        LoadUserDetail(FCurrentUserInfo);
      end
      else
        MessageDlg('Gagal Menerapkan GRANT', Err, mtError, [mbOK], 0);
    finally
      Screen.Cursor := crDefault;
    end;
  finally
    Privs.Free;
  end;
end;

procedure TFormUserManager.btnApplyRevokeClick(Sender: TObject);
var
  Privs: TStringList;
  Err: string;
begin
  if not Assigned(FCurrentUserInfo) then Exit;

  Privs := CollectSelectedPrivileges;
  try
    if Privs.Count = 0 then
    begin
      MessageDlg('Peringatan', 'Pilih minimal satu hak akses yang ingin dicabut.', mtWarning, [mbOK], 0);
      Exit;
    end;

    if MessageDlg('Konfirmasi', Format('Cabut hak akses terpilih dari user "%s"?', [FCurrentUserInfo.Username]),
      mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

    Screen.Cursor := crHourGlass;
    try
      if TDBUserManagerService.ApplyPrivileges(FProfile, FCurrentUserInfo.Username, FCurrentUserInfo.Host,
        Trim(cboTargetDB.Text), Privs, False, False, Err) then
      begin
        MessageDlg('Sukses', 'Hak akses (REVOKE) berhasil dicabut.', mtInformation, [mbOK], 0);
        LoadUserDetail(FCurrentUserInfo);
      end
      else
        MessageDlg('Gagal Mencabut Hak Akses', Err, mtError, [mbOK], 0);
    finally
      Screen.Cursor := crDefault;
    end;
  finally
    Privs.Free;
  end;
end;

procedure TFormUserManager.btnNewUserClick(Sender: TObject);
var
  UName, UHost, UPass, Err: string;
  IsAdmin: Boolean;
begin
  UName := '';
  if not InputQuery('Buat User Baru', 'Nama User:', UName) or (Trim(UName) = '') then Exit;

  UHost := '%';
  if FProfile.DriverType in [dtMySQL, dtMariaDB] then
    InputQuery('Host/IP', 'Host (misal % atau localhost):', UHost);

  UPass := '';
  if not InputQuery('Password', 'Password Akun:', UPass) then Exit;

  IsAdmin := (MessageDlg('Privilege Administrator', 'Jadikan user ini sebagai Superuser/Admin?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes);

  Screen.Cursor := crHourGlass;
  try
    if TDBUserManagerService.CreateUser(FProfile, Trim(UName), Trim(UHost), UPass, IsAdmin, Err) then
    begin
      MessageDlg('Sukses', Format('User "%s" berhasil dibuat.', [UName]), mtInformation, [mbOK], 0);
      ReloadUsers;
    end
    else
      MessageDlg('Gagal Membuat User', Err, mtError, [mbOK], 0);
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFormUserManager.btnDeleteUserClick(Sender: TObject);
var
  Err: string;
begin
  if not Assigned(FCurrentUserInfo) then Exit;

  if MessageDlg('Hapus User', Format('Hapus akun user "%s"? Tindakan ini tidak dapat dibatalkan.', [FCurrentUserInfo.Username]),
    mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;

  Screen.Cursor := crHourGlass;
  try
    if TDBUserManagerService.DropUser(FProfile, FCurrentUserInfo.Username, FCurrentUserInfo.Host, Err) then
    begin
      MessageDlg('Sukses', 'User berhasil dihapus.', mtInformation, [mbOK], 0);
      ReloadUsers;
    end
    else
      MessageDlg('Gagal Menghapus User', Err, mtError, [mbOK], 0);
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFormUserManager.btnChangePassClick(Sender: TObject);
var
  NewPass, Err: string;
begin
  if not Assigned(FCurrentUserInfo) then Exit;

  NewPass := '';
  if not InputQuery('Ubah Password', Format('Password baru untuk "%s":', [FCurrentUserInfo.Username]), NewPass) then Exit;

  Screen.Cursor := crHourGlass;
  try
    if TDBUserManagerService.ChangePassword(FProfile, FCurrentUserInfo.Username, FCurrentUserInfo.Host, NewPass, Err) then
      MessageDlg('Sukses', 'Password user berhasil diperbarui.', mtInformation, [mbOK], 0)
    else
      MessageDlg('Gagal Mengubah Password', Err, mtError, [mbOK], 0);
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFormUserManager.btnRefreshUsersClick(Sender: TObject);
begin
  ReloadUsers;
end;

end.
