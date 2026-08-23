unit uFormAISettings;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Buttons, Spin,
  uAIService;

type
  { TFormAISettings }
  TFormAISettings = class(TForm)
    pnlTop: TPanel;
    lblHeaderTitle: TLabel;
    lblHeaderSubtitle: TLabel;

    // Provider Selector
    gbProvider: TGroupBox;
    rbGemini: TRadioButton;
    rbLlamaCpp: TRadioButton;

    // Gemini Settings
    gbGemini: TGroupBox;
    lblGeminiKey: TLabel;
    edtGeminiKey: TEdit;
    btnToggleShowKey: TSpeedButton;
    lblGeminiModel: TLabel;
    cboGeminiModel: TComboBox;

    // llama.cpp Settings
    gbLlamaCpp: TGroupBox;
    lblLlamaEndpoint: TLabel;
    edtLlamaEndpoint: TEdit;
    lblLlamaModel: TLabel;
    edtLlamaModel: TEdit;
    lblLlamaApiKey: TLabel;
    edtLlamaApiKey: TEdit;

    // Parameter Global
    gbParameters: TGroupBox;
    lblTemperature: TLabel;
    seTemperature: TFloatSpinEdit;
    lblMaxTokens: TLabel;
    seMaxTokens: TSpinEdit;
    lblTimeout: TLabel;
    seTimeout: TSpinEdit;

    // Footer & Action
    pnlBottom: TPanel;
    btnTestConnection: TBitBtn;
    btnSave: TBitBtn;
    btnCancel: TBitBtn;
    lblTestStatus: TLabel;

    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure rbProviderChange(Sender: TObject);
    procedure btnToggleShowKeyClick(Sender: TObject);
    procedure btnTestConnectionClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    procedure LoadConfigToUI;
    procedure SaveUIToConfig;
    procedure UpdateProviderPanels;
    procedure HandleTestSuccess(Sender: TObject; const AResponseText: string; const AElapsedMS: Int64);
    procedure HandleTestError(Sender: TObject; const AErrorMessage: string);
  public
    class procedure Execute(AOwner: TComponent);
  end;

implementation

{$R *.lfm}

{ TFormAISettings }

class procedure TFormAISettings.Execute(AOwner: TComponent);
var
  Frm: TFormAISettings;
begin
  Frm := TFormAISettings.Create(AOwner);
  try
    Frm.ShowModal;
  finally
    Frm.Free;
  end;
end;

procedure TFormAISettings.FormCreate(Sender: TObject);
begin
  edtGeminiKey.EchoMode := emPassword;
end;

procedure TFormAISettings.FormShow(Sender: TObject);
begin
  LoadConfigToUI;
  UpdateProviderPanels;
  lblTestStatus.Caption := '';
end;

procedure TFormAISettings.LoadConfigToUI;
var
  Cfg: TAIConfig;
begin
  Cfg := AIService.Config;

  if Cfg.Provider = aipGemini then
    rbGemini.Checked := True
  else
    rbLlamaCpp.Checked := True;

  edtGeminiKey.Text := Cfg.GeminiApiKey;
  cboGeminiModel.Text := Cfg.GeminiModel;

  edtLlamaEndpoint.Text := Cfg.LlamaEndpoint;
  edtLlamaModel.Text := Cfg.LlamaModel;
  edtLlamaApiKey.Text := Cfg.LlamaApiKey;

  seTemperature.Value := Cfg.Temperature;
  seMaxTokens.Value := Cfg.MaxTokens;
  seTimeout.Value := Cfg.TimeoutSec;
end;

procedure TFormAISettings.SaveUIToConfig;
var
  Cfg: TAIConfig;
begin
  Cfg := AIService.Config;

  if rbGemini.Checked then
    Cfg.Provider := aipGemini
  else
    Cfg.Provider := aipLlamaCpp;

  Cfg.GeminiApiKey := Trim(edtGeminiKey.Text);
  Cfg.GeminiModel := Trim(cboGeminiModel.Text);

  Cfg.LlamaEndpoint := Trim(edtLlamaEndpoint.Text);
  Cfg.LlamaModel := Trim(edtLlamaModel.Text);
  Cfg.LlamaApiKey := Trim(edtLlamaApiKey.Text);

  Cfg.Temperature := seTemperature.Value;
  Cfg.MaxTokens := seMaxTokens.Value;
  Cfg.TimeoutSec := seTimeout.Value;

  Cfg.SaveToFile(AIService.ConfigFile);
end;

procedure TFormAISettings.UpdateProviderPanels;
begin
  gbGemini.Enabled := rbGemini.Checked;
  gbLlamaCpp.Enabled := rbLlamaCpp.Checked;

  if rbGemini.Checked then
  begin
    gbGemini.Color := clWindow;
    gbLlamaCpp.Color := clBtnFace;
  end
  else
  begin
    gbGemini.Color := clBtnFace;
    gbLlamaCpp.Color := clWindow;
  end;
end;

procedure TFormAISettings.rbProviderChange(Sender: TObject);
begin
  UpdateProviderPanels;
end;

procedure TFormAISettings.btnToggleShowKeyClick(Sender: TObject);
begin
  if edtGeminiKey.EchoMode = emPassword then
  begin
    edtGeminiKey.EchoMode := emNormal;
    btnToggleShowKey.Caption := '🙈';
  end
  else
  begin
    edtGeminiKey.EchoMode := emPassword;
    btnToggleShowKey.Caption := '👁';
  end;
end;

procedure TFormAISettings.btnTestConnectionClick(Sender: TObject);
begin
  SaveUIToConfig;
  lblTestStatus.Caption := 'Mengirim ping ke layanan AI...';
  lblTestStatus.Font.Color := clNavy;
  btnTestConnection.Enabled := False;

  AIService.ExecutePromptAsync(
    'Balas dengan satu kata: "PONG" jika koneksi aktif.',
    'Anda adalah sistem AI diagnostik.',
    @HandleTestSuccess,
    @HandleTestError
  );
end;

procedure TFormAISettings.HandleTestSuccess(Sender: TObject; const AResponseText: string; const AElapsedMS: Int64);
begin
  btnTestConnection.Enabled := True;
  lblTestStatus.Font.Color := $00008800; // Hijau
  lblTestStatus.Caption := Format('Koneksi Berhasil! (%d ms) Respon: "%s"', [AElapsedMS, Trim(AResponseText)]);
  MessageDlg('Uji Koneksi AI Sukses', Format('Layanan AI merespon dengan sukses dalam %d ms:%s%s', [
    AElapsedMS, LineEnding, Trim(AResponseText)
  ]), mtInformation, [mbOK], 0);
end;

procedure TFormAISettings.HandleTestError(Sender: TObject; const AErrorMessage: string);
begin
  btnTestConnection.Enabled := True;
  lblTestStatus.Font.Color := clRed;
  lblTestStatus.Caption := 'Koneksi Gagal!';
  MessageDlg('Uji Koneksi AI Gagal', AErrorMessage, mtError, [mbOK], 0);
end;

procedure TFormAISettings.btnSaveClick(Sender: TObject);
begin
  SaveUIToConfig;
  MessageDlg('Pengaturan AI', 'Konfigurasi layanan AI berhasil disimpan.', mtInformation, [mbOK], 0);
  ModalResult := mrOk;
end;

procedure TFormAISettings.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
