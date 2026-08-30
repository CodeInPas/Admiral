unit uFormDataTransfer;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, CheckLst, Buttons, ComCtrls, Spin,
  uAppTypes, uDBTypes, uModelConnection, uDBDriverBase, uDBConnectionFactory,
  uModelSchemaObject, uDataTransferEngine;

type
  { TFormDataTransfer }
  TFormDataTransfer = class(TForm)
    pnlTop: TPanel;
    lblHeaderTitle: TLabel;
    lblHeaderSubtitle: TLabel;

    pnlMain: TPanel;
    gbSource: TGroupBox;
    lblSourceConn: TLabel;
    cboSourceConn: TComboBox;
    lblSourceTables: TLabel;
    clbSourceTables: TCheckListBox;
    btnSelectAllTables: TSpeedButton;
    btnUnselectAllTables: TSpeedButton;

    gbTarget: TGroupBox;
    lblTargetConn: TLabel;
    cboTargetConn: TComboBox;

    gbOptions: TGroupBox;
    chkCreateTable: TCheckBox;
    chkTruncateTable: TCheckBox;
    chkTransferData: TCheckBox;
    chkContinueOnError: TCheckBox;
    lblBatchSize: TLabel;
    seBatchSize: TSpinEdit;

    pnlProgress: TPanel;
    lblCurrentStatus: TLabel;
    prgTable: TProgressBar;
    memTransferLog: TMemo;

    pnlBottom: TPanel;
    btnStartTransfer: TBitBtn;
    btnCancelTransfer: TBitBtn;
    btnClose: TBitBtn;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure cboSourceConnChange(Sender: TObject);
    procedure btnSelectAllTablesClick(Sender: TObject);
    procedure btnUnselectAllTablesClick(Sender: TObject);
    procedure btnStartTransferClick(Sender: TObject);
    procedure btnCancelTransferClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
  private
    FConnections: TConnectionProfileList;
    FDefaultSource: TConnectionProfile;
    FWorker: TDataTransferWorkerThread;

    procedure PopulateConnectionCombos;
    procedure LoadSourceTables;
    procedure SetUIExecuting(const AExecuting: Boolean);
    procedure AppendLog(const AMessage: string);

    procedure HandleTransferProgress(
      Sender: TObject;
      const ACurrentTable: string;
      const ATableIndex, ATotalTables: Integer;
      const ARowsCopied, ATotalRows: Int64;
      const AStatusMessage: string
    );
    procedure HandleTransferComplete(
      Sender: TObject;
      const ASuccess: Boolean;
      const ATotalCopied: Int64;
      const AElapsedMS: Int64;
      const AErrorMsg: string
    );
  public
    class procedure Execute(
      AOwner: TComponent;
      AConnections: TConnectionProfileList;
      const ADefaultSource: TConnectionProfile = nil
    );
  end;

implementation

{$R *.lfm}

{ TFormDataTransfer }

class procedure TFormDataTransfer.Execute(
  AOwner: TComponent;
  AConnections: TConnectionProfileList;
  const ADefaultSource: TConnectionProfile
);
var
  Frm: TFormDataTransfer;
begin
  Frm := TFormDataTransfer.Create(AOwner);
  try
    Frm.FConnections := AConnections;
    Frm.FDefaultSource := ADefaultSource;
    Frm.ShowModal;
  finally
    Frm.Free;
  end;
end;

procedure TFormDataTransfer.FormCreate(Sender: TObject);
begin
  FWorker := nil;
  FConnections := nil;
  FDefaultSource := nil;
end;

procedure TFormDataTransfer.FormDestroy(Sender: TObject);
begin
  if Assigned(FWorker) then
  begin
    FWorker.CancelTransfer;
    FWorker.WaitFor;
    FreeAndNil(FWorker);
  end;
end;

procedure TFormDataTransfer.FormShow(Sender: TObject);
begin
  PopulateConnectionCombos;
  LoadSourceTables;
end;

procedure TFormDataTransfer.PopulateConnectionCombos;
var
  I: Integer;
  Prof: TConnectionProfile;
begin
  cboSourceConn.Items.Clear;
  cboTargetConn.Items.Clear;

  if not Assigned(FConnections) then Exit;

  for I := 0 to FConnections.Count - 1 do
  begin
    Prof := FConnections[I];
    cboSourceConn.Items.AddObject(Prof.ConnectionName + ' (' + Prof.GetDisplayName + ')', Prof);
    cboTargetConn.Items.AddObject(Prof.ConnectionName + ' (' + Prof.GetDisplayName + ')', Prof);
  end;

  if cboSourceConn.Items.Count > 0 then
  begin
    if Assigned(FDefaultSource) then
      cboSourceConn.ItemIndex := FConnections.IndexOf(FDefaultSource)
    else
      cboSourceConn.ItemIndex := 0;

    if cboSourceConn.Items.Count > 1 then
      cboTargetConn.ItemIndex := 1
    else
      cboTargetConn.ItemIndex := 0;
  end;
end;

procedure TFormDataTransfer.LoadSourceTables;
var
  Prof: TConnectionProfile;
  Driver: TDBDriverBase;
  Tables: TSchemaObjectList;
  I: Integer;
begin
  clbSourceTables.Items.Clear;
  if cboSourceConn.ItemIndex < 0 then Exit;

  Prof := TConnectionProfile(cboSourceConn.Items.Objects[cboSourceConn.ItemIndex]);
  Tables := TSchemaObjectList.Create;
  Driver := nil;
  try
    try
      Driver := TDBConnectionFactory.CreateDriver(Prof);
      Driver.ExtractTables('', '', Tables);

      for I := 0 to Tables.Count - 1 do
      begin
        clbSourceTables.Items.Add(Tables[I].Name);
        clbSourceTables.Checked[I] := True;
      end;
    except
      on E: Exception do
        AppendLog('Failed to read source table:' + E.Message);
    end;
  finally
    Tables.Free;
    if Assigned(Driver) then Driver.Free;
  end;
end;

procedure TFormDataTransfer.cboSourceConnChange(Sender: TObject);
begin
  LoadSourceTables;
end;

procedure TFormDataTransfer.btnSelectAllTablesClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to clbSourceTables.Items.Count - 1 do
    clbSourceTables.Checked[I] := True;
end;

procedure TFormDataTransfer.btnUnselectAllTablesClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to clbSourceTables.Items.Count - 1 do
    clbSourceTables.Checked[I] := False;
end;

procedure TFormDataTransfer.SetUIExecuting(const AExecuting: Boolean);
begin
  btnStartTransfer.Enabled := not AExecuting;
  btnCancelTransfer.Enabled := AExecuting;
  btnClose.Enabled := not AExecuting;
  cboSourceConn.Enabled := not AExecuting;
  cboTargetConn.Enabled := not AExecuting;
  clbSourceTables.Enabled := not AExecuting;
  gbOptions.Enabled := not AExecuting;
  prgTable.Visible := AExecuting;
end;

procedure TFormDataTransfer.AppendLog(const AMessage: string);
begin
  memTransferLog.Lines.Add(FormatDateTime('[hh:nn:ss] ', Now) + AMessage);
end;

procedure TFormDataTransfer.btnStartTransferClick(Sender: TObject);
var
  SrcProf, TgtProf: TConnectionProfile;
  SelectedTables: TStringList;
  Options: TDataTransferOptions;
  I: Integer;
begin
  if (cboSourceConn.ItemIndex < 0) or (cboTargetConn.ItemIndex < 0) then
  begin
    MessageDlg('Waring', 'Please select the Source and Target connection profiles..', mtWarning, [mbOK], 0);
    Exit;
  end;

  if cboSourceConn.ItemIndex = cboTargetConn.ItemIndex then
  begin
    MessageDlg('Waring', 'Source and target connections cannot be the same.', mtWarning, [mbOK], 0);
    Exit;
  end;

  SelectedTables := TStringList.Create;
  try
    for I := 0 to clbSourceTables.Items.Count - 1 do
      if clbSourceTables.Checked[I] then
        SelectedTables.Add(clbSourceTables.Items[I]);

    if SelectedTables.Count = 0 then
    begin
      MessageDlg('Waring', 'Please check at least one table to migrate..', mtWarning, [mbOK], 0);
      Exit;
    end;

    SrcProf := TConnectionProfile(cboSourceConn.Items.Objects[cboSourceConn.ItemIndex]);
    TgtProf := TConnectionProfile(cboTargetConn.Items.Objects[cboTargetConn.ItemIndex]);

    Options.CreateTableIfNotExists := chkCreateTable.Checked;
    Options.TruncateTargetTable := chkTruncateTable.Checked;
    Options.TransferData := chkTransferData.Checked;
    Options.BatchSize := seBatchSize.Value;
    Options.ContinueOnError := chkContinueOnError.Checked;

    memTransferLog.Clear;
    AppendLog(Format('Starting migration from [%s] to [%s] (%d tables)....', [
      SrcProf.ConnectionName, TgtProf.ConnectionName, SelectedTables.Count
    ]));

    SetUIExecuting(True);
    prgTable.Style := pbstMarquee;

    if Assigned(FWorker) then
    begin
      FWorker.WaitFor;
      FreeAndNil(FWorker);
    end;

    FWorker := TDataTransferWorkerThread.Create(
      SrcProf, TgtProf, SelectedTables, Options,
      @HandleTransferProgress, @HandleTransferComplete
    );
    FWorker.Start;

  finally
    SelectedTables.Free;
  end;
end;

procedure TFormDataTransfer.btnCancelTransferClick(Sender: TObject);
begin
  if Assigned(FWorker) then
  begin
    AppendLog('Canceling data transfer process...');
    FWorker.CancelTransfer;
  end;
end;

procedure TFormDataTransfer.HandleTransferProgress(
  Sender: TObject;
  const ACurrentTable: string;
  const ATableIndex, ATotalTables: Integer;
  const ARowsCopied, ATotalRows: Int64;
  const AStatusMessage: string
);
begin
  lblCurrentStatus.Caption := Format('[%d/%d] Tabel "%s": %s', [
    ATableIndex, ATotalTables, ACurrentTable, AStatusMessage
  ]);
end;

procedure TFormDataTransfer.HandleTransferComplete(
  Sender: TObject;
  const ASuccess: Boolean;
  const ATotalCopied: Int64;
  const AElapsedMS: Int64;
  const AErrorMsg: string
);
begin
  SetUIExecuting(False);

  if ASuccess then
  begin
    lblCurrentStatus.Caption := 'Data migration completed successfully.';
    AppendLog(Format('Transfer complete! Total %d rows copied in %d ms.', [
      ATotalCopied, AElapsedMS
    ]));
    MessageDlg('Data transfer successful.',
      Format('Migration completed successfully!%sTotal rows: %d%sDuration: %d ms', [
        LineEnding, ATotalCopied, LineEnding, AElapsedMS
      ]), mtInformation, [mbOK], 0);
  end
  else
  begin
    lblCurrentStatus.Caption := 'Migration Failed/Canceled.';
    AppendLog('Error: ' + AErrorMsg);
    MessageDlg('Migration Failed/Canceled.', AErrorMsg, mtError, [mbOK], 0);
  end;
end;

procedure TFormDataTransfer.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
