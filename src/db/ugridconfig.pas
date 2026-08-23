unit uGridConfig;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Graphics, fpjson, jsonparser;

type
  { TGridConfig }
  TGridConfig = class
  public
    MaxColWidth: Integer;
    RowsPerPage: Integer;
    MaxRowsLimit: Integer;
    TextLinesPerRow: Integer;
    FontName: string;
    FontSize: Integer;

    // Warna Teks Berdasarkan Tipe Data
    ColorInteger: TColor;
    ColorFloat: TColor;
    ColorString: TColor;
    ColorDateTime: TColor;
    ColorBlob: TColor;

    // Warna Latar Belakang Sel & Baris
    ColorNullBg: TColor;
    UseNullBg: Boolean;
    ColorAltRow1: TColor;
    ColorAltRow2: TColor;
    UseAltRowColor: Boolean;
    ColorSameTextBg: TColor;
    UseSameTextBg: Boolean;

    // Format Nilai & Peringatan
    MaxDecimalZeros: Integer;
    SortWarningThreshold: Integer;
    UseLocaleNumberFormat: Boolean;
    LowercaseHex: Boolean;
    PopupSQLTextOverTabs: Boolean;
    ShowRowNumbers: Boolean;

    constructor Create;
    procedure SetDefaults;
    procedure LoadFromFile(const AFileName: string);
    procedure SaveToFile(const AFileName: string);
  end;

function GridConfig: TGridConfig;

implementation

var
  GGridConfig: TGridConfig = nil;

function GridConfig: TGridConfig;
begin
  if not Assigned(GGridConfig) then
    GGridConfig := TGridConfig.Create;
  Result := GGridConfig;
end;

{ TGridConfig }

constructor TGridConfig.Create;
begin
  inherited Create;
  SetDefaults;
  LoadFromFile(ExtractFilePath(ParamStr(0)) + 'grid_settings.json');
end;

procedure TGridConfig.SetDefaults;
begin
  MaxColWidth := 300;
  RowsPerPage := 20000;
  MaxRowsLimit := 20000;
  TextLinesPerRow := 1;
  FontName := 'Segoe UI';
  FontSize := 10;

  ColorInteger := clBlue;
  ColorFloat := $00804000; // Teal/Brown
  ColorString := clBlack;
  ColorDateTime := $00008000; // Green
  ColorBlob := clMaroon;

  ColorNullBg := $00E8E8E8;
  UseNullBg := False;
  ColorAltRow1 := clWindow;
  ColorAltRow2 := $00F9F9F9;
  UseAltRowColor := True;
  ColorSameTextBg := $00D0FFFF; // Info yellow/cream
  UseSameTextBg := True;

  MaxDecimalZeros := 1;
  SortWarningThreshold := 10000;
  UseLocaleNumberFormat := True;
  LowercaseHex := True;
  PopupSQLTextOverTabs := True;
  ShowRowNumbers := True;
end;

procedure TGridConfig.LoadFromFile(const AFileName: string);
var
  FS: TFileStream;
  Parser: TJSONParser;
  Data: TJSONData;
  Obj: TJSONObject;
begin
  if not FileExists(AFileName) then Exit;
  FS := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    Parser := TJSONParser.Create(FS);
    try
      Data := Parser.Parse;
      try
        if Data is TJSONObject then
        begin
          Obj := TJSONObject(Data);
          MaxColWidth := Obj.Get('max_col_width', MaxColWidth);
          RowsPerPage := Obj.Get('rows_per_page', RowsPerPage);
          MaxRowsLimit := Obj.Get('max_rows_limit', MaxRowsLimit);
          TextLinesPerRow := Obj.Get('text_lines_per_row', TextLinesPerRow);
          FontName := Obj.Get('font_name', FontName);
          FontSize := Obj.Get('font_size', FontSize);

          ColorInteger := StringToColor(Obj.Get('color_integer', ColorToString(ColorInteger)));
          ColorFloat := StringToColor(Obj.Get('color_float', ColorToString(ColorFloat)));
          ColorString := StringToColor(Obj.Get('color_string', ColorToString(ColorString)));
          ColorDateTime := StringToColor(Obj.Get('color_datetime', ColorToString(ColorDateTime)));
          ColorBlob := StringToColor(Obj.Get('color_blob', ColorToString(ColorBlob)));

          ColorNullBg := StringToColor(Obj.Get('color_null_bg', ColorToString(ColorNullBg)));
          UseNullBg := Obj.Get('use_null_bg', UseNullBg);
          ColorAltRow1 := StringToColor(Obj.Get('color_alt_row1', ColorToString(ColorAltRow1)));
          ColorAltRow2 := StringToColor(Obj.Get('color_alt_row2', ColorToString(ColorAltRow2)));
          UseAltRowColor := Obj.Get('use_alt_row_color', UseAltRowColor);
          ColorSameTextBg := StringToColor(Obj.Get('color_same_text_bg', ColorToString(ColorSameTextBg)));
          UseSameTextBg := Obj.Get('use_same_text_bg', UseSameTextBg);

          MaxDecimalZeros := Obj.Get('max_decimal_zeros', MaxDecimalZeros);
          SortWarningThreshold := Obj.Get('sort_warning_threshold', SortWarningThreshold);
          UseLocaleNumberFormat := Obj.Get('use_locale_number_format', UseLocaleNumberFormat);
          LowercaseHex := Obj.Get('lowercase_hex', LowercaseHex);
          PopupSQLTextOverTabs := Obj.Get('popup_sql_text_over_tabs', PopupSQLTextOverTabs);
          ShowRowNumbers := Obj.Get('show_row_numbers', ShowRowNumbers);
        end;
      finally
        Data.Free;
      end;
    finally
      Parser.Free;
    end;
  finally
    FS.Free;
  end;
end;

procedure TGridConfig.SaveToFile(const AFileName: string);
var
  Obj: TJSONObject;
  SL: TStringList;
begin
  Obj := TJSONObject.Create;
  SL := TStringList.Create;
  try
    Obj.Add('max_col_width', MaxColWidth);
    Obj.Add('rows_per_page', RowsPerPage);
    Obj.Add('max_rows_limit', MaxRowsLimit);
    Obj.Add('text_lines_per_row', TextLinesPerRow);
    Obj.Add('font_name', FontName);
    Obj.Add('font_size', FontSize);

    Obj.Add('color_integer', ColorToString(ColorInteger));
    Obj.Add('color_float', ColorToString(ColorFloat));
    Obj.Add('color_string', ColorToString(ColorString));
    Obj.Add('color_datetime', ColorToString(ColorDateTime));
    Obj.Add('color_blob', ColorToString(ColorBlob));

    Obj.Add('color_null_bg', ColorToString(ColorNullBg));
    Obj.Add('use_null_bg', UseNullBg);
    Obj.Add('color_alt_row1', ColorToString(ColorAltRow1));
    Obj.Add('color_alt_row2', ColorToString(ColorAltRow2));
    Obj.Add('use_alt_row_color', UseAltRowColor);
    Obj.Add('color_same_text_bg', ColorToString(ColorSameTextBg));
    Obj.Add('use_same_text_bg', UseSameTextBg);

    Obj.Add('max_decimal_zeros', MaxDecimalZeros);
    Obj.Add('sort_warning_threshold', SortWarningThreshold);
    Obj.Add('use_locale_number_format', UseLocaleNumberFormat);
    Obj.Add('lowercase_hex', LowercaseHex);
    Obj.Add('popup_sql_text_over_tabs', PopupSQLTextOverTabs);
    Obj.Add('show_row_numbers', ShowRowNumbers);

    SL.Text := Obj.FormatJSON;
    SL.SaveToFile(AFileName);
  finally
    Obj.Free;
    SL.Free;
  end;
end;

finalization
  if Assigned(GGridConfig) then
    FreeAndNil(GGridConfig);

end.
