unit uFormBackupRestore;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Buttons, CheckLst, ComCtrls, Spin,
  uAppTypes, uDBTypes, uModelConnection, uDBDriverBase, uDBConnectionFactory,
  uModelSchemaObject, uBackupRestoreEngine;

type
  { TFormBackupRestore }
  TFormBackupRestore = class(TForm)
    pnlTop: TPanel;
    lblTitle: TLabel;
    lblSubtitle: TLabel;

    pgcMain: TPageControl;
    tabBackup: TTabSheet;
    tabRestore: TTabSheet;

    // Kontrol Tab Backup
    gbBackupTarget: TGroupBox;
    lblBackupConn: TLabel;
    cboBackupConn: TComboBox;
    lblBackupTables: TLabel;
    clbBackupTables: TCheckListBox;
    btnSelectAll: TSpeedButton;
    btnUnselectAll: TSpeedButton;

    gbBackupOptions: TGroupBox;
    chkIncludeStructure: TCheckBox;
    chkIncludeData: TCheckBox;
    chkAddDropTable: TCheckBox;
    lblBatchSize: TLabel;
    seBatchSize: TSpinEdit;
    lblBackupPath: TLabel;
    edtBackupPath: TEdit;
    btnBrowseBackup: TSpeedButton;

    // Kontrol Tab Restore
    gbRestoreTarget: TGroupBox;
    lblRestoreConn: TLabel;
    cboRestoreConn: TComboBox;
    lblRestoreFile: TLabel;
    edtRestoreFile: TEdit;
    btnBrowseRestore: TSpeedButton;

    gbRestoreOptions: TGroupBox;
    chkRestoreTx: TCheckBox;
    chkRestoreContinueError: TCheckBox;

    // Panel Progress
    pnlProgress: TPanel;
    lblCurrentTask: TLabel;
    prgStatus: TProgressBar;
    memLog: TMemo;

    // Footer
    pnlBottom: TPanel;
    btnStart: TBitBtn;
    btnCancel: TBitBtn;
    btnClose: TBitBtn;

    saveDlg: TSaveDialog;
    openDlg: TOpenDialog;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure cboBackupConnChange(Sender: TObject);
    procedure btnSelectAllClick(Sender: TObject);
    procedure btnUnselectAllClick(Sender: TObject);
    procedure btnBrowseBackupClick(Sender: TObject);
    procedure btnBrowseRestoreClick(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure pgcMainChange(Sender: TObject);
  private
    FConnections: TConnectionProfileList;
    FDefaultProfile: TConnectionProfile;
    FWorker: TBackupRestoreWorkerThread;

    procedure PopulateConnectionCombos;
    procedure LoadBackupTables;
    procedure SetUIExecuting(const AExecuting: Boolean);
    procedure AppendLog(const AMessage: string);

    procedure HandleEngineProgress(
      Sender: TObject;
      const ACurrentTask: string;
      const AItemIndex, ATotalItems: Integer;
      const AProgressPercentage: Integer;
      const ADetailMessage: string
    );
    procedure HandleEngineComplete(
      Sender: TObject;
      const ASuccess: Boolean;
      const ATotalLinesOrRows: Int64;
      const AElapsedMS: Int64;
      const AErrorMessage: string
    );
  public
    class procedure Execute(
      AOwner: TComponent;
      AConnections: TConnectionProfileList;
      const ADefaultProfile: TConnectionProfile = nil
    );
  end;

implementation

{$R *.lfm}

{ TFormBackupRestore }

class procedure TFormBackupRestore.Execute(
  AOwner: TComponent;
  AConnections: TConnectionProfileList;
  const ADefaultProfile: TConnectionProfile
);
var
  Frm: TFormBackupRestore;
begin
  Frm := TFormBackupRestore.Create(AOwner);
  try
    Frm.FConnections := AConnections;
    Frm.FDefaultProfile := ADefaultProfile;
    Frm.ShowModal;
  finally
    Frm.Free;
  end;
end;

procedure TFormBackupRestore.FormCreate(Sender: TObject);
begin
  FWorker := nil;
  FConnections := nil;
  FDefaultProfile := nil;
end;

procedure TFormBackupRestore.FormDestroy(Sender: TObject);
begin
  if Assigned(FWorker) then
  begin
    FWorker.CancelOperation;
    FWorker.WaitFor;
    FreeAndNil(FWorker);
  end;
end;

procedure TFormBackupRestore.FormShow(Sender: TObject);
begin
  PopulateConnectionCombos;
  LoadBackupTables;
  edtBackupPath.Text := ExtractFilePath(ParamStr(0)) + Format('backup_dump_%s.sql', [FormatDateTime('yyyymmdd_hhnnss', Now)]);
end;

procedure TFormBackupRestore.PopulateConnectionCombos;
var
  I: Integer;
  Prof: TConnectionProfile;
begin
  cboBackupConn.Items.Clear;
  cboRestoreConn.Items.Clear;

  if not Assigned(FConnections) then Exit;

  for I := 0 to FConnections.Count - 1 do
  begin
    Prof := FConnections[I];
    cboBackupConn.Items.AddObject(Prof.ConnectionName + ' (' + Prof.GetDisplayName + ')', Prof);
    cboRestoreConn.Items.AddObject(Prof.ConnectionName + ' (' + Prof.GetDisplayName + ')', Prof);
  end;

  if cboBackupConn.Items.Count > 0 then
  begin
    if Assigned(FDefaultProfile) then
    begin
      cboBackupConn.ItemIndex := FConnections.IndexOf(FDefaultProfile);
      cboRestoreConn.ItemIndex := cboBackupConn.ItemIndex;
    end
    else
    begin
      cboBackupConn.ItemIndex := 0;
      cboRestoreConn.ItemIndex := 0;
    end;
  end;
end;

procedure TFormBackupRestore.LoadBackupTables;
var
  Prof: TConnectionProfile;
  Driver: TDBDriverBase;
  Tables: TSchemaObjectList;
  I: Integer;
begin
  clbBackupTables.Items.Clear;
  if cboBackupConn.ItemIndex < 0 then Exit;

  Prof := TConnectionProfile(cboBackupConn.Items.Objects[cboBackupConn.ItemIndex]);
  Tables := TSchemaObjectList.Create;
  Driver := nil;
  try
    try
      Driver := TDBConnectionFactory.CreateDriver(Prof);
      Driver.ExtractTables(Prof.DatabaseName, '', Tables);

      for I := 0 to Tables.Count - 1 do
      begin
        clbBackupTables.Items.Add(Tables[I].Name);
        clbBackupTables.Checked[I] := True;
      end;
    except
      on E: Exception do
        AppendLog('Gagal membaca tabel: ' + E.Message);
    end;
  finally
    Tables.Free;
    if Assigned(Driver) then Driver.Free;
  end;
end;

procedure TFormBackupRestore.cboBackupConnChange(Sender: TObject);
begin
  LoadBackupTables;
end;

procedure TFormBackupRestore.btnSelectAllClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to clbBackupTables.Items.Count - 1 do
    clbBackupTables.Checked[I] := True;
end;

procedure TFormBackupRestore.btnUnselectAllClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to clbBackupTables.Items.Count - 1 do
    clbBackupTables.Checked[I] := False;
end;

procedure TFormBackupRestore.btnBrowseBackupClick(Sender: TObject);
begin
  saveDlg.DefaultExt := '.sql';
  saveDlg.Filter := 'SQL Dump File (*.sql)|*.sql|All Files (*.*)|*.*';
  saveDlg.FileName := ExtractFileName(edtBackupPath.Text);
  if saveDlg.Execute then
    edtBackupPath.Text := saveDlg.FileName;
end;

procedure TFormBackupRestore.btnBrowseRestoreClick(Sender: TObject);
begin
  openDlg.DefaultExt := '.sql';
  openDlg.Filter := 'SQL Dump File (*.sql)|*.sql|All Files (*.*)|*.*';
  if openDlg.Execute then
    edtRestoreFile.Text := openDlg.FileName;
end;

procedure TFormBackupRestore.pgcMainChange(Sender: TObject);
begin
  if pgcMain.ActivePage = tabBackup then
    btnStart.Caption := '⚡ Mulai Backup (Dump)'
  else
    btnStart.Caption := '⚡ Mulai Restore (Pulihkan)';
end;

procedure TFormBackupRestore.SetUIExecuting(const AExecuting: Boolean);
begin
  btnStart.Enabled := not AExecuting;
  btnCancel.Enabled := AExecuting;
  btnClose.Enabled := not AExecuting;
  pgcMain.Enabled := not AExecuting;
  prgStatus.Visible := AExecuting;
end;

procedure TFormBackupRestore.AppendLog(const AMessage: string);
begin
  memLog.Lines.Add(FormatDateTime('[hh:nn:ss] ', Now) + AMessage);
end;

procedure TFormBackupRestore.btnStartClick(Sender: TObject);
var
  Prof: TConnectionProfile;
  SelectedTables: TStringList;
  BackupOpts: TBackupOptions;
  RestoreOpts: TRestoreOptions;
  I: Integer;
begin
  memLog.Clear;

  if pgcMain.ActivePage = tabBackup then
  begin
    // Validasi Tab Backup
    if cboBackupConn.ItemIndex < 0 then
    begin
      MessageDlg('Peringatan', 'Pilih koneksi database target backup.', mtWarning, [mbOK], 0);
      Exit;
    end;

    if Trim(edtBackupPath.Text) = '' then
    begin
      MessageDlg('Peringatan', 'Tentukan lokasi berkas keluaran SQL dump.', mtWarning, [mbOK], 0);
      Exit;
    end;

    SelectedTables := TStringList.Create;
    try
      for I := 0 to clbBackupTables.Items.Count - 1 do
        if clbBackupTables.Checked[I] then
          SelectedTables.Add(clbBackupTables.Items[I]);

      if SelectedTables.Count = 0 then
      begin
        MessageDlg('Peringatan', 'Centang minimal satu tabel yang ingin dicadangkan.', mtWarning, [mbOK], 0);
        Exit;
      end;

      Prof := TConnectionProfile(cboBackupConn.Items.Objects[cboBackupConn.ItemIndex]);

      BackupOpts.IncludeStructure := chkIncludeStructure.Checked;
      BackupOpts.IncludeData := chkIncludeData.Checked;
      BackupOpts.AddDropTable := chkAddDropTable.Checked;
      BackupOpts.InsertBatchSize := seBatchSize.Value;
      BackupOpts.FilePath := Trim(edtBackupPath.Text);

      AppendLog(Format('Memulai backup database [%s] (%d tabel)...', [Prof.ConnectionName, SelectedTables.Count]));
      SetUIExecuting(True);

      if Assigned(FWorker) then
      begin
        FWorker.WaitFor;
        FreeAndNil(FWorker);
      end;

      FWorker := TBackupRestoreWorkerThread.CreateBackup(
        Prof, Prof.DatabaseName, SelectedTables, BackupOpts,
        @HandleEngineProgress, @HandleEngineComplete
      );
      FWorker.Start;
    finally
      SelectedTables.Free;
    end;
  end
  else
  begin
    // Validasi Tab Restore
    if cboRestoreConn.ItemIndex < 0 then
    begin
      MessageDlg('Peringatan', 'Pilih koneksi database tujuan pemulihan (restore).', mtWarning, [mbOK], 0);
      Exit;
    end;

    if (Trim(edtRestoreFile.Text) = '') or not FileExists(Trim(edtRestoreFile.Text)) then
    begin
      MessageDlg('Peringatan', 'Pilih berkas SQL dump yang valid.', mtWarning, [mbOK], 0);
      Exit;
    end;

    Prof := TConnectionProfile(cboRestoreConn.Items.Objects[cboRestoreConn.ItemIndex]);

    RestoreOpts.ContinueOnError := chkRestoreContinueError.Checked;
    RestoreOpts.UseTransaction := chkRestoreTx.Checked;
    RestoreOpts.FilePath := Trim(edtRestoreFile.Text);

    AppendLog(Format('Memulai proses pemulihan ke database [%s]...', [Prof.ConnectionName]));
    SetUIExecuting(True);

    if Assigned(FWorker) then
    begin
      FWorker.WaitFor;
      FreeAndNil(FWorker);
    end;

    FWorker := TBackupRestoreWorkerThread.CreateRestore(
      Prof, Prof.DatabaseName, RestoreOpts,
      @HandleEngineProgress, @HandleEngineComplete
    );
    FWorker.Start;
  end;
end;

procedure TFormBackupRestore.btnCancelClick(Sender: TObject);
begin
  if Assigned(FWorker) then
  begin
    AppendLog('Membatalkan proses backup / restore...');
    FWorker.CancelOperation;
  end;
end;

procedure TFormBackupRestore.HandleEngineProgress(
  Sender: TObject;
  const ACurrentTask: string;
  const AItemIndex, ATotalItems: Integer;
  const AProgressPercentage: Integer;
  const ADetailMessage: string
);
begin
  lblCurrentTask.Caption := ACurrentTask;
  prgStatus.Position := AProgressPercentage;
  AppendLog(ADetailMessage);
end;

procedure TFormBackupRestore.HandleEngineComplete(
  Sender: TObject;
  const ASuccess: Boolean;
  const ATotalLinesOrRows: Int64;
  const AElapsedMS: Int64;
  const AErrorMessage: string
);
begin
  SetUIExecuting(False);

  if ASuccess then
  begin
    lblCurrentTask.Caption := 'Operasi Selesai Sukses.';
    prgStatus.Position := 100;
    AppendLog(Format('Selesai! Total %d baris/statement diproses dalam %d ms.', [ATotalLinesOrRows, AElapsedMS]));
    MessageDlg('Operasi Sukses',
      Format('Proses telah selesai dengan sukses!%sTotal: %d item diproses%sDurasi: %d ms', [
        LineEnding, ATotalLinesOrRows, LineEnding, AElapsedMS
      ]), mtInformation, [mbOK], 0);
  end
  else
  begin
    lblCurrentTask.Caption := 'Operasi Gagal / Dibatalkan.';
    AppendLog('Kesalahan: ' + AErrorMessage);
    MessageDlg('Operasi Gagal', AErrorMessage, mtError, [mbOK], 0);
  end;
end;

procedure TFormBackupRestore.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
