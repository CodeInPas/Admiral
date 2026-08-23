unit uFormGridSettings;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Buttons, Spin, ColorBox,
  uGridConfig;

type
  { TFormGridSettings }
  TFormGridSettings = class(TForm)
    pnlMain: TPanel;
    pnlBottom: TPanel;

    // Baris 1: Lebar Kolom
    lblMaxColWidth: TLabel;
    seMaxColWidth: TSpinEdit;

    // Baris 2: Baris per halaman dan maksimal
    lblRowsPerPage: TLabel;
    seRowsPerPage: TSpinEdit;
    seMaxRowsLimit: TSpinEdit;

    // Baris 3: Jumlah baris teks dalam baris grid
    lblTextLinesPerRow: TLabel;
    seTextLinesPerRow: TSpinEdit;

    // Baris 4: Huruf & Ukuran
    lblFont: TLabel;
    cboFontName: TComboBox;
    seFontSize: TSpinEdit;
    lblPt: TLabel;

    // Baris 5: Warna teks grid berdasarkan tipe data
    lblGridTextColor: TLabel;
    cboDataTypeChoice: TComboBox;
    cbDataTypeColor: TColorBox;

    // Baris 6: Latar Belakang Null
    lblNullBg: TLabel;
    chkNullBg: TCheckBox;
    cbNullBg: TColorBox;

    // Baris 7: Latar Belakang Baris Bergantian
    lblAltRowBg: TLabel;
    chkAltRowBg: TCheckBox;
    cbAltRow1: TColorBox;
    cbAltRow2: TColorBox;

    // Baris 8: Same Text Background
    lblSameTextBg: TLabel;
    chkSameTextBg: TCheckBox;
    cbSameTextBg: TColorBox;

    // Baris 9: Max Decimal Zeros
    lblMaxDecimalZeros: TLabel;
    seMaxDecimalZeros: TSpinEdit;
    lblMaxDecimalHint: TLabel;

    // Baris 10: Sort Warning
    lblSortWarning: TLabel;
    seSortWarning: TSpinEdit;

    // Checkboxes Opsi Tambahan
    chkLocaleNumber: TCheckBox;
    chkLowercaseHex: TCheckBox;
    chkPopupSQLText: TCheckBox;
    chkShowRowNumbers: TCheckBox;

    // Footer Buttons
    btnSave: TBitBtn;
    btnCancel: TBitBtn;
    btnResetDefault: TBitBtn;

    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure cboDataTypeChoiceChange(Sender: TObject);
    procedure cbDataTypeColorChange(Sender: TObject);
    procedure chkNullBgChange(Sender: TObject);
    procedure chkAltRowBgChange(Sender: TObject);
    procedure chkSameTextBgChange(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnResetDefaultClick(Sender: TObject);
  private
    procedure LoadConfigToUI;
    procedure SaveUIToConfig;
  public
    class function Execute(AOwner: TComponent): Boolean;
  end;

implementation

{$R *.lfm}

{ TFormGridSettings }

class function TFormGridSettings.Execute(AOwner: TComponent): Boolean;
var
  Frm: TFormGridSettings;
begin
  Frm := TFormGridSettings.Create(AOwner);
  try
    Result := (Frm.ShowModal = mrOk);
  finally
    Frm.Free;
  end;
end;

procedure TFormGridSettings.FormCreate(Sender: TObject);
begin
  cboFontName.Items.Assign(Screen.Fonts);
end;

procedure TFormGridSettings.FormShow(Sender: TObject);
begin
  LoadConfigToUI;
end;

procedure TFormGridSettings.LoadConfigToUI;
var
  Cfg: TGridConfig;
begin
  Cfg := GridConfig;

  seMaxColWidth.Value := Cfg.MaxColWidth;
  seRowsPerPage.Value := Cfg.RowsPerPage;
  seMaxRowsLimit.Value := Cfg.MaxRowsLimit;
  seTextLinesPerRow.Value := Cfg.TextLinesPerRow;

  cboFontName.Text := Cfg.FontName;
  seFontSize.Value := Cfg.FontSize;

  cboDataTypeChoice.ItemIndex := 0;
  cbDataTypeColor.Selected := Cfg.ColorInteger;

  chkNullBg.Checked := Cfg.UseNullBg;
  cbNullBg.Selected := Cfg.ColorNullBg;
  cbNullBg.Enabled := Cfg.UseNullBg;

  chkAltRowBg.Checked := Cfg.UseAltRowColor;
  cbAltRow1.Selected := Cfg.ColorAltRow1;
  cbAltRow2.Selected := Cfg.ColorAltRow2;
  cbAltRow1.Enabled := Cfg.UseAltRowColor;
  cbAltRow2.Enabled := Cfg.UseAltRowColor;

  chkSameTextBg.Checked := Cfg.UseSameTextBg;
  cbSameTextBg.Selected := Cfg.ColorSameTextBg;
  cbSameTextBg.Enabled := Cfg.UseSameTextBg;

  seMaxDecimalZeros.Value := Cfg.MaxDecimalZeros;
  seSortWarning.Value := Cfg.SortWarningThreshold;

  chkLocaleNumber.Checked := Cfg.UseLocaleNumberFormat;
  chkLowercaseHex.Checked := Cfg.LowercaseHex;
  chkPopupSQLText.Checked := Cfg.PopupSQLTextOverTabs;
  chkShowRowNumbers.Checked := Cfg.ShowRowNumbers;
end;

procedure TFormGridSettings.SaveUIToConfig;
var
  Cfg: TGridConfig;
begin
  Cfg := GridConfig;

  Cfg.MaxColWidth := seMaxColWidth.Value;
  Cfg.RowsPerPage := seRowsPerPage.Value;
  Cfg.MaxRowsLimit := seMaxRowsLimit.Value;
  Cfg.TextLinesPerRow := seTextLinesPerRow.Value;

  Cfg.FontName := cboFontName.Text;
  Cfg.FontSize := seFontSize.Value;

  Cfg.UseNullBg := chkNullBg.Checked;
  Cfg.ColorNullBg := cbNullBg.Selected;

  Cfg.UseAltRowColor := chkAltRowBg.Checked;
  Cfg.ColorAltRow1 := cbAltRow1.Selected;
  Cfg.ColorAltRow2 := cbAltRow2.Selected;

  Cfg.UseSameTextBg := chkSameTextBg.Checked;
  Cfg.ColorSameTextBg := cbSameTextBg.Selected;

  Cfg.MaxDecimalZeros := seMaxDecimalZeros.Value;
  Cfg.SortWarningThreshold := seSortWarning.Value;

  Cfg.UseLocaleNumberFormat := chkLocaleNumber.Checked;
  Cfg.LowercaseHex := chkLowercaseHex.Checked;
  Cfg.PopupSQLTextOverTabs := chkPopupSQLText.Checked;
  Cfg.ShowRowNumbers := chkShowRowNumbers.Checked;

  Cfg.SaveToFile(ExtractFilePath(ParamStr(0)) + 'grid_settings.json');
end;

procedure TFormGridSettings.cboDataTypeChoiceChange(Sender: TObject);
var
  Cfg: TGridConfig;
begin
  Cfg := GridConfig;
  case cboDataTypeChoice.ItemIndex of
    0: cbDataTypeColor.Selected := Cfg.ColorInteger;
    1: cbDataTypeColor.Selected := Cfg.ColorFloat;
    2: cbDataTypeColor.Selected := Cfg.ColorString;
    3: cbDataTypeColor.Selected := Cfg.ColorDateTime;
    4: cbDataTypeColor.Selected := Cfg.ColorBlob;
  end;
end;

procedure TFormGridSettings.cbDataTypeColorChange(Sender: TObject);
var
  Cfg: TGridConfig;
begin
  Cfg := GridConfig;
  case cboDataTypeChoice.ItemIndex of
    0: Cfg.ColorInteger := cbDataTypeColor.Selected;
    1: Cfg.ColorFloat := cbDataTypeColor.Selected;
    2: Cfg.ColorString := cbDataTypeColor.Selected;
    3: Cfg.ColorDateTime := cbDataTypeColor.Selected;
    4: Cfg.ColorBlob := cbDataTypeColor.Selected;
  end;
end;

procedure TFormGridSettings.chkNullBgChange(Sender: TObject);
begin
  cbNullBg.Enabled := chkNullBg.Checked;
end;

procedure TFormGridSettings.chkAltRowBgChange(Sender: TObject);
begin
  cbAltRow1.Enabled := chkAltRowBg.Checked;
  cbAltRow2.Enabled := chkAltRowBg.Checked;
end;

procedure TFormGridSettings.chkSameTextBgChange(Sender: TObject);
begin
  cbSameTextBg.Enabled := chkSameTextBg.Checked;
end;

procedure TFormGridSettings.btnSaveClick(Sender: TObject);
begin
  SaveUIToConfig;
  ModalResult := mrOk;
end;

procedure TFormGridSettings.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TFormGridSettings.btnResetDefaultClick(Sender: TObject);
begin
  if MessageDlg('Reset Pengaturan', 'Kembalikan seluruh pengaturan grid ke nilai bawaan?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    GridConfig.SetDefaults;
    LoadConfigToUI;
  end;
end;

end.
