unit uFormAppSettings;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  ComCtrls, StdCtrls, Buttons, Spin,
  uThemeManager, uAppSettings;

type
  { TFormAppSettings }
  TFormAppSettings = class(TForm)
    pnlSidebar: TPanel;
    tvCategories: TTreeView;
    splDivider: TSplitter;

    pnlMain: TPanel;
    pgcSettings: TPageControl;

    // Tab Sheets
    tabGeneral: TTabSheet;
    tabEditor: TTabSheet;
    tabDataGrid: TTabSheet;
    tabDatabase: TTabSheet;
    tabAI: TTabSheet;
    tabNetwork: TTabSheet;
    tabDataTools: TTabSheet;

    // Tab 1: Umum & Sesi
    chkRestoreSession: TCheckBox;
    chkAutoConnectLast: TCheckBox;
    chkConfirmOnExit: TCheckBox;
    lblHistoryDays: TLabel;
    seHistoryDays: TSpinEdit;

    // Tab 2: Tampilan & Editor SQL
    lblTheme: TLabel;
    cboTheme: TComboBox;
    lblFontName: TLabel;
    cboFontName: TComboBox;
    lblFontSize: TLabel;
    seFontSize: TSpinEdit;
    chkShowLineNumbers: TCheckBox;
    chkHighlightLine: TCheckBox;
    chkWordWrap: TCheckBox;
    lblTabWidth: TLabel;
    seTabWidth: TSpinEdit;
    chkIntelliSenseAuto: TCheckBox;
    chkIntelliSenseCase: TCheckBox;

    // Tab 3: Tampilan Data Grid
    chkGridZebra: TCheckBox;
    chkGridShowNull: TCheckBox;
    lblGridDensity: TLabel;
    cboGridDensity: TComboBox;
    chkGridAutoFit: TCheckBox;
    lblDateTimeFmt: TLabel;
    edtDateTimeFmt: TEdit;
    lblDateFmt: TLabel;
    edtDateFmt: TEdit;
    chkGridCopyHeaders: TCheckBox;

    // Tab 4: Database & Safety Guardrails
    lblSelectLimit: TLabel;
    seSelectLimit: TSpinEdit;
    lblTimeoutSec: TLabel;
    seTimeoutSec: TSpinEdit;
    chkSafeMode: TCheckBox;
    chkRequireWhere: TCheckBox;

    // Tab 5: Integrasi AI Assistant
    lblAIProvider: TLabel;
    cboAIProvider: TComboBox;
    lblAIApiKey: TLabel;
    edtAIApiKey: TEdit;
    lblAIModel: TLabel;
    edtAIModel: TEdit;
    lblAITemp: TLabel;
    edtAITemp: TEdit;
    lblAILang: TLabel;
    cboAILang: TComboBox;

    // Tab 6: SSH & Jaringan
    lblSSHPath: TLabel;
    edtSSHPath: TEdit;
    lblSSHTimeout: TLabel;
    seSSHTimeout: TSpinEdit;

    // Tab 7: Ekspor & Alat Data
    lblDefaultDelim: TLabel;
    cboDefaultDelim: TComboBox;
    lblMockBatch: TLabel;
    seMockBatch: TSpinEdit;

    // Tombol Aksi Bawah
    pnlBottom: TPanel;
    btnResetDefaults: TBitBtn;
    btnSave: TBitBtn;
    btnCancel: TBitBtn;

    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure tvCategoriesSelectionChanged(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnResetDefaultsClick(Sender: TObject);
  private
    procedure InitCategoryTree;
    procedure LoadValuesToUI;
    procedure SaveValuesFromUI;
  public
    class function ExecuteSettings(AOwner: TComponent): Boolean;
  end;

var
  FormAppSettings: TFormAppSettings;

implementation

{$R *.lfm}

{ TFormAppSettings }

class function TFormAppSettings.ExecuteSettings(AOwner: TComponent): Boolean;
var
  Dlg: TFormAppSettings;
begin
  Dlg := TFormAppSettings.Create(AOwner);
  try
    Result := (Dlg.ShowModal = mrOk);
  finally
    Dlg.Free;
  end;
end;

procedure TFormAppSettings.InitCategoryTree;
begin
  tvCategories.Items.BeginUpdate;
  try
    tvCategories.Items.Clear;
    tvCategories.Items.Add(nil, '⚙️ Umum & Sesi');
    tvCategories.Items.Add(nil, '🎨 Tampilan & Editor');
    tvCategories.Items.Add(nil, '📊 Tampilan Data Grid');
    tvCategories.Items.Add(nil, '🛡️ Database & Safety');
    tvCategories.Items.Add(nil, '🤖 Integrasi AI Assistant');
    tvCategories.Items.Add(nil, '🔒 Jaringan & SSH');
    tvCategories.Items.Add(nil, '📦 Ekspor & Alat Data');
  finally
    tvCategories.Items.EndUpdate;
  end;
end;

procedure TFormAppSettings.FormCreate(Sender: TObject);
begin
  pgcSettings.ShowTabs := False;
  InitCategoryTree;

  cboFontName.Items.Assign(Screen.Fonts);

  cboTheme.Items.Clear;
  cboTheme.Items.Add('Modern Light');
  cboTheme.Items.Add('Slate Dark');
  cboTheme.Items.Add('Dracula');
  cboTheme.Items.Add('Monokai Pro');

  cboGridDensity.Items.Clear;
  cboGridDensity.Items.Add('Ringkas (Compact / 22px)');
  cboGridDensity.Items.Add('Normal (Standard / 26px)');
  cboGridDensity.Items.Add('Longgar (Relaxed / 32px)');

  cboAIProvider.Items.Clear;
  cboAIProvider.Items.Add('Google Gemini');
  cboAIProvider.Items.Add('OpenAI (ChatGPT)');
  cboAIProvider.Items.Add('DeepSeek');
  cboAIProvider.Items.Add('Ollama (Lokal)');

  cboAILang.Items.Clear;
  cboAILang.Items.Add('Indonesian');
  cboAILang.Items.Add('English');

  cboDefaultDelim.Items.Clear;
  cboDefaultDelim.Items.Add('Koma ( , )');
  cboDefaultDelim.Items.Add('Titik Koma ( ; )');
  cboDefaultDelim.Items.Add('Tab ( \t )');
  cboDefaultDelim.Items.Add('Garis Tegak ( | )');
end;

procedure TFormAppSettings.FormShow(Sender: TObject);
begin
  TThemeManager.ApplyThemeToForm(Self);
  LoadValuesToUI;

  if tvCategories.Items.Count > 0 then
    tvCategories.Selected := tvCategories.Items[0];
end;

procedure TFormAppSettings.tvCategoriesSelectionChanged(Sender: TObject);
begin
  if not Assigned(tvCategories.Selected) then Exit;
  pgcSettings.PageIndex := tvCategories.Selected.Index;
end;

procedure TFormAppSettings.LoadValuesToUI;
begin
  // 1. General
  chkRestoreSession.Checked := Settings.RestoreSession;
  chkAutoConnectLast.Checked := Settings.AutoConnectLastProfile;
  seHistoryDays.Value := Settings.HistoryRetentionDays;
  chkConfirmOnExit.Checked := Settings.ConfirmOnExit;

  // 2. Editor & Appearance
  cboTheme.ItemIndex := Integer(Settings.AppTheme);
  cboFontName.Text := Settings.EditorFontName;
  seFontSize.Value := Settings.EditorFontSize;
  chkShowLineNumbers.Checked := Settings.EditorShowLineNumbers;
  chkHighlightLine.Checked := Settings.EditorHighlightActiveLine;
  chkWordWrap.Checked := Settings.EditorWordWrap;
  seTabWidth.Value := Settings.EditorTabWidth;
  chkIntelliSenseAuto.Checked := Settings.IntelliSenseAutoTrigger;
  chkIntelliSenseCase.Checked := Settings.IntelliSenseCaseSensitive;

  // 3. Grid
  chkGridZebra.Checked := Settings.GridZebraStriping;
  chkGridShowNull.Checked := Settings.GridShowNullLabel;
  cboGridDensity.ItemIndex := Integer(Settings.GridDensity);
  chkGridAutoFit.Checked := Settings.GridAutoFitColumns;
  edtDateTimeFmt.Text := Settings.GridDateTimeFormat;
  edtDateFmt.Text := Settings.GridDateFormat;
  chkGridCopyHeaders.Checked := Settings.GridCopyIncludeHeaders;

  // 4. Database & Safety
  seSelectLimit.Value := Settings.DefaultSelectLimit;
  seTimeoutSec.Value := Settings.QueryTimeoutSeconds;
  chkSafeMode.Checked := Settings.SafeModeEnabled;
  chkRequireWhere.Checked := Settings.RequireWhereConfirmation;

  // 5. AI
  cboAIProvider.ItemIndex := Integer(Settings.AIProvider);
  edtAIApiKey.Text := Settings.AIApiKey;
  edtAIModel.Text := Settings.AIModelName;
  edtAITemp.Text := FloatToStr(Settings.AITemperature);
  cboAILang.Text := Settings.AILanguage;

  // 6. SSH
  edtSSHPath.Text := Settings.SSHExecutablePath;
  seSSHTimeout.Value := Settings.SSHTimeoutSeconds;

  // 7. Data Tools
  if Settings.ExportDefaultDelimiter = ';' then cboDefaultDelim.ItemIndex := 1
  else if Settings.ExportDefaultDelimiter = #9 then cboDefaultDelim.ItemIndex := 2
  else if Settings.ExportDefaultDelimiter = '|' then cboDefaultDelim.ItemIndex := 3
  else cboDefaultDelim.ItemIndex := 0;

  seMockBatch.Value := Settings.MockDataBatchSize;
end;

procedure TFormAppSettings.SaveValuesFromUI;
var
  OldTheme: TAppTheme;
begin
  OldTheme := Settings.AppTheme;

  // 1. General
  Settings.RestoreSession := chkRestoreSession.Checked;
  Settings.AutoConnectLastProfile := chkAutoConnectLast.Checked;
  Settings.HistoryRetentionDays := seHistoryDays.Value;
  Settings.ConfirmOnExit := chkConfirmOnExit.Checked;

  // 2. Editor & Appearance
  Settings.AppTheme := TAppTheme(cboTheme.ItemIndex);
  Settings.EditorFontName := cboFontName.Text;
  Settings.EditorFontSize := seFontSize.Value;
  Settings.EditorShowLineNumbers := chkShowLineNumbers.Checked;
  Settings.EditorHighlightActiveLine := chkHighlightLine.Checked;
  Settings.EditorWordWrap := chkWordWrap.Checked;
  Settings.EditorTabWidth := seTabWidth.Value;
  Settings.IntelliSenseAutoTrigger := chkIntelliSenseAuto.Checked;
  Settings.IntelliSenseCaseSensitive := chkIntelliSenseCase.Checked;

  // 3. Grid
  Settings.GridZebraStriping := chkGridZebra.Checked;
  Settings.GridShowNullLabel := chkGridShowNull.Checked;
  Settings.GridDensity := TGridDensity(cboGridDensity.ItemIndex);
  Settings.GridAutoFitColumns := chkGridAutoFit.Checked;
  Settings.GridDateTimeFormat := edtDateTimeFmt.Text;
  Settings.GridDateFormat := edtDateFmt.Text;
  Settings.GridCopyIncludeHeaders := chkGridCopyHeaders.Checked;

  // 4. Database & Safety
  Settings.DefaultSelectLimit := seSelectLimit.Value;
  Settings.QueryTimeoutSeconds := seTimeoutSec.Value;
  Settings.SafeModeEnabled := chkSafeMode.Checked;
  Settings.RequireWhereConfirmation := chkRequireWhere.Checked;

  // 5. AI
  Settings.AIProvider := TAIProviderType(cboAIProvider.ItemIndex);
  Settings.AIApiKey := Trim(edtAIApiKey.Text);
  Settings.AIModelName := Trim(edtAIModel.Text);
  Settings.AITemperature := StrToFloatDef(edtAITemp.Text, 0.2);
  Settings.AILanguage := cboAILang.Text;

  // 6. SSH
  Settings.SSHExecutablePath := Trim(edtSSHPath.Text);
  Settings.SSHTimeoutSeconds := seSSHTimeout.Value;

  // 7. Data Tools
  case cboDefaultDelim.ItemIndex of
    1: Settings.ExportDefaultDelimiter := ';';
    2: Settings.ExportDefaultDelimiter := #9;
    3: Settings.ExportDefaultDelimiter := '|';
    else Settings.ExportDefaultDelimiter := ',';
  end;

  Settings.MockDataBatchSize := seMockBatch.Value;
  Settings.SaveSettings;

  if OldTheme <> Settings.AppTheme then
    TThemeManager.SetTheme(Settings.AppTheme);
end;

procedure TFormAppSettings.btnSaveClick(Sender: TObject);
begin
  SaveValuesFromUI;
  ModalResult := mrOk;
end;

procedure TFormAppSettings.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TFormAppSettings.btnResetDefaultsClick(Sender: TObject);
begin
  if MessageDlg('Konfirmasi', 'Kembalikan seluruh preferensi ke pengaturan bawaan?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    Settings.Destroy;
    Settings := TAppSettings.Create;
    LoadValuesToUI;
  end;
end;

end.
