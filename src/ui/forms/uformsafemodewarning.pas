unit uFormSafeModeWarning;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Buttons,
  SynEdit, SynHighlighterSQL,
  uSafeModeGuardrails;

type
  { TFormSafeModeWarning }
  TFormSafeModeWarning = class(TForm)
    pnlTop: TPanel;
    lblBadge: TLabel;
    lblRiskTitle: TLabel;
    lblTargetNotice: TLabel;

    pnlCenter: TPanel;
    lblReasonHeader: TLabel;
    lblRiskReason: TLabel;
    lblSnippetHeader: TLabel;
    synOffendingSQL: TSynEdit;
    synSQLSyn: TSynSQLSyn;

    pnlBottom: TPanel;
    chkAcknowledge: TCheckBox;
    btnCancelExec: TBitBtn;
    btnProceedExec: TBitBtn;

    procedure FormCreate(Sender: TObject);
    procedure chkAcknowledgeChange(Sender: TObject);
    procedure btnCancelExecClick(Sender: TObject);
    procedure btnProceedExecClick(Sender: TObject);
  private
    FAnalysis: TSafeGuardAnalysis;
    procedure LoadAnalysisToUI;
  public
    class function PromptConfirmation(
      AOwner: TComponent;
      const AAnalysis: TSafeGuardAnalysis;
      const ADBTarget: string
    ): Boolean;
  end;

implementation

{$R *.lfm}

{ TFormSafeModeWarning }

class function TFormSafeModeWarning.PromptConfirmation(
  AOwner: TComponent;
  const AAnalysis: TSafeGuardAnalysis;
  const ADBTarget: string
): Boolean;
var
  Frm: TFormSafeModeWarning;
begin
  Frm := TFormSafeModeWarning.Create(AOwner);
  try
    Frm.FAnalysis := AAnalysis;
    if ADBTarget <> '' then
      Frm.lblTargetNotice.Caption := 'Target Database: ' + ADBTarget
    else
      Frm.lblTargetNotice.Caption := 'Target: Database Aktif';

    Frm.LoadAnalysisToUI;
    Result := (Frm.ShowModal = mrOk);
  finally
    Frm.Free;
  end;
end;

procedure TFormSafeModeWarning.FormCreate(Sender: TObject);
begin
  synOffendingSQL.Highlighter := synSQLSyn;
  btnProceedExec.Enabled := False;
end;

procedure TFormSafeModeWarning.LoadAnalysisToUI;
begin
  lblRiskTitle.Caption := FAnalysis.Title;
  lblRiskReason.Caption := FAnalysis.RiskReason;
  synOffendingSQL.Lines.Text := FAnalysis.OffendingSQL;

  case FAnalysis.RiskLevel of
    rlCritical:
    begin
      pnlTop.Color := $002B2BD8; // Merah Tua
      lblBadge.Caption := ' ⛔ LEVEL RISIKO: KRITIKAL ';
    end;
    rlHigh:
    begin
      pnlTop.Color := $000A75E6; // Oranye Tua
      lblBadge.Caption := ' ⚠️ LEVEL RISIKO: TINGGI ';
    end;
    else
    begin
      pnlTop.Color := $004A6984;
      lblBadge.Caption := ' ℹ️ LEVEL RISIKO: MENENGAH ';
    end;
  end;
end;

procedure TFormSafeModeWarning.chkAcknowledgeChange(Sender: TObject);
begin
  btnProceedExec.Enabled := chkAcknowledge.Checked;
end;

procedure TFormSafeModeWarning.btnCancelExecClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TFormSafeModeWarning.btnProceedExecClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

end.
