unit uFormProcessManager;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  ComCtrls, StdCtrls, Buttons, SynEdit, SynHighlighterSQL,
  uAppTypes, uDBTypes, uModelConnection, uDBProcessManagerService;

type
  { TFormProcessManager }
  TFormProcessManager = class(TForm)
    pnlToolbar: TPanel;
    btnRefresh: TSpeedButton;
    btnCancelQuery: TSpeedButton;
    btnKillSession: TSpeedButton;
    sepTool1: TBevel;
    chkAutoRefresh: TCheckBox;
    cboInterval: TComboBox;
    lblInterval: TLabel;
    edtSearch: TEdit;
    lblSearch: TLabel;

    lvProcesses: TListView;
    splBottom: TSplitter;
    pnlBottomQuery: TPanel;
    pnlQueryHeader: TPanel;
    lblQueryTitle: TLabel;
    synQuery: TSynEdit;
    synSQLSyn: TSynSQLSyn;

    tmrRefresh: TTimer;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);

    procedure btnRefreshClick(Sender: TObject);
    procedure btnCancelQueryClick(Sender: TObject);
    procedure btnKillSessionClick(Sender: TObject);
    procedure chkAutoRefreshChange(Sender: TObject);
    procedure cboIntervalChange(Sender: TObject);
    procedure edtSearchChange(Sender: TObject);
    procedure lvProcessesSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure tmrRefreshTimer(Sender: TObject);
  private
    FProfile: TConnectionProfile;
    FProcessList: TList;
    FSelectedProcess: TDBProcessInfo;

    procedure ClearProcessList;
    procedure ReloadProcesses;
    procedure PopulateListView;
  public
    class procedure Execute(AOwner: TComponent; AProfile: TConnectionProfile);
    property Profile: TConnectionProfile read FProfile write FProfile;
  end;

implementation

{$R *.lfm}

{ TFormProcessManager }

class procedure TFormProcessManager.Execute(AOwner: TComponent; AProfile: TConnectionProfile);
var
  Frm: TFormProcessManager;
begin
  Frm := TFormProcessManager.Create(AOwner);
  try
    Frm.Profile := AProfile;
    Frm.ShowModal;
  finally
    Frm.Free;
  end;
end;

procedure TFormProcessManager.FormCreate(Sender: TObject);
begin
  FProcessList := TList.Create;
  FSelectedProcess := nil;
  synQuery.Highlighter := synSQLSyn;
  synQuery.ReadOnly := True;
end;

procedure TFormProcessManager.FormDestroy(Sender: TObject);
begin
  tmrRefresh.Enabled := False;
  ClearProcessList;
  FProcessList.Free;
end;

procedure TFormProcessManager.FormShow(Sender: TObject);
begin
  if Assigned(FProfile) then
  begin
    Caption := Format('Process List & Session Manager - %s (%s)', [FProfile.ConnectionName, FProfile.GetDisplayName]);
    ReloadProcesses;
  end;
end;

procedure TFormProcessManager.ClearProcessList;
var
  I: Integer;
begin
  for I := 0 to FProcessList.Count - 1 do
    TDBProcessInfo(FProcessList[I]).Free;
  FProcessList.Clear;
  FSelectedProcess := nil;
end;

procedure TFormProcessManager.ReloadProcesses;
var
  Err: string;
begin
  ClearProcessList;
  if not TDBProcessManagerService.FetchProcesses(FProfile, FProcessList, Err) then
  begin
    tmrRefresh.Enabled := False;
    chkAutoRefresh.Checked := False;
    MessageDlg('Perhatian', Err, mtWarning, [mbOK], 0);
    Exit;
  end;

  PopulateListView;
end;

procedure TFormProcessManager.PopulateListView;
var
  I: Integer;
  PInfo: TDBProcessInfo;
  Item: TListItem;
  FilterText: string;
  Matched: Boolean;
begin
  FilterText := LowerCase(Trim(edtSearch.Text));
  lvProcesses.Items.BeginUpdate;
  try
    lvProcesses.Items.Clear;
    for I := 0 to FProcessList.Count - 1 do
    begin
      PInfo := TDBProcessInfo(FProcessList[I]);

      // Filter search
      Matched := True;
      if FilterText <> '' then
      begin
        Matched := (Pos(FilterText, LowerCase(IntToStr(PInfo.PID))) > 0) or
                   (Pos(FilterText, LowerCase(PInfo.User)) > 0) or
                   (Pos(FilterText, LowerCase(PInfo.DatabaseName)) > 0) or
                   (Pos(FilterText, LowerCase(PInfo.State)) > 0) or
                   (Pos(FilterText, LowerCase(PInfo.QuerySQL)) > 0);
      end;

      if Matched then
      begin
        Item := lvProcesses.Items.Add;
        Item.Caption := IntToStr(PInfo.PID);
        Item.SubItems.Add(PInfo.User);
        Item.SubItems.Add(PInfo.DatabaseName);
        Item.SubItems.Add(PInfo.Host);
        Item.SubItems.Add(IntToStr(PInfo.TimeSec));
        Item.SubItems.Add(PInfo.State);
        Item.SubItems.Add(StringReplace(PInfo.QuerySQL, #13#10, ' ', [rfReplaceAll]));
        Item.Data := PInfo;
      end;
    end;
  finally
    lvProcesses.Items.EndUpdate;
  end;
end;

procedure TFormProcessManager.lvProcessesSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  if Selected and Assigned(Item) and Assigned(Item.Data) then
  begin
    FSelectedProcess := TDBProcessInfo(Item.Data);
    lblQueryTitle.Caption := Format('Query Lengkap (PID: %d | User: %s):', [FSelectedProcess.PID, FSelectedProcess.User]);
    synQuery.Lines.Text := FSelectedProcess.QuerySQL;
  end
  else
  begin
    FSelectedProcess := nil;
    lblQueryTitle.Caption := 'Query Lengkap:';
    synQuery.Clear;
  end;
end;

procedure TFormProcessManager.btnRefreshClick(Sender: TObject);
begin
  ReloadProcesses;
end;

procedure TFormProcessManager.btnCancelQueryClick(Sender: TObject);
var
  Err: string;
begin
  if not Assigned(FSelectedProcess) then
  begin
    MessageDlg('Pilih Sesi', 'Silakan pilih proses/query yang ingin dibatalkan.', mtInformation, [mbOK], 0);
    Exit;
  end;

  if MessageDlg('Konfirmasi', Format('Batalkan eksekusi query aktif pada PID %d?', [FSelectedProcess.PID]),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

  if TDBProcessManagerService.TerminateProcess(FProfile, FSelectedProcess.PID, True, Err) then
  begin
    MessageDlg('Sukses', 'Perintah pembatalan query berhasil dikirim.', mtInformation, [mbOK], 0);
    ReloadProcesses;
  end
  else
    MessageDlg('Gagal Membatalkan Query', Err, mtError, [mbOK], 0);
end;

procedure TFormProcessManager.btnKillSessionClick(Sender: TObject);
var
  Err: string;
begin
  if not Assigned(FSelectedProcess) then
  begin
    MessageDlg('Pilih Sesi', 'Silakan pilih sesi koneksi yang ingin dihentikan.', mtInformation, [mbOK], 0);
    Exit;
  end;

  if MessageDlg('Peringatan', Format('Hentikan dan putuskan total sesi koneksi PID %d? (Kill Connection)', [FSelectedProcess.PID]),
    mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;

  if TDBProcessManagerService.TerminateProcess(FProfile, FSelectedProcess.PID, False, Err) then
  begin
    MessageDlg('Sukses', 'Sesi koneksi berhasil dihentikan.', mtInformation, [mbOK], 0);
    ReloadProcesses;
  end
  else
    MessageDlg('Gagal Menghentikan Sesi', Err, mtError, [mbOK], 0);
end;

procedure TFormProcessManager.chkAutoRefreshChange(Sender: TObject);
begin
  tmrRefresh.Enabled := chkAutoRefresh.Checked;
end;

procedure TFormProcessManager.cboIntervalChange(Sender: TObject);
begin
  case cboInterval.ItemIndex of
    0: tmrRefresh.Interval := 1000;
    1: tmrRefresh.Interval := 3000;
    2: tmrRefresh.Interval := 5000;
    3: tmrRefresh.Interval := 10000;
  end;
end;

procedure TFormProcessManager.edtSearchChange(Sender: TObject);
begin
  PopulateListView;
end;

procedure TFormProcessManager.tmrRefreshTimer(Sender: TObject);
begin
  ReloadProcesses;
end;

end.
