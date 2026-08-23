unit uThemeManager;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls,
  ComCtrls, Grids, Buttons, SynEdit, SynHighlighterSQL, IniFiles;

type
  { TAppTheme }
  TAppTheme = (thLight, thDarkSlate, thDracula, thMonokai);

  { TThemePalette }
  TThemePalette = record
    ThemeName: string;
    IsDark: Boolean;

    // Background & Surfaces
    BgMain: TColor;
    BgSurface: TColor;
    BgSurfaceAlt: TColor;
    BgPanelHeader: TColor;
    BorderColor: TColor;

    // Typography
    TextPrimary: TColor;
    TextSecondary: TColor;
    TextMuted: TColor;

    // Accent & Highlights
    AccentColor: TColor;
    AccentHover: TColor;
    AccentText: TColor;

    // Grids & Tables
    GridBg: TColor;
    GridHeaderBg: TColor;
    GridHeaderFont: TColor;
    GridLines: TColor;
    GridSelection: TColor;

    // TreeView & ListViews
    TreeBg: TColor;
    TreeFont: TColor;

    // SQL Editor (SynEdit)
    EditorBg: TColor;
    EditorGutterBg: TColor;
    EditorGutterFont: TColor;
    EditorCaretLine: TColor;
    EditorSelection: TColor;

    // SQL Highlighter Syntax
    SynKeyword: TColor;
    SynIdentifier: TColor;
    SynString: TColor;
    SynNumber: TColor;
    SynComment: TColor;
    SynSymbol: TColor;
    SynFunction: TColor;
  end;

  { TThemeManager }
  TThemeManager = class
  private
    class var FCurrentTheme: TAppTheme;
    class var FPalette: TThemePalette;
    class var FOnThemeChanged: TNotifyEvent;

    class procedure BuildPalette(ATheme: TAppTheme; out APalette: TThemePalette);
    class procedure StyleSynHighlighter(AHighlighter: TSynSQLSyn; const P: TThemePalette);
  public
    class procedure Initialize;
    class procedure SetTheme(ATheme: TAppTheme; AApplyToRootForm: TCustomForm = nil);
    class procedure ApplyThemeToControl(AControl: TControl);
    class procedure ApplyThemeToForm(AForm: TCustomForm);

    class property CurrentTheme: TAppTheme read FCurrentTheme;
    class property Palette: TThemePalette read FPalette;
    class property OnThemeChanged: TNotifyEvent read FOnThemeChanged write FOnThemeChanged;
  end;

implementation

{ TThemeManager }

class procedure TThemeManager.BuildPalette(ATheme: TAppTheme; out APalette: TThemePalette);
begin
  APalette.IsDark := (ATheme <> thLight);

  case ATheme of
    thLight:
    begin
      APalette.ThemeName       := 'Modern Light';
      APalette.BgMain          := $00F8FAFC;
      APalette.BgSurface       := clWhite;
      APalette.BgSurfaceAlt    := $00F1F5F9;
      APalette.BgPanelHeader   := $00E2E8F0;
      APalette.BorderColor     := $00CBD5E1;

      APalette.TextPrimary     := $000F172A;
      APalette.TextSecondary   := $00334155;
      APalette.TextMuted       := $0064748B;

      APalette.AccentColor     := $00D97706; // Blue-600
      APalette.AccentHover     := $00B45309;
      APalette.AccentText      := clWhite;

      APalette.GridBg          := clWhite;
      APalette.GridHeaderBg    := $00F1F5F9;
      APalette.GridHeaderFont  := $001E293B;
      APalette.GridLines       := $00E2E8F0;
      APalette.GridSelection   := $00FED7AA;

      APalette.TreeBg          := clWhite;
      APalette.TreeFont        := $000F172A;

      APalette.EditorBg        := clWhite;
      APalette.EditorGutterBg  := $00F8FAFC;
      APalette.EditorGutterFont:= $0094A3B8;
      APalette.EditorCaretLine := $00F1F5F9;
      APalette.EditorSelection := $00E2E8F0;

      APalette.SynKeyword      := $00B45309; // Blue bold
      APalette.SynIdentifier   := $000F172A;
      APalette.SynString       := $00047857; // Emerald Green
      APalette.SynNumber       := $00D97706;
      APalette.SynComment      := $0094A3B8;
      APalette.SynSymbol       := $00334155;
      APalette.SynFunction     := $007C3AED;
    end;

    thDarkSlate:
    begin
      APalette.ThemeName       := 'Slate Dark';
      APalette.BgMain          := $000F172A; // Slate-900
      APalette.BgSurface       := $001E293B; // Slate-800
      APalette.BgSurfaceAlt    := $00334155; // Slate-700
      APalette.BgPanelHeader   := $001E293B;
      APalette.BorderColor     := $00475569;

      APalette.TextPrimary     := $00F8FAFC;
      APalette.TextSecondary   := $00CBD5E1;
      APalette.TextMuted       := $0094A3B8;

      APalette.AccentColor     := $00F59E0B; // Sky/Cyan Accent
      APalette.AccentHover     := $00D97706;
      APalette.AccentText      := clWhite;

      APalette.GridBg          := $001E293B;
      APalette.GridHeaderBg    := $000F172A;
      APalette.GridHeaderFont  := $00F8FAFC;
      APalette.GridLines       := $00334155;
      APalette.GridSelection   := $00475569;

      APalette.TreeBg          := $001E293B;
      APalette.TreeFont        := $00F8FAFC;

      APalette.EditorBg        := $000F172A;
      APalette.EditorGutterBg  := $001E293B;
      APalette.EditorGutterFont:= $0064748B;
      APalette.EditorCaretLine := $001E293B;
      APalette.EditorSelection := $00334155;

      APalette.SynKeyword      := $0038BDF8; // Amber/Cyan
      APalette.SynIdentifier   := $00F8FAFC;
      APalette.SynString       := $004ADE80; // Light Green
      APalette.SynNumber       := $00FBBF24;
      APalette.SynComment      := $0064748B;
      APalette.SynSymbol       := $0094A3B8;
      APalette.SynFunction     := $00C084FC;
    end;

    thDracula:
    begin
      APalette.ThemeName       := 'Dracula';
      APalette.BgMain          := $001E1F29;
      APalette.BgSurface       := $00282A36;
      APalette.BgSurfaceAlt    := $0044475A;
      APalette.BgPanelHeader   := $0021222C;
      APalette.BorderColor     := $006272A4;

      APalette.TextPrimary     := $00F8F8F2;
      APalette.TextSecondary   := $00BD93F9;
      APalette.TextMuted       := $006272A4;

      APalette.AccentColor     := $00BD93F9; // Purple
      APalette.AccentHover     := $00FF79C6; // Pink
      APalette.AccentText      := $00282A36;

      APalette.GridBg          := $00282A36;
      APalette.GridHeaderBg    := $001E1F29;
      APalette.GridHeaderFont  := $0050FA7B;
      APalette.GridLines       := $0044475A;
      APalette.GridSelection   := $0044475A;

      APalette.TreeBg          := $00282A36;
      APalette.TreeFont        := $00F8F8F2;

      APalette.EditorBg        := $00282A36;
      APalette.EditorGutterBg  := $001E1F29;
      APalette.EditorGutterFont:= $006272A4;
      APalette.EditorCaretLine := $0044475A;
      APalette.EditorSelection := $0044475A;

      APalette.SynKeyword      := $00FF79C6; // Pink
      APalette.SynIdentifier   := $00F8F8F2;
      APalette.SynString       := $00F1FA8C; // Yellow
      APalette.SynNumber       := $00BD93F9; // Purple
      APalette.SynComment      := $006272A4;
      APalette.SynSymbol       := $00FFB86C; // Orange
      APalette.SynFunction     := $0050FA7B; // Green
    end;

    thMonokai:
    begin
      APalette.ThemeName       := 'Monokai Pro';
      APalette.BgMain          := $00221F22;
      APalette.BgSurface       := $002D2A2E;
      APalette.BgSurfaceAlt    := $00403E41;
      APalette.BgPanelHeader   := $0019181A;
      APalette.BorderColor     := $005B595C;

      APalette.TextPrimary     := $00FCFCFA;
      APalette.TextSecondary   := $00FFD866;
      APalette.TextMuted       := $00727072;

      APalette.AccentColor     := $0078DCE8; // Cyan
      APalette.AccentHover     := $00A9DC76; // Green
      APalette.AccentText      := $00221F22;

      APalette.GridBg          := $002D2A2E;
      APalette.GridHeaderBg    := $00221F22;
      APalette.GridHeaderFont  := $00FFD866;
      APalette.GridLines       := $00403E41;
      APalette.GridSelection   := $00403E41;

      APalette.TreeBg          := $002D2A2E;
      APalette.TreeFont        := $00FCFCFA;

      APalette.EditorBg        := $002D2A2E;
      APalette.EditorGutterBg  := $00221F22;
      APalette.EditorGutterFont:= $00727072;
      APalette.EditorCaretLine := $00403E41;
      APalette.EditorSelection := $00403E41;

      APalette.SynKeyword      := $00FF6188; // Red/Pink
      APalette.SynIdentifier   := $00FCFCFA;
      APalette.SynString       := $00FFD866; // Yellow
      APalette.SynNumber       := $00AB9DF2; // Purple
      APalette.SynComment      := $00727072;
      APalette.SynSymbol       := $00FF6188;
      APalette.SynFunction     := $0078DCE8; // Cyan
    end;
  end;
end;

class procedure TThemeManager.StyleSynHighlighter(AHighlighter: TSynSQLSyn; const P: TThemePalette);
begin
  if not Assigned(AHighlighter) then Exit;

  AHighlighter.KeyAttri.Foreground := P.SynKeyword;
  AHighlighter.KeyAttri.Style := [fsBold];

  AHighlighter.IdentifierAttri.Foreground := P.SynIdentifier;
  AHighlighter.StringAttri.Foreground := P.SynString;
  AHighlighter.NumberAttri.Foreground := P.SynNumber;
  AHighlighter.CommentAttri.Foreground := P.SynComment;
  AHighlighter.SymbolAttri.Foreground := P.SynSymbol;
  AHighlighter.FunctionAttri.Foreground := P.SynFunction;
end;

class procedure TThemeManager.ApplyThemeToControl(AControl: TControl);
var
  I: Integer;
  P: TThemePalette;
  WinCtrl: TWinControl;
begin
  if not Assigned(AControl) then Exit;
  P := FPalette;

  // 1. TPanel
  if AControl is TPanel then
  begin
    TPanel(AControl).Color := P.BgSurface;
    TPanel(AControl).Font.Color := P.TextPrimary;
  end
  // 2. TSynEdit (SQL Editor)
  else if AControl is TSynEdit then
  begin
    with TSynEdit(AControl) do
    begin
      Color := P.EditorBg;
      Font.Color := P.TextPrimary;
      Gutter.Color := P.EditorGutterBg;
      Gutter.LineNumberPart.MarkupInfo.Foreground := P.EditorGutterFont;
      Gutter.LineNumberPart.MarkupInfo.Background := P.EditorGutterBg;
      SelectedColor.Background := P.EditorSelection;
      LineHighlightColor.Background := P.EditorCaretLine;

      if Assigned(Highlighter) and (Highlighter is TSynSQLSyn) then
        StyleSynHighlighter(TSynSQLSyn(Highlighter), P);
    end;
  end
  // 3. TStringGrid
  else if AControl is TStringGrid then
  begin
    with TStringGrid(AControl) do
    begin
      Color := P.GridBg;
      FixedColor := P.GridHeaderBg;
      Font.Color := P.TextPrimary;
      TitleFont.Color := P.GridHeaderFont;
      GridLineColor := P.GridLines;
    end;
  end
  // 4. TTreeView
  else if AControl is TTreeView then
  begin
    with TTreeView(AControl) do
    begin
      Color := P.TreeBg;
      Font.Color := P.TreeFont;
    end;
  end
  // 5. TListView
  else if AControl is TListView then
  begin
    with TListView(AControl) do
    begin
      Color := P.BgSurface;
      Font.Color := P.TextPrimary;
    end;
  end
  // 6. TMemo & TEdit
  else if (AControl is TMemo) or (AControl is TEdit) then
  begin
    TWinControl(AControl).Color := P.BgSurface;
    TWinControl(AControl).Font.Color := P.TextPrimary;
  end
  // 7. TLabel
  else if AControl is TLabel then
  begin
    TLabel(AControl).Font.Color := P.TextPrimary;
  end
  // 8. TPageControl
  else if AControl is TPageControl then
  begin
    TPageControl(AControl).Color := P.BgMain;
    TPageControl(AControl).Font.Color := P.TextPrimary;
  end;

  // Rekursif ke Child Controls
  if AControl is TWinControl then
  begin
    WinCtrl := TWinControl(AControl);
    for I := 0 to WinCtrl.ControlCount - 1 do
      ApplyThemeToControl(WinCtrl.Controls[I]);
  end;
end;

class procedure TThemeManager.ApplyThemeToForm(AForm: TCustomForm);
var
  I: Integer;
begin
  if not Assigned(AForm) then Exit;
  AForm.Color := FPalette.BgMain;
  AForm.Font.Color := FPalette.TextPrimary;

  for I := 0 to AForm.ControlCount - 1 do
    ApplyThemeToControl(AForm.Controls[I]);

  AForm.Invalidate;
end;

class procedure TThemeManager.SetTheme(ATheme: TAppTheme; AApplyToRootForm: TCustomForm);
var
  I: Integer;
begin
  FCurrentTheme := ATheme;
  BuildPalette(FCurrentTheme, FPalette);

  if Assigned(AApplyToRootForm) then
    ApplyThemeToForm(AApplyToRootForm)
  else
  begin
    for I := 0 to Screen.FormCount - 1 do
      ApplyThemeToForm(Screen.Forms[I]);
  end;

  if Assigned(FOnThemeChanged) then
    FOnThemeChanged(nil);
end;

class procedure TThemeManager.Initialize;
begin
  FCurrentTheme := thLight;
  BuildPalette(FCurrentTheme, FPalette);
end;

initialization
  TThemeManager.Initialize;

end.
