unit uFormAIExplainer;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Buttons, ComCtrls, Clipbrd,
  SynEdit, SynHighlighterSQL,
  uAppTypes, uDBTypes, uModelConnection, uAIService, uAIExplainerEngine;

type
  { TFormAIExplainer }
  TFormAIExplainer = class(TForm)
    pnlTop: TPanel;
    lblTitle: TLabel;
    lblSubtitle: TLabel;
    lblElapsed: TLabel;
    prgLoading: TProgressBar;

    pgcMain: TPageControl;
    tabExplanation: TTabSheet;
    tabAnnotatedSQL: TTabSheet;
    tabOriginalSQL: TTabSheet;

    // Tab 1: Penjelasan Logika & Dokumentasi
    memExplanation: TMemo;

    // Tab 2: SQL Beranotasi
    pnlAnnotatedToolbar: TPanel;
    lblAnnotatedInfo: TLabel;
    btnCopyAnnotatedSQL: TSpeedButton;
    synAnnotatedSQL: TSynEdit;

    // Tab 3: SQL Semula
    synOriginalSQL: TSynEdit;

    // Footer Actions
    pnlBottom: TPanel;
    btnApplyToEditor: TBitBtn;
    btnExportMarkdown: TBitBtn;
    btnCopyExplanation: TBitBtn;
    btnReanalyze: TBitBtn;
    btnClose: TBitBtn;

    synSQLSyn: TSynSQLSyn;
    saveDialog: TSaveDialog;

    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);

    procedure btnApplyToEditorClick(Sender: TObject);
    procedure btnCopyAnnotatedSQLClick(Sender: TObject);
    procedure btnCopyExplanationClick(Sender: TObject);
    procedure btnExportMarkdownClick(Sender: TObject);
    procedure btnReanalyzeClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
  private
    FProfile: TConnectionProfile;
    FOriginalSQL: string;
    FDatabaseTarget: string;
    FAnnotatedSQLResult: string;

    procedure StartExplanation;
    procedure HandleAISuccess(Sender: TObject; const AResponseText: string; const AElapsedMS: Int64);
    procedure HandleAIError(Sender: TObject; const AErrorMessage: string);
    procedure SetUIExecuting(const AExecuting: Boolean);
  public
    class function ExecuteExplainer(
      AOwner: TComponent;
      AProfile: TConnectionProfile;
      const AOriginalSQL: string;
      const ADBTarget: string;
      out AAnnotatedSQL: string
    ): Boolean;
  end;

implementation

{$R *.lfm}

{ TFormAIExplainer }

class function TFormAIExplainer.ExecuteExplainer(
  AOwner: TComponent;
  AProfile: TConnectionProfile;
  const AOriginalSQL: string;
  const ADBTarget: string;
  out AAnnotatedSQL: string
): Boolean;
var
  Frm: TFormAIExplainer;
begin
  Result := False;
  AAnnotatedSQL := '';

  Frm := TFormAIExplainer.Create(AOwner);
  try
    Frm.FProfile := AProfile;
    Frm.FOriginalSQL := AOriginalSQL;
    Frm.FDatabaseTarget := ADBTarget;

    if Frm.ShowModal = mrOk then
    begin
      AAnnotatedSQL := Frm.FAnnotatedSQLResult;
      Result := (Trim(AAnnotatedSQL) <> '');
    end;
  finally
    Frm.Free;
  end;
end;

procedure TFormAIExplainer.FormCreate(Sender: TObject);
begin
  FAnnotatedSQLResult := '';
  synAnnotatedSQL.Highlighter := synSQLSyn;
  synOriginalSQL.Highlighter := synSQLSyn;
end;

procedure TFormAIExplainer.FormShow(Sender: TObject);
begin
  synOriginalSQL.Lines.Text := FOriginalSQL;
  memExplanation.Clear;
  synAnnotatedSQL.Clear;
  lblElapsed.Caption := '';

  StartExplanation;
end;

procedure TFormAIExplainer.SetUIExecuting(const AExecuting: Boolean);
begin
  prgLoading.Visible := AExecuting;
  btnApplyToEditor.Enabled := not AExecuting and (Trim(synAnnotatedSQL.Lines.Text) <> '');
  btnReanalyze.Enabled := not AExecuting;
  btnCopyAnnotatedSQL.Enabled := not AExecuting and (Trim(synAnnotatedSQL.Lines.Text) <> '');
  btnCopyExplanation.Enabled := not AExecuting and (Trim(memExplanation.Lines.Text) <> '');
  btnExportMarkdown.Enabled := not AExecuting and (Trim(memExplanation.Lines.Text) <> '');

  if AExecuting then
  begin
    lblSubtitle.Caption := 'AI sedang membedah alur logika kueri dan menyusun dokumentasi...';
    prgLoading.Style := pbstMarquee;
  end
  else
  begin
    lblSubtitle.Caption := 'Dokumentasi berhasil dibuat.';
    prgLoading.Style := pbstNormal;
  end;
end;

procedure TFormAIExplainer.StartExplanation;
var
  SysPrompt, UserPrompt: string;
  DriverType: TDBDriverType;
begin
  if Assigned(FProfile) then
    DriverType := FProfile.DriverType
  else
    DriverType := dtSQLite;

  SysPrompt := TAIExplainerEngine.BuildSystemPrompt(DriverType);
  UserPrompt := TAIExplainerEngine.BuildUserPrompt(DriverType, FOriginalSQL, FDatabaseTarget);

  SetUIExecuting(True);
  pgcMain.ActivePage := tabExplanation;
  memExplanation.Lines.Text := 'Sedang menganalisis dan mendokumentasikan kueri SQL... Mohon tunggu.';

  AIService.ExecutePromptAsync(
    UserPrompt,
    SysPrompt,
    @HandleAISuccess,
    @HandleAIError
  );
end;

procedure TFormAIExplainer.HandleAISuccess(Sender: TObject; const AResponseText: string; const AElapsedMS: Int64);
var
  ExplResult: TAIExplanationResult;
begin
  SetUIExecuting(False);
  lblElapsed.Caption := Format('Waktu respon AI: %d ms', [AElapsedMS]);

  ExplResult := TAIExplainerEngine.ParseExplainerResponse(AResponseText);
  memExplanation.Lines.Text := ExplResult.LogicExplanation;
  synAnnotatedSQL.Lines.Text := ExplResult.AnnotatedSQL;
  FAnnotatedSQLResult := ExplResult.AnnotatedSQL;

  if Trim(ExplResult.AnnotatedSQL) <> '' then
  begin
    btnApplyToEditor.Enabled := True;
    btnCopyAnnotatedSQL.Enabled := True;
  end;
end;

procedure TFormAIExplainer.HandleAIError(Sender: TObject; const AErrorMessage: string);
begin
  SetUIExecuting(False);
  lblElapsed.Caption := 'Gagal membuat dokumentasi AI.';
  memExplanation.Lines.Text := 'Terjadi kesalahan saat memproses penjelasan kueri:' + LineEnding + AErrorMessage;
  MessageDlg('AI Explainer Error', AErrorMessage, mtError, [mbOK], 0);
end;

procedure TFormAIExplainer.btnApplyToEditorClick(Sender: TObject);
begin
  FAnnotatedSQLResult := synAnnotatedSQL.Lines.Text;
  ModalResult := mrOk;
end;

procedure TFormAIExplainer.btnCopyAnnotatedSQLClick(Sender: TObject);
begin
  Clipboard.AsText := synAnnotatedSQL.Lines.Text;
  MessageDlg('SQL Explainer', 'Kueri SQL beranotasi berhasil disalin ke Clipboard.', mtInformation, [mbOK], 0);
end;

procedure TFormAIExplainer.btnCopyExplanationClick(Sender: TObject);
begin
  Clipboard.AsText := memExplanation.Lines.Text;
  MessageDlg('SQL Explainer', 'Teks penjelasan logika berhasil disalin ke Clipboard.', mtInformation, [mbOK], 0);
end;

procedure TFormAIExplainer.btnExportMarkdownClick(Sender: TObject);
var
  SL: TStringList;
begin
  saveDialog.DefaultExt := '.md';
  saveDialog.Filter := 'Markdown Document (*.md)|*.md|Text Document (*.txt)|*.txt|All Files (*.*)|*.*';
  saveDialog.FileName := Format('sql_documentation_%s.md', [FormatDateTime('YYYYMMDD_HHNNSS', Now)]);

  if saveDialog.Execute then
  begin
    SL := TStringList.Create;
    try
      SL.Add('# SQL Query Logic & Documentation');
      SL.Add('*Dibuat otomatis oleh SiAdmin AI Engine pada: ' + FormatDateTime('YYYY-MM-DD HH:NN:SS', Now) + '*');
      SL.Add('');
      SL.Add('## 1. Analisis Alur Logika');
      SL.Add(memExplanation.Lines.Text);
      SL.Add('');
      SL.Add('## 2. Kueri SQL Asli');
      SL.Add('```sql');
      SL.Add(FOriginalSQL);
      SL.Add('```');
      SL.Add('');
      if Trim(synAnnotatedSQL.Lines.Text) <> '' then
      begin
        SL.Add('## 3. Kueri SQL Beranotasi (Documented SQL)');
        SL.Add('```sql');
        SL.Add(synAnnotatedSQL.Lines.Text);
        SL.Add('```');
      end;

      SL.SaveToFile(saveDialog.FileName);
      MessageDlg('Dokumentasi Tersimpan', Format('Dokumentasi berhasil diekspor ke:%s%s', [LineEnding, saveDialog.FileName]), mtInformation, [mbOK], 0);
    finally
      SL.Free;
    end;
  end;
end;

procedure TFormAIExplainer.btnReanalyzeClick(Sender: TObject);
begin
  StartExplanation;
end;

procedure TFormAIExplainer.btnCloseClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
