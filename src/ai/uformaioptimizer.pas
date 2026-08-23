unit uFormAIOptimizer;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Buttons, ComCtrls, Clipbrd,
  SynEdit, SynHighlighterSQL,
  ZConnection,
  uAppTypes, uDBTypes, uModelConnection, uDBDriverBase, uDBConnectionFactory,
  uAIService, uAIOptimizerEngine;

type
  { TFormAIOptimizer }
  TFormAIOptimizer = class(TForm)
    pnlTop: TPanel;
    lblTitle: TLabel;
    lblSubtitle: TLabel;
    lblElapsed: TLabel;
    prgLoading: TProgressBar;

    pgcMain: TPageControl;
    tabOptimizedSQL: TTabSheet;
    tabIndexAdvisor: TTabSheet;
    tabAnalysis: TTabSheet;
    tabOriginalPlan: TTabSheet;

    // Tab 1: Kueri Hasil Rewrite
    pnlOptToolbar: TPanel;
    lblOptInfo: TLabel;
    btnCopyOptSQL: TSpeedButton;
    synOptimizedSQL: TSynEdit;

    // Tab 2: Rekomendasi Indeks DDL
    pnlIdxToolbar: TPanel;
    lblIdxInfo: TLabel;
    btnCopyIndexDDL: TSpeedButton;
    btnExecuteIndexDDL: TBitBtn;
    synIndexDDL: TSynEdit;

    // Tab 3: Analisis & Penjelasan
    memAnalysis: TMemo;

    // Tab 4: SQL Asli & Explain Plan
    pnlPlanTop: TPanel;
    lblOrigSQLTitle: TLabel;
    synOriginalSQL: TSynEdit;
    lblPlanTitle: TLabel;
    memExplainPlan: TMemo;

    // Footer Actions
    pnlBottom: TPanel;
    btnApplyToEditor: TBitBtn;
    btnReanalyze: TBitBtn;
    btnClose: TBitBtn;

    synSQLSyn: TSynSQLSyn;

    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);

    procedure btnApplyToEditorClick(Sender: TObject);
    procedure btnCopyOptSQLClick(Sender: TObject);
    procedure btnCopyIndexDDLClick(Sender: TObject);
    procedure btnExecuteIndexDDLClick(Sender: TObject);
    procedure btnReanalyzeClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
  private
    FProfile: TConnectionProfile;
    FOriginalSQL: string;
    FDatabaseTarget: string;
    FExplainPlanText: string;
    FOptimizedSQLResult: string;

    procedure RunExplainPlan;
    procedure StartOptimization;
    procedure HandleAISuccess(Sender: TObject; const AResponseText: string; const AElapsedMS: Int64);
    procedure HandleAIError(Sender: TObject; const AErrorMessage: string);
    procedure SetUIExecuting(const AExecuting: Boolean);
  public
    class function ExecuteOptimizer(
      AOwner: TComponent;
      AProfile: TConnectionProfile;
      const AOriginalSQL: string;
      const ADBTarget: string;
      out AOptimizedSQL: string
    ): Boolean;
  end;

implementation

{$R *.lfm}

{ TFormAIOptimizer }

class function TFormAIOptimizer.ExecuteOptimizer(
  AOwner: TComponent;
  AProfile: TConnectionProfile;
  const AOriginalSQL: string;
  const ADBTarget: string;
  out AOptimizedSQL: string
): Boolean;
var
  Frm: TFormAIOptimizer;
begin
  Result := False;
  AOptimizedSQL := '';

  Frm := TFormAIOptimizer.Create(AOwner);
  try
    Frm.FProfile := AProfile;
    Frm.FOriginalSQL := AOriginalSQL;
    Frm.FDatabaseTarget := ADBTarget;

    if Frm.ShowModal = mrOk then
    begin
      AOptimizedSQL := Frm.FOptimizedSQLResult;
      Result := (Trim(AOptimizedSQL) <> '');
    end;
  finally
    Frm.Free;
  end;
end;

procedure TFormAIOptimizer.FormCreate(Sender: TObject);
begin
  FOptimizedSQLResult := '';
  synOptimizedSQL.Highlighter := synSQLSyn;
  synIndexDDL.Highlighter := synSQLSyn;
  synOriginalSQL.Highlighter := synSQLSyn;
end;

procedure TFormAIOptimizer.FormShow(Sender: TObject);
begin
  synOriginalSQL.Lines.Text := FOriginalSQL;
  memAnalysis.Clear;
  synOptimizedSQL.Clear;
  synIndexDDL.Clear;
  lblElapsed.Caption := '';

  RunExplainPlan;
  StartOptimization;
end;

procedure TFormAIOptimizer.RunExplainPlan;
var
  Driver: TDBDriverBase;
  Plan: TDBExecutionPlanArray;
begin
  FExplainPlanText := '';
  Driver := nil;
  try
    try
      Driver := TDBConnectionFactory.CreateDriver(FProfile);
      if Driver.GetExplainPlan(FOriginalSQL, Plan) then
        FExplainPlanText := TAIOptimizerEngine.FormatExplainPlan(Plan)
      else
        FExplainPlanText := '(DBMS tidak mengembalikan detail Execution Plan)';
    except
      on E: Exception do
        FExplainPlanText := 'Gagal mengambil Execution Plan: ' + E.Message;
    end;
  finally
    if Assigned(Driver) then
      Driver.Free;
  end;

  memExplainPlan.Lines.Text := FExplainPlanText;
end;

procedure TFormAIOptimizer.SetUIExecuting(const AExecuting: Boolean);
begin
  prgLoading.Visible := AExecuting;
  btnApplyToEditor.Enabled := not AExecuting and (Trim(synOptimizedSQL.Lines.Text) <> '');
  btnReanalyze.Enabled := not AExecuting;
  btnCopyOptSQL.Enabled := not AExecuting and (Trim(synOptimizedSQL.Lines.Text) <> '');
  btnExecuteIndexDDL.Enabled := not AExecuting and (Trim(synIndexDDL.Lines.Text) <> '');

  if AExecuting then
  begin
    lblSubtitle.Caption := 'AI sedang menganalisis query bottleneck, execution plan, dan menyusun optimasi...';
    prgLoading.Style := pbstMarquee;
  end
  else
  begin
    lblSubtitle.Caption := 'Optimasi selesai.';
    prgLoading.Style := pbstNormal;
  end;
end;

procedure TFormAIOptimizer.StartOptimization;
var
  SysPrompt, UserPrompt: string;
  DriverType: TDBDriverType;
begin
  if Assigned(FProfile) then
    DriverType := FProfile.DriverType
  else
    DriverType := dtSQLite;

  SysPrompt := TAIOptimizerEngine.BuildSystemPrompt(DriverType);
  UserPrompt := TAIOptimizerEngine.BuildUserPrompt(DriverType, FOriginalSQL, FExplainPlanText, FDatabaseTarget);

  SetUIExecuting(True);
  pgcMain.ActivePage := tabOptimizedSQL;
  memAnalysis.Lines.Text := 'Sedang menganalisis performa query... Mohon tunggu.';

  AIService.ExecutePromptAsync(
    UserPrompt,
    SysPrompt,
    @HandleAISuccess,
    @HandleAIError
  );
end;

procedure TFormAIOptimizer.HandleAISuccess(Sender: TObject; const AResponseText: string; const AElapsedMS: Int64);
var
  OptResult: TAIOptimizerResult;
begin
  SetUIExecuting(False);
  lblElapsed.Caption := Format('Waktu respon AI: %d ms', [AElapsedMS]);

  OptResult := TAIOptimizerEngine.ParseOptimizerResponse(AResponseText);
  memAnalysis.Lines.Text := OptResult.AnalysisText;
  synOptimizedSQL.Lines.Text := OptResult.OptimizedSQL;
  synIndexDDL.Lines.Text := OptResult.IndexDDL;
  FOptimizedSQLResult := OptResult.OptimizedSQL;

  if Trim(OptResult.OptimizedSQL) <> '' then
  begin
    btnApplyToEditor.Enabled := True;
    btnCopyOptSQL.Enabled := True;
    pgcMain.ActivePage := tabOptimizedSQL;
  end;

  if Trim(OptResult.IndexDDL) <> '' then
    btnExecuteIndexDDL.Enabled := True;
end;

procedure TFormAIOptimizer.HandleAIError(Sender: TObject; const AErrorMessage: string);
begin
  SetUIExecuting(False);
  lblElapsed.Caption := 'Gagal optimasi AI.';
  memAnalysis.Lines.Text := 'Terjadi kesalahan saat memproses optimasi kueri:' + LineEnding + AErrorMessage;
  MessageDlg('AI Optimizer Error', AErrorMessage, mtError, [mbOK], 0);
end;

procedure TFormAIOptimizer.btnApplyToEditorClick(Sender: TObject);
begin
  FOptimizedSQLResult := synOptimizedSQL.Lines.Text;
  ModalResult := mrOk;
end;

procedure TFormAIOptimizer.btnCopyOptSQLClick(Sender: TObject);
begin
  Clipboard.AsText := synOptimizedSQL.Lines.Text;
  MessageDlg('Query Optimizer', 'Kueri SQL teroptimasi berhasil disalin ke Clipboard.', mtInformation, [mbOK], 0);
end;

procedure TFormAIOptimizer.btnCopyIndexDDLClick(Sender: TObject);
begin
  Clipboard.AsText := synIndexDDL.Lines.Text;
  MessageDlg('Index Advisor', 'Rekomendasi indeks DDL berhasil disalin ke Clipboard.', mtInformation, [mbOK], 0);
end;

procedure TFormAIOptimizer.btnExecuteIndexDDLClick(Sender: TObject);
var
  Conn: TZConnection;
  DDL: string;
begin
  DDL := Trim(synIndexDDL.Lines.Text);
  if DDL = '' then Exit;

  if MessageDlg('Konfirmasi Pembuatan Indeks',
    Format('Eksekusi perintah DDL pembuatan indeks berikut ke database "%s"?%s%s', [
      FProfile.ConnectionName, LineEnding, DDL
    ]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

  Screen.Cursor := crHourGlass;
  Conn := TZConnection.Create(nil);
  try
    try
      case FProfile.DriverType of
        dtMySQL: Conn.Protocol := 'mysql';
        dtMariaDB: Conn.Protocol := 'mariadb';
        dtPostgreSQL: Conn.Protocol := 'postgresql';
        dtFirebird: Conn.Protocol := 'firebird';
        dtSQLite: Conn.Protocol := 'sqlite';
      end;
      Conn.HostName := FProfile.Host;
      Conn.Port := FProfile.Port;
      Conn.Database := FProfile.DatabaseName;
      Conn.User := FProfile.Username;
      Conn.Password := FProfile.Password;
      Conn.AutoCommit := True;
      Conn.Connect;

      Conn.ExecuteDirect(DDL);
      MessageDlg('Sukses', 'Indeks berhasil dibuat di database.', mtInformation, [mbOK], 0);
    except
      on E: Exception do
        MessageDlg('Gagal Eksekusi DDL Indeks', E.Message, mtError, [mbOK], 0);
    end;
  finally
    Conn.Free;
    Screen.Cursor := crDefault;
  end;
end;

procedure TFormAIOptimizer.btnReanalyzeClick(Sender: TObject);
begin
  RunExplainPlan;
  StartOptimization;
end;

procedure TFormAIOptimizer.btnCloseClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
