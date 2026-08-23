unit uFormAIDiagnostic;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Buttons, ComCtrls, Clipbrd,
  SynEdit, SynHighlighterSQL,
  uAppTypes, uDBTypes, uModelConnection, uAIService, uAIDiagnosticsEngine;

type
  { TFormAIDiagnostic }
  TFormAIDiagnostic = class(TForm)
    pnlTop: TPanel;
    lblTitle: TLabel;
    lblSubtitle: TLabel;
    lblElapsed: TLabel;
    prgLoading: TProgressBar;

    pgcMain: TPageControl;
    tabAnalysis: TTabSheet;
    tabFixedSQL: TTabSheet;
    tabOriginalError: TTabSheet;

    // Tab 1: Analisis & Penjelasan AI
    memAnalysis: TMemo;

    // Tab 2: SQL Perbaikan
    pnlFixedToolbar: TPanel;
    lblFixedInfo: TLabel;
    btnCopyFixedSQL: TSpeedButton;
    synFixedSQL: TSynEdit;
    synSQLSyn: TSynSQLSyn;

    // Tab 3: Error & Query Asli
    pnlOrigTop: TPanel;
    lblOrigErrorTitle: TLabel;
    memErrorMessage: TMemo;
    lblOrigSQLTitle: TLabel;
    synOriginalSQL: TSynEdit;

    // Footer Actions
    pnlBottom: TPanel;
    btnApplyToEditor: TBitBtn;
    btnReanalyze: TBitBtn;
    btnClose: TBitBtn;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);

    procedure btnApplyToEditorClick(Sender: TObject);
    procedure btnCopyFixedSQLClick(Sender: TObject);
    procedure btnReanalyzeClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
  private
    FProfile: TConnectionProfile;
    FFailedSQL: string;
    FErrorMessage: string;
    FDatabaseTarget: string;
    FFixedSQLResult: string;

    procedure StartDiagnostic;
    procedure HandleAISuccess(Sender: TObject; const AResponseText: string; const AElapsedMS: Int64);
    procedure HandleAIError(Sender: TObject; const AErrorMessage: string);
    procedure SetUIExecuting(const AExecuting: Boolean);
  public
    class function ExecuteDiagnostic(
      AOwner: TComponent;
      AProfile: TConnectionProfile;
      const AFailedSQL: string;
      const AErrorMessage: string;
      const ADBTarget: string;
      out AFixedSQL: string
    ): Boolean;
  end;

implementation

{$R *.lfm}

{ TFormAIDiagnostic }

class function TFormAIDiagnostic.ExecuteDiagnostic(
  AOwner: TComponent;
  AProfile: TConnectionProfile;
  const AFailedSQL: string;
  const AErrorMessage: string;
  const ADBTarget: string;
  out AFixedSQL: string
): Boolean;
var
  Frm: TFormAIDiagnostic;
begin
  Result := False;
  AFixedSQL := '';

  Frm := TFormAIDiagnostic.Create(AOwner);
  try
    Frm.FProfile := AProfile;
    Frm.FFailedSQL := AFailedSQL;
    Frm.FErrorMessage := AErrorMessage;
    Frm.FDatabaseTarget := ADBTarget;

    if Frm.ShowModal = mrOk then
    begin
      AFixedSQL := Frm.FFixedSQLResult;
      Result := (Trim(AFixedSQL) <> '');
    end;
  finally
    Frm.Free;
  end;
end;

procedure TFormAIDiagnostic.FormCreate(Sender: TObject);
begin
  FFixedSQLResult := '';
  synFixedSQL.Highlighter := synSQLSyn;
  synOriginalSQL.Highlighter := synSQLSyn;
end;

procedure TFormAIDiagnostic.FormDestroy(Sender: TObject);
begin
  // Dikelola otomatis oleh LCL
end;

procedure TFormAIDiagnostic.FormShow(Sender: TObject);
begin
  synOriginalSQL.Lines.Text := FFailedSQL;
  memErrorMessage.Lines.Text := FErrorMessage;
  memAnalysis.Clear;
  synFixedSQL.Clear;
  lblElapsed.Caption := '';

  StartDiagnostic;
end;

procedure TFormAIDiagnostic.SetUIExecuting(const AExecuting: Boolean);
begin
  prgLoading.Visible := AExecuting;
  btnApplyToEditor.Enabled := not AExecuting and (Trim(synFixedSQL.Lines.Text) <> '');
  btnReanalyze.Enabled := not AExecuting;
  btnCopyFixedSQL.Enabled := not AExecuting and (Trim(synFixedSQL.Lines.Text) <> '');

  if AExecuting then
  begin
    lblSubtitle.Caption := 'AI sedang mendiagnosis kesalahan dan menyusun koreksi query...';
    prgLoading.Style := pbstMarquee;
  end
  else
  begin
    lblSubtitle.Caption := 'Diagnosis selesai.';
    prgLoading.Style := pbstNormal;
  end;
end;

procedure TFormAIDiagnostic.StartDiagnostic;
var
  SysPrompt, UserPrompt: string;
  DriverType: TDBDriverType;
begin
  if Assigned(FProfile) then
    DriverType := FProfile.DriverType
  else
    DriverType := dtSQLite;

  SysPrompt := TAIDiagnosticsEngine.BuildSystemPrompt(DriverType);
  UserPrompt := TAIDiagnosticsEngine.BuildUserPrompt(DriverType, FFailedSQL, FErrorMessage, FDatabaseTarget);

  SetUIExecuting(True);
  pgcMain.ActivePage := tabAnalysis;
  memAnalysis.Lines.Text := 'Sedang berkomunikasi dengan layanan AI... Mohon tunggu.';

  AIService.ExecutePromptAsync(
    UserPrompt,
    SysPrompt,
    @HandleAISuccess,
    @HandleAIError
  );
end;

procedure TFormAIDiagnostic.HandleAISuccess(Sender: TObject; const AResponseText: string; const AElapsedMS: Int64);
var
  DiagResult: TAIDiagnosticResult;
begin
  SetUIExecuting(False);
  lblElapsed.Caption := Format('Waktu respon AI: %d ms', [AElapsedMS]);

  DiagResult := TAIDiagnosticsEngine.ParseDiagnosticResponse(AResponseText);
  memAnalysis.Lines.Text := DiagResult.Explanation;
  synFixedSQL.Lines.Text := DiagResult.FixedSQL;
  FFixedSQLResult := DiagResult.FixedSQL;

  if Trim(DiagResult.FixedSQL) <> '' then
  begin
    btnApplyToEditor.Enabled := True;
    btnCopyFixedSQL.Enabled := True;
    // Buka tab hasil perbaikan jika kode SQL berhasil diekstrak
    pgcMain.ActivePage := tabFixedSQL;
  end;
end;

procedure TFormAIDiagnostic.HandleAIError(Sender: TObject; const AErrorMessage: string);
begin
  SetUIExecuting(False);
  lblElapsed.Caption := 'Gagal mendapatkan respon AI.';
  memAnalysis.Lines.Text := 'Terjadi kesalahan saat memproses diagnostik AI:' + LineEnding + AErrorMessage;
  MessageDlg('Diagnostik AI Gagal', AErrorMessage, mtError, [mbOK], 0);
end;

procedure TFormAIDiagnostic.btnApplyToEditorClick(Sender: TObject);
begin
  FFixedSQLResult := synFixedSQL.Lines.Text;
  ModalResult := mrOk;
end;

procedure TFormAIDiagnostic.btnCopyFixedSQLClick(Sender: TObject);
begin
  Clipboard.AsText := synFixedSQL.Lines.Text;
  MessageDlg('Smart Auto-Fix', 'Kueri SQL hasil perbaikan berhasil disalin ke Clipboard.', mtInformation, [mbOK], 0);
end;

procedure TFormAIDiagnostic.btnReanalyzeClick(Sender: TObject);
begin
  StartDiagnostic;
end;

procedure TFormAIDiagnostic.btnCloseClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
