unit uFormExportDialog;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Buttons, ComCtrls,
  uAppTypes, uDBTypes, uModelConnection, uExportWorkerThread, uExportService;

type
  { TFormExportDialog }
  TFormExportDialog = class(TForm)
    pnlBottom: TPanel;
    pnlContent: TPanel;
    btnStart: TBitBtn;
    btnCancel: TBitBtn;
    btnClose: TBitBtn;

    // Bagian Pemilihan Berkas & Format
    grpDestination: TGroupBox;
    lblFormat: TLabel;
    cboFormat: TComboBox;
    lblFilePath: TLabel;
    edtFilePath: TEdit;
    btnBrowse: TSpeedButton;

    // Bagian Pengaturan Format
    grpOptions: TGroupBox;
    chkIncludeHeaders: TCheckBox;
    lblDelimiter: TLabel;
    cboDelimiter: TComboBox;
    lblQuoteChar: TLabel;
    edtQuoteChar: TEdit;
    lblNullString: TLabel;
    edtNullString: TEdit;
    lblTableName: TLabel;
    edtTableName: TEdit;

    // Bagian Indikator Kemajuan
    grpProgress: TGroupBox;
    prgExport: TProgressBar;
    lblProgressStatus: TLabel;

    saveDialog: TSaveDialog;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure cboFormatChange(Sender: TObject);
    procedure btnBrowseClick(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
  private
    FProfile: TConnectionProfile;
    FSQL: string;
    FDatabaseTarget: string;
    FDefaultTableName: string;
    FWorker: TExportWorkerThread;
    FIsRunning: Boolean;

    procedure SetIsRunning(const AValue: Boolean);
    procedure UpdateControlStates;
    function BuildOptions: TExportOptions;
    function SelectedFormat: TExportFormat;

    // Handler Event Thread Ekspor
    procedure HandleExportProgress(Sender: TObject; const CurrentRow, TotalRows: Int64; const AMessage: string);
    procedure HandleExportSuccess(Sender: TObject; const TotalRows: Int64; const ElapsedMS: Int64);
    procedure HandleExportError(Sender: TObject; const AErrorMessage: string);
  public
    procedure SetupExport(AProfile: TConnectionProfile; const ASQL: string; 
      const ADefaultTableName: string = ''; const ADatabaseTarget: string = '');
    class function ExecuteDialog(AOwner: TComponent; AProfile: TConnectionProfile; 
      const ASQL: string; const ADefaultTableName: string = ''; const ADatabaseTarget: string = ''): Boolean;

    property Profile: TConnectionProfile read FProfile;
    property SQL: string read FSQL;
  end;

var
  FormExportDialog: TFormExportDialog;

implementation

{$R *.lfm}

{ TFormExportDialog }

class function TFormExportDialog.ExecuteDialog(AOwner: TComponent; AProfile: TConnectionProfile;
  const ASQL: string; const ADefaultTableName: string; const ADatabaseTarget: string): Boolean;
var
  Dlg: TFormExportDialog;
begin
  Dlg := TFormExportDialog.Create(AOwner);
  try
    Dlg.SetupExport(AProfile, ASQL, ADefaultTableName, ADatabaseTarget);
    Result := (Dlg.ShowModal = mrOk);
  finally
    Dlg.Free;
  end;
end;

procedure TFormExportDialog.FormCreate(Sender: TObject);
begin
  FProfile := TConnectionProfile.Create;
  FSQL := '';
  FDatabaseTarget := '';
  FDefaultTableName := 'exported_data';
  FWorker := nil;
  FIsRunning := False;

  cboFormat.Items.Clear;
  cboFormat.Items.Add('Comma Separated Values (*.csv)');
  cboFormat.Items.Add('JSON Document (*.json)');
  cboFormat.Items.Add('SQL Insert Statements (*.sql)');
  cboFormat.Items.Add('HTML Document (*.html)');
  cboFormat.Items.Add('Markdown Table (*.md)');
  cboFormat.Items.Add('XML Document (*.xml)');
  cboFormat.ItemIndex := 0;

  cboDelimiter.Items.Clear;
  cboDelimiter.Items.Add('Koma ( , )');
  cboDelimiter.Items.Add('Titik Koma ( ; )');
  cboDelimiter.Items.Add('Tab ( \t )');
  cboDelimiter.Items.Add('Garis Tegak ( | )');
  cboDelimiter.ItemIndex := 0;

  UpdateControlStates;
end;

procedure TFormExportDialog.FormDestroy(Sender: TObject);
begin
  if Assigned(FWorker) then
  begin
    FWorker.CancelExport;
    FWorker.WaitFor;
    FWorker := nil;
  end;

  FreeAndNil(FProfile);
end;

procedure TFormExportDialog.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FIsRunning then
  begin
    if MessageDlg('Konfirmasi', 'Proses ekspor sedang berjalan. Apakah Anda yakin ingin membatalkannya?',
      mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    begin
      btnCancelClick(Sender);
      CanClose := True;
    end
    else
      CanClose := False;
  end
  else
    CanClose := True;
end;

procedure TFormExportDialog.SetupExport(AProfile: TConnectionProfile; const ASQL: string;
  const ADefaultTableName: string; const ADatabaseTarget: string);
var
  BaseName: string;
begin
  if Assigned(AProfile) then
    FProfile.Assign(AProfile);

  FSQL := ASQL;
  FDatabaseTarget := ADatabaseTarget;

  if ADefaultTableName <> '' then
    FDefaultTableName := ADefaultTableName
  else
    FDefaultTableName := 'exported_data';

  edtTableName.Text := FDefaultTableName;
  BaseName := Format('%s_%s', [FDefaultTableName, FormatDateTime('YYYYMMDD_HHNNSS', Now)]);
  edtFilePath.Text := ExpandFileName(Format('%s.csv', [BaseName]));

  UpdateControlStates;
end;

function TFormExportDialog.SelectedFormat: TExportFormat;
begin
  case cboFormat.ItemIndex of
    0: Result := efCSV;
    1: Result := efJSON;
    2: Result := efSQL;
    3: Result := efHTML;
    4: Result := efMarkdown;
    5: Result := efXML;
    else Result := efCSV;
  end;
end;

procedure TFormExportDialog.UpdateControlStates;
var
  Fmt: TExportFormat;
begin
  Fmt := SelectedFormat;

  // Opsi CSV
  chkIncludeHeaders.Enabled := (Fmt in [efCSV, efHTML, efMarkdown]) and not FIsRunning;
  cboDelimiter.Enabled := (Fmt = efCSV) and not FIsRunning;
  lblDelimiter.Enabled := cboDelimiter.Enabled;
  edtQuoteChar.Enabled := (Fmt = efCSV) and not FIsRunning;
  lblQuoteChar.Enabled := edtQuoteChar.Enabled;

  // Opsi SQL Table
  edtTableName.Enabled := (Fmt = efSQL) and not FIsRunning;
  lblTableName.Enabled := edtTableName.Enabled;

  // Pengaturan Nilai NULL
  edtNullString.Enabled := (Fmt in [efCSV, efHTML, efMarkdown]) and not FIsRunning;
  lblNullString.Enabled := edtNullString.Enabled;

  // Kontrol Umum
  cboFormat.Enabled := not FIsRunning;
  edtFilePath.Enabled := not FIsRunning;
  btnBrowse.Enabled := not FIsRunning;
end;

procedure TFormExportDialog.SetIsRunning(const AValue: Boolean);
begin
  FIsRunning := AValue;
  btnStart.Enabled := not FIsRunning;
  btnCancel.Enabled := FIsRunning;
  btnClose.Enabled := not FIsRunning;

  if FIsRunning then
  begin
    prgExport.Style := pbstMarquee;
    lblProgressStatus.Caption := 'Memulai proses ekspor data...';
  end
  else
  begin
    prgExport.Style := pbstNormal;
    prgExport.Position := 0;
  end;

  UpdateControlStates;
end;

function TFormExportDialog.BuildOptions: TExportOptions;
var
  Fmt: TExportFormat;
begin
  Fmt := SelectedFormat;
  Result.FileName := Trim(edtFilePath.Text);
  Result.Format := Fmt;
  Result.IncludeHeaders := chkIncludeHeaders.Checked;
  Result.NullValueString := edtNullString.Text;
  Result.TableName := Trim(edtTableName.Text);
  Result.BatchSize := 100;

  // Penentuan Delimiter
  case cboDelimiter.ItemIndex of
    0: Result.Delimiter := ',';
    1: Result.Delimiter := ';';
    2: Result.Delimiter := #9;
    3: Result.Delimiter := '|';
    else Result.Delimiter := ',';
  end;

  if Length(edtQuoteChar.Text) > 0 then
    Result.QuoteChar := edtQuoteChar.Text[1]
  else
    Result.QuoteChar := '"';
end;

procedure TFormExportDialog.cboFormatChange(Sender: TObject);
var
  CurPath, NewExt: string;
begin
  NewExt := ExportService.GetDefaultExtension(SelectedFormat);
  CurPath := Trim(edtFilePath.Text);

  if CurPath <> '' then
    edtFilePath.Text := ChangeFileExt(CurPath, NewExt);

  UpdateControlStates;
end;

procedure TFormExportDialog.btnBrowseClick(Sender: TObject);
var
  Fmt: TExportFormat;
begin
  Fmt := SelectedFormat;
  saveDialog.DefaultExt := ExportService.GetDefaultExtension(Fmt);
  saveDialog.Filter := ExportService.GetFilterForFormat(Fmt);
  saveDialog.FileName := ExtractFileName(edtFilePath.Text);

  if saveDialog.Execute then
    edtFilePath.Text := saveDialog.FileName;
end;

procedure TFormExportDialog.btnStartClick(Sender: TObject);
var
  Opts: TExportOptions;
begin
  if Trim(edtFilePath.Text) = '' then
  begin
    MessageDlg('Peringatan', 'Silakan tentukan path berkas tujuan ekspor.', mtWarning, [mbOK], 0);
    edtFilePath.SetFocus;
    Exit;
  end;

  if Trim(FSQL) = '' then
  begin
    MessageDlg('Kesalahan', 'Tidak ada kueri data yang tersedia untuk diekspor.', mtError, [mbOK], 0);
    Exit;
  end;

  Opts := BuildOptions;
  SetIsRunning(True);

  FWorker := ExportService.StartExportAsync(
    FProfile,
    FSQL,
    Opts,
    FDatabaseTarget,
    @HandleExportProgress,
    @HandleExportSuccess,
    @HandleExportError
  );
end;

procedure TFormExportDialog.btnCancelClick(Sender: TObject);
begin
  if FIsRunning and Assigned(FWorker) then
  begin
    lblProgressStatus.Caption := 'Membatalkan proses ekspor...';
    ExportService.CancelExport(FWorker);
    FWorker := nil;
    SetIsRunning(False);
    lblProgressStatus.Caption := 'Proses ekspor dibatalkan.';
  end;
end;

procedure TFormExportDialog.btnCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TFormExportDialog.HandleExportProgress(Sender: TObject; const CurrentRow, TotalRows: Int64; const AMessage: string);
begin
  if TotalRows > 0 then
  begin
    prgExport.Style := pbstNormal;
    prgExport.Max := 100;
    prgExport.Position := (CurrentRow * 100) div TotalRows;
    lblProgressStatus.Caption := Format('%s (%d / %d baris)', [AMessage, CurrentRow, TotalRows]);
  end
  else
  begin
    prgExport.Style := pbstMarquee;
    lblProgressStatus.Caption := AMessage;
  end;
end;

procedure TFormExportDialog.HandleExportSuccess(Sender: TObject; const TotalRows: Int64; const ElapsedMS: Int64);
begin
  SetIsRunning(False);
  prgExport.Style := pbstNormal;
  prgExport.Position := 100;
  lblProgressStatus.Caption := Format('Selesai: %d baris berhasil diekspor (%d ms).', [TotalRows, ElapsedMS]);

  MessageDlg('Sukses', Format('Data berhasil diekspor ke:%s%s%s%sTotal: %d baris (%d ms)', [
    LineEnding, edtFilePath.Text, LineEnding, LineEnding, TotalRows, ElapsedMS
  ]), mtInformation, [mbOK], 0);

  ModalResult := mrOk;
end;

procedure TFormExportDialog.HandleExportError(Sender: TObject; const AErrorMessage: string);
begin
  SetIsRunning(False);
  lblProgressStatus.Caption := 'Gagal mengekspor data.';
  MessageDlg('Kesalahan Ekspor', Format('Terjadi kesalahan saat mengekspor data:%s%s', [
    LineEnding, AErrorMessage
  ]), mtError, [mbOK], 0);
end;

end.