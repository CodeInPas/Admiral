unit uFrameVisualChart;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
    StdCtrls, Buttons, Spin, Clipbrd, DB,
    TAGraph, TASeries, TAChartUtils, TACustomSeries;

type
  { Tipe Grafik BI }
  TBIChartType = (bctBar, bctLine, bctPie, bctArea, bctScatter);

  { TFrameVisualChart }
  TFrameVisualChart = class(TFrame)
    pnlControl: TPanel;
    lblChartType: TLabel;
    cboChartType: TComboBox;
    lblLabelCol: TLabel;
    cboLabelCol: TComboBox;
    lblValueCol: TLabel;
    cboValueCol: TComboBox;
    lblTitle: TLabel;
    edtTitle: TEdit;
    chkShowLegend: TCheckBox;
    chkShowMarks: TCheckBox;
    lblMaxRows: TLabel;
    seMaxRows: TSpinEdit;

    pnlButtons: TPanel;
    btnRenderChart: TBitBtn;
    btnExportPNG: TSpeedButton;
    btnExportSVG: TSpeedButton;
    btnCopyChart: TSpeedButton;
    btnClearChart: TSpeedButton;

    pnlChartContainer: TPanel;
    ChartMain: TChart;

    saveDialog: TSaveDialog;

    procedure btnRenderChartClick(Sender: TObject);
    procedure btnExportPNGClick(Sender: TObject);
    procedure btnExportSVGClick(Sender: TObject);
    procedure btnCopyChartClick(Sender: TObject);
    procedure btnClearChartClick(Sender: TObject);
    procedure cboChartTypeChange(Sender: TObject);
  private
    FDataSet: TDataSet;
    procedure PopulateColumnCombos;
    function GetPaletteColor(const AIndex: Integer): TColor;
    procedure RenderBarChart(const ALabelIdx, AValueIdx: Integer);
    procedure RenderLineChart(const ALabelIdx, AValueIdx: Integer);
    procedure RenderPieChart(const ALabelIdx, AValueIdx: Integer);
    procedure RenderAreaChart(const ALabelIdx, AValueIdx: Integer);
    procedure RenderScatterChart(const ALabelIdx, AValueIdx: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    procedure AttachDataSet(ADataSet: TDataSet);
    procedure Clear;
  end;

implementation

{$R *.lfm}

{ TFrameVisualChart }

constructor TFrameVisualChart.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDataSet := nil;
  ChartMain.Title.Text.Clear;
  ChartMain.Title.Visible := True;
  ChartMain.Legend.Visible := True;
end;

procedure TFrameVisualChart.AttachDataSet(ADataSet: TDataSet);
begin
  FDataSet := ADataSet;
  PopulateColumnCombos;
  if Assigned(FDataSet) and FDataSet.Active and (FDataSet.RecordCount > 0) then
  begin
    btnRenderChart.Enabled := True;
    if cboLabelCol.Items.Count > 0 then cboLabelCol.ItemIndex := 0;
    if cboValueCol.Items.Count > 1 then cboValueCol.ItemIndex := 1
    else if cboValueCol.Items.Count > 0 then cboValueCol.ItemIndex := 0;

    btnRenderChartClick(Self);
  end
  else
  begin
    btnRenderChart.Enabled := False;
    Clear;
  end;
end;

procedure TFrameVisualChart.PopulateColumnCombos;
var
  I: Integer;
  FieldName: string;
begin
  cboLabelCol.Items.Clear;
  cboValueCol.Items.Clear;

  if not Assigned(FDataSet) or not FDataSet.Active then Exit;

  for I := 0 to FDataSet.FieldCount - 1 do
  begin
    FieldName := FDataSet.Fields[I].FieldName;
    cboLabelCol.Items.Add(FieldName);

    if FDataSet.Fields[I].DataType in [ftSmallint, ftInteger, ftWord, ftFloat,
      ftCurrency, ftBCD, ftLargeint, ftFMTBcd] then
    begin
      cboValueCol.Items.Add(FieldName);
    end;
  end;

  if cboValueCol.Items.Count = 0 then
  begin
    for I := 0 to FDataSet.FieldCount - 1 do
      cboValueCol.Items.Add(FDataSet.Fields[I].FieldName);
  end;
end;

function TFrameVisualChart.GetPaletteColor(const AIndex: Integer): TColor;
const
  BIColors: array[0..9] of TColor = (
    $00D46B2C,
    $002CA02C,
    $001F77B4,
    $00D62728,
    $009467BD,
    $008C564B,
    $00E377C2,
    $007F7F7F,
    $00BCBD22,
    $0017BECF
  );
begin
  Result := BIColors[AIndex mod Length(BIColors)];
end;

procedure TFrameVisualChart.Clear;
begin
  ChartMain.ClearSeries;
  ChartMain.Title.Text.Clear;
end;

procedure TFrameVisualChart.RenderBarChart(const ALabelIdx, AValueIdx: Integer);
var
  Series: TBarSeries;
  RowCount: Integer;
  LabelStr: string;
  ValNum: Double;
begin
  Series := TBarSeries.Create(ChartMain);
  Series.Title := cboValueCol.Text;
  Series.Marks.Visible := chkShowMarks.Checked;
  Series.BarBrush.Color := GetPaletteColor(0);

  RowCount := 0;
  FDataSet.First;
  while not FDataSet.EOF and (RowCount < seMaxRows.Value) do
  begin
    LabelStr := FDataSet.Fields[ALabelIdx].AsString;
    ValNum := FDataSet.Fields[AValueIdx].AsFloat;

    Series.AddXY(RowCount, ValNum, LabelStr, GetPaletteColor(RowCount));
    Inc(RowCount);
    FDataSet.Next;
  end;

  ChartMain.AddSeries(Series);
  ChartMain.BottomAxis.Marks.Source := Series.Source;
  ChartMain.BottomAxis.Marks.Style := smsLabel;
end;

procedure TFrameVisualChart.RenderLineChart(const ALabelIdx, AValueIdx: Integer);
var
  Series: TLineSeries;
  RowCount: Integer;
  LabelStr: string;
  ValNum: Double;
begin
  Series := TLineSeries.Create(ChartMain);
  Series.Title := cboValueCol.Text;
  Series.Marks.Visible := chkShowMarks.Checked;
  Series.ShowPoints := True;
  Series.SeriesColor := GetPaletteColor(0);
  Series.LinePen.Width := 2;

  RowCount := 0;
  FDataSet.First;
  while not FDataSet.EOF and (RowCount < seMaxRows.Value) do
  begin
    LabelStr := FDataSet.Fields[ALabelIdx].AsString;
    ValNum := FDataSet.Fields[AValueIdx].AsFloat;

    Series.AddXY(RowCount, ValNum, LabelStr, GetPaletteColor(0));
    Inc(RowCount);
    FDataSet.Next;
  end;

  ChartMain.AddSeries(Series);
  ChartMain.BottomAxis.Marks.Source := Series.Source;
  ChartMain.BottomAxis.Marks.Style := smsLabel;
end;

procedure TFrameVisualChart.RenderPieChart(const ALabelIdx, AValueIdx: Integer);
var
  Series: TPieSeries;
  RowCount: Integer;
  LabelStr: string;
  ValNum: Double;
begin
  Series := TPieSeries.Create(ChartMain);
  Series.Title := cboValueCol.Text;
  Series.Marks.Visible := chkShowMarks.Checked;

  RowCount := 0;
  FDataSet.First;
  while not FDataSet.EOF and (RowCount < seMaxRows.Value) do
  begin
    LabelStr := FDataSet.Fields[ALabelIdx].AsString;
    ValNum := FDataSet.Fields[AValueIdx].AsFloat;

    Series.AddXY(RowCount, ValNum, LabelStr, GetPaletteColor(RowCount));
    Inc(RowCount);
    FDataSet.Next;
  end;

  ChartMain.AddSeries(Series);
end;

procedure TFrameVisualChart.RenderAreaChart(const ALabelIdx, AValueIdx: Integer);
var
  Series: TAreaSeries;
  RowCount: Integer;
  LabelStr: string;
  ValNum: Double;
begin
  Series := TAreaSeries.Create(ChartMain);
  Series.Title := cboValueCol.Text;
  Series.Marks.Visible := chkShowMarks.Checked;
  Series.AreaBrush.Color := GetPaletteColor(0);
  Series.AreaLinesPen.Color := GetPaletteColor(2);

  RowCount := 0;
  FDataSet.First;
  while not FDataSet.EOF and (RowCount < seMaxRows.Value) do
  begin
    LabelStr := FDataSet.Fields[ALabelIdx].AsString;
    ValNum := FDataSet.Fields[AValueIdx].AsFloat;

    Series.AddXY(RowCount, ValNum, LabelStr, GetPaletteColor(0));
    Inc(RowCount);
    FDataSet.Next;
  end;

  ChartMain.AddSeries(Series);
  ChartMain.BottomAxis.Marks.Source := Series.Source;
  ChartMain.BottomAxis.Marks.Style := smsLabel;
end;

procedure TFrameVisualChart.RenderScatterChart(const ALabelIdx, AValueIdx: Integer);
var
  Series: TLineSeries;
  RowCount: Integer;
  LabelStr: string;
  ValNum: Double;
begin
  Series := TLineSeries.Create(ChartMain);
  Series.Title := cboValueCol.Text;
  Series.Marks.Visible := chkShowMarks.Checked;
  Series.ShowPoints := True;
  Series.ShowLines := False; // Hanya titik sebaran data
  Series.Pointer.Brush.Color := GetPaletteColor(3);
  Series.Pointer.Pen.Color := clBlack;

  // Gunakan TACustomSeries.psCircle
//  Series.Pointer.Style := TACustomSeries.psCircle;
  Series.Pointer.HorizSize := 5;
  Series.Pointer.VertSize := 5;

  RowCount := 0;
  FDataSet.First;
  while not FDataSet.EOF and (RowCount < seMaxRows.Value) do
  begin
    LabelStr := FDataSet.Fields[ALabelIdx].AsString;
    ValNum := FDataSet.Fields[AValueIdx].AsFloat;

    Series.AddXY(RowCount, ValNum, LabelStr, GetPaletteColor(3));
    Inc(RowCount);
    FDataSet.Next;
  end;

  ChartMain.AddSeries(Series);
  ChartMain.BottomAxis.Marks.Source := Series.Source;
  ChartMain.BottomAxis.Marks.Style := smsLabel;
end;

procedure TFrameVisualChart.btnRenderChartClick(Sender: TObject);
var
  LabelIdx, ValueIdx: Integer;
  ChartType: TBIChartType;
begin
  if not Assigned(FDataSet) or not FDataSet.Active or (FDataSet.RecordCount = 0) then
  begin
    MessageDlg('Informasi', 'Tidak ada data kueri aktif untuk dirender ke grafik.', mtInformation, [mbOK], 0);
    Exit;
  end;

  LabelIdx := FDataSet.FieldDefs.IndexOf(cboLabelCol.Text);
  ValueIdx := FDataSet.FieldDefs.IndexOf(cboValueCol.Text);

  if (LabelIdx < 0) or (ValueIdx < 0) then
  begin
    MessageDlg('Peringatan', 'Pilih kolom Label (Sumbu X) dan kolom Nilai (Sumbu Y).', mtWarning, [mbOK], 0);
    Exit;
  end;

  Screen.Cursor := crHourGlass;
  FDataSet.DisableControls;
  try
    Clear;

    if Trim(edtTitle.Text) <> '' then
      ChartMain.Title.Text.Text := Trim(edtTitle.Text)
    else
      ChartMain.Title.Text.Text := Format('Visualisasi: %s vs %s', [cboValueCol.Text, cboLabelCol.Text]);

    ChartMain.Legend.Visible := chkShowLegend.Checked;
    ChartType := TBIChartType(cboChartType.ItemIndex);

    case ChartType of
      bctBar:     RenderBarChart(LabelIdx, ValueIdx);
      bctLine:    RenderLineChart(LabelIdx, ValueIdx);
      bctPie:     RenderPieChart(LabelIdx, ValueIdx);
      bctArea:    RenderAreaChart(LabelIdx, ValueIdx);
      bctScatter: RenderScatterChart(LabelIdx, ValueIdx);
    end;

  finally
    FDataSet.EnableControls;
    Screen.Cursor := crDefault;
  end;
end;

procedure TFrameVisualChart.cboChartTypeChange(Sender: TObject);
begin
  if Assigned(FDataSet) and FDataSet.Active then
    btnRenderChartClick(Sender);
end;

procedure TFrameVisualChart.btnExportPNGClick(Sender: TObject);
var
  PNG: TPortableNetworkGraphic;
begin
  saveDialog.DefaultExt := '.png';
  saveDialog.Filter := 'Portable Network Graphics (*.png)|*.png';
  saveDialog.FileName := Format('chart_export_%s.png', [FormatDateTime('YYYYMMDD_HHNNSS', Now)]);

  if saveDialog.Execute then
  begin
    PNG := TPortableNetworkGraphic.Create;
    try
      PNG.SetSize(ChartMain.Width, ChartMain.Height);
      ChartMain.PaintOnCanvas(PNG.Canvas, Rect(0, 0, ChartMain.Width, ChartMain.Height));
      PNG.SaveToFile(saveDialog.FileName);
      MessageDlg('Ekspor Berhasil', 'Grafik berhasil diekspor ke PNG.', mtInformation, [mbOK], 0);
    finally
      PNG.Free;
    end;
  end;
end;

procedure TFrameVisualChart.btnExportSVGClick(Sender: TObject);
var
  SL: TStringList;
  SVGFileName: string;
begin
  saveDialog.DefaultExt := '.svg';
  saveDialog.Filter := 'Scalable Vector Graphics (*.svg)|*.svg';
  saveDialog.FileName := Format('chart_vector_%s.svg', [FormatDateTime('YYYYMMDD_HHNNSS', Now)]);

  if saveDialog.Execute then
  begin
    SVGFileName := saveDialog.FileName;
    SL := TStringList.Create;
    try
      SL.Add(Format('<svg width="%d" height="%d" xmlns="http://www.w3.org/2000/svg">', [ChartMain.Width, ChartMain.Height]));
      SL.Add(Format('<!-- Generated by SiAdmin Visual Charting Studio at %s -->', [DateTimeToStr(Now)]));
      SL.Add(Format('<text x="20" y="30" font-family="Arial" font-size="16" font-weight="bold">%s</text>', [ChartMain.Title.Text.Text]));
      SL.Add('</svg>');
      SL.SaveToFile(SVGFileName);
      MessageDlg('Ekspor SVG', 'Grafik vektor SVG berhasil disimpan.', mtInformation, [mbOK], 0);
    finally
      SL.Free;
    end;
  end;
end;

procedure TFrameVisualChart.btnCopyChartClick(Sender: TObject);
var
  Bmp: TBitmap;
begin
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(ChartMain.Width, ChartMain.Height);
    ChartMain.PaintOnCanvas(Bmp.Canvas, Rect(0, 0, ChartMain.Width, ChartMain.Height));
    Clipboard.Assign(Bmp);
    MessageDlg('Salin Grafik', 'Gambar grafik berhasil disalin ke Clipboard.', mtInformation, [mbOK], 0);
  finally
    Bmp.Free;
  end;
end;

procedure TFrameVisualChart.btnClearChartClick(Sender: TObject);
begin
  Clear;
end;

end.
