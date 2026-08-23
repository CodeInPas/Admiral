unit uFormExtensionManager;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  ComCtrls, StdCtrls, Buttons,
  uAppTypes, uDBTypes, uModelConnection, uDBExtensionService;

type
  { TFormExtensionManager }
  TFormExtensionManager = class(TForm)
    pnlToolbar: TPanel;
    btnRefresh: TSpeedButton;
    btnInstall: TSpeedButton;
    btnUninstall: TSpeedButton;
    btnLoadFile: TSpeedButton;
    sep1: TBevel;
    sep2: TBevel;
    lblSearch: TLabel;
    edtSearch: TEdit;

    lvExtensions: TListView;
    pnlBottom: TPanel;
    lblStatus: TLabel;
    btnClose: TBitBtn;
    openDialog: TOpenDialog;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);

    procedure btnRefreshClick(Sender: TObject);
    procedure btnInstallClick(Sender: TObject);
    procedure btnUninstallClick(Sender: TObject);
    procedure btnLoadFileClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure edtSearchChange(Sender: TObject);
    procedure lvExtensionsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
  private
    FProfile: TConnectionProfile;
    FDatabaseName: string;
    FExtensions: TExtensionInfoList;

    procedure ReloadExtensions;
    procedure PopulateList;
    procedure UpdateUIControls;
  public
    class procedure Execute(AOwner: TComponent; AProfile: TConnectionProfile; const ADBName: string = '');
    property Profile: TConnectionProfile read FProfile write FProfile;
    property DatabaseName: string read FDatabaseName write FDatabaseName;
  end;

implementation

{$R *.lfm}

{ TFormExtensionManager }

class procedure TFormExtensionManager.Execute(AOwner: TComponent; AProfile: TConnectionProfile; const ADBName: string);
var
  Dlg: TFormExtensionManager;
begin
  Dlg := TFormExtensionManager.Create(AOwner);
  try
    Dlg.Profile := AProfile;
    if ADBName <> '' then
      Dlg.DatabaseName := ADBName
    else if Assigned(AProfile) then
      Dlg.DatabaseName := AProfile.DatabaseName;
    Dlg.ShowModal;
  finally
    Dlg.Free;
  end;
end;

procedure TFormExtensionManager.FormCreate(Sender: TObject);
begin
  FProfile := TConnectionProfile.Create;
  FExtensions := TExtensionInfoList.Create(True);
end;

procedure TFormExtensionManager.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FExtensions);
  FreeAndNil(FProfile);
end;

procedure TFormExtensionManager.FormShow(Sender: TObject);
begin
  if Assigned(FProfile) then
  begin
    Caption := Format('Ekstensi & Plugin Manager - %s [%s]', [FProfile.ConnectionName, FDatabaseName]);
    ReloadExtensions;
  end;
end;

procedure TFormExtensionManager.ReloadExtensions;
var
  Err: string;
begin
  Screen.Cursor := crHourGlass;
  try
    if TDBExtensionService.FetchExtensions(FProfile, FDatabaseName, FExtensions, Err) then
    begin
      PopulateList;
      lblStatus.Caption := Format('Total: %d item terdaftar.', [FExtensions.Count]);
    end
    else
    begin
      MessageDlg('Gagal Memuat Ekstensi', Err, mtError, [mbOK], 0);
      lblStatus.Caption := 'Gagal mengambil data ekstensi.';
    end;
  finally
    Screen.Cursor := crDefault;
    UpdateUIControls;
  end;
end;

procedure TFormExtensionManager.PopulateList;
var
  I: Integer;
  Item: TListItem;
  Ext: TExtensionInfo;
  SearchKey: string;
begin
  lvExtensions.Items.BeginUpdate;
  try
    lvExtensions.Items.Clear;
    SearchKey := LowerCase(Trim(edtSearch.Text));

    for I := 0 to FExtensions.Count - 1 do
    begin
      Ext := FExtensions[I];

      if (SearchKey <> '') and (Pos(SearchKey, LowerCase(Ext.Name)) = 0) and
         (Pos(SearchKey, LowerCase(Ext.Description)) = 0) then
        Continue;

      Item := lvExtensions.Items.Add;
      Item.Caption := Ext.Name;
      Item.SubItems.Add(Ext.Status);
      Item.SubItems.Add(Ext.Version);
      Item.SubItems.Add(Ext.LibraryFile);
      Item.SubItems.Add(Ext.Description);
      Item.Data := Ext;
    end;
  finally
    lvExtensions.Items.EndUpdate;
  end;
end;

procedure TFormExtensionManager.UpdateUIControls;
var
  HasSel: Boolean;
  Ext: TExtensionInfo;
begin
  HasSel := Assigned(lvExtensions.Selected);
  btnLoadFile.Visible := (FProfile.DriverType in [dtSQLite, dtMySQL, dtMariaDB]);

  if HasSel then
  begin
    Ext := TExtensionInfo(lvExtensions.Selected.Data);
    btnInstall.Enabled := not Ext.Installed;
    btnUninstall.Enabled := Ext.Installed and (FProfile.DriverType <> dtSQLite);
  end
  else
  begin
    btnInstall.Enabled := (FProfile.DriverType in [dtPostgreSQL, dtMySQL, dtMariaDB]);
    btnUninstall.Enabled := False;
  end;
end;

procedure TFormExtensionManager.btnRefreshClick(Sender: TObject);
begin
  ReloadExtensions;
end;

procedure TFormExtensionManager.btnInstallClick(Sender: TObject);
var
  ExtName, Err: string;
  Ext: TExtensionInfo;
begin
  ExtName := '';
  if Assigned(lvExtensions.Selected) then
  begin
    Ext := TExtensionInfo(lvExtensions.Selected.Data);
    ExtName := Ext.Name;
  end;

  if ExtName = '' then
  begin
    if not InputQuery('Pasang Ekstensi', 'Nama Ekstensi / Komponen:', ExtName) then Exit;
    ExtName := Trim(ExtName);
    if ExtName = '' then Exit;
  end;

  Screen.Cursor := crHourGlass;
  try
    if TDBExtensionService.LoadOrInstallExtension(FProfile, FDatabaseName, ExtName, '', Err) then
    begin
      MessageDlg('Sukses', Format('Ekstensi/Plugin "%s" berhasil diaktifkan.', [ExtName]), mtInformation, [mbOK], 0);
      ReloadExtensions;
    end
    else
      MessageDlg('Gagal Memasang Ekstensi', Err, mtError, [mbOK], 0);
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFormExtensionManager.btnUninstallClick(Sender: TObject);
var
  Ext: TExtensionInfo;
  Err: string;
begin
  if not Assigned(lvExtensions.Selected) then Exit;
  Ext := TExtensionInfo(lvExtensions.Selected.Data);

  if MessageDlg('Konfirmasi', Format('Yakin ingin mencopot/menonaktifkan ekstensi "%s"?', [Ext.Name]),
    mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;

  Screen.Cursor := crHourGlass;
  try
    if TDBExtensionService.UnloadOrDropExtension(FProfile, FDatabaseName, Ext.Name, Err) then
    begin
      MessageDlg('Sukses', Format('Ekstensi "%s" berhasil dicopot.', [Ext.Name]), mtInformation, [mbOK], 0);
      ReloadExtensions;
    end
    else
      MessageDlg('Gagal Mencopot Ekstensi', Err, mtError, [mbOK], 0);
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFormExtensionManager.btnLoadFileClick(Sender: TObject);
var
  ExtName, Err: string;
begin
  {$IFDEF WINDOWS}
  openDialog.Filter := 'Dynamic Link Library (*.dll)|*.dll|All Files (*.*)|*.*';
  {$ELSE}
  openDialog.Filter := 'Shared Object (*.so)|*.so|All Files (*.*)|*.*';
  {$ENDIF}

  if openDialog.Execute then
  begin
    ExtName := ExtractFileName(openDialog.FileName);
    Screen.Cursor := crHourGlass;
    try
      if TDBExtensionService.LoadOrInstallExtension(FProfile, FDatabaseName, ExtName, openDialog.FileName, Err) then
      begin
        MessageDlg('Sukses', Format('Berkas ekstensi berhasil dimuat:%s%s', [LineEnding, openDialog.FileName]), mtInformation, [mbOK], 0);
        ReloadExtensions;
      end
      else
        MessageDlg('Gagal Memuat Berkas Library', Err, mtError, [mbOK], 0);
    finally
      Screen.Cursor := crDefault;
    end;
  end;
end;

procedure TFormExtensionManager.edtSearchChange(Sender: TObject);
begin
  PopulateList;
end;

procedure TFormExtensionManager.lvExtensionsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  UpdateUIControls;
end;

procedure TFormExtensionManager.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
