unit uFrameMapViewer;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Buttons, DB, Math,
  // Unit resmi paket lazmapviewer
  mvMapViewer, mvTypes, mvEngine, mvGpsObj;

type
  { TFrameMapViewer }
  TFrameMapViewer = class(TFrame)
    pnlToolbar: TPanel;
    lblLat: TLabel;
    cboLatField: TComboBox;
    lblLng: TLabel;
    cboLngField: TComboBox;
    lblLabelField: TLabel;
    cboLabelField: TComboBox;
    lblProvider: TLabel;
    cboProvider: TComboBox;
    btnPlot: TSpeedButton;
    btnClear: TSpeedButton;
    btnAutoFit: TSpeedButton;
    lblStatus: TLabel;
    mapView: TMapView;

    procedure btnPlotClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure btnAutoFitClick(Sender: TObject);
    procedure cboProviderChange(Sender: TObject);
  private
    FDataSet: TDataSet;
    FMinLat, FMaxLat, FMinLng, FMaxLng: Double;
    FTotalPlotted: Integer;

    function SafeStrToFloat(const AValue: string; out AFloat: Double): Boolean;
    procedure PopulateProviders;
    procedure AutoDetectFields;
    procedure FitMapToBounds;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure SetDataSet(ADataSet: TDataSet);
    procedure PlotCoordinates;
    procedure ClearMap;
  end;

implementation

{$R *.lfm}

{ TFrameMapViewer }

constructor TFrameMapViewer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDataSet := nil;
  FTotalPlotted := 0;

  PopulateProviders;
  cboProvider.ItemIndex := cboProvider.Items.IndexOf('OpenStreetMap Standard');
  if cboProvider.ItemIndex < 0 then
    cboProvider.ItemIndex := 0;

  mapView.MapProvider := cboProvider.Text;
  mapView.Zoom := 5;
  // Default titik tengah koordinat kepulauan Indonesia (Lon, Lat)
  mapView.Center := RealPoint(113.9213, -0.7893);
end;

destructor TFrameMapViewer.Destroy;
begin
  inherited Destroy;
end;

procedure TFrameMapViewer.PopulateProviders;
begin
  cboProvider.Items.Clear;
  cboProvider.Items.Add('OpenStreetMap Standard');
  cboProvider.Items.Add('OpenTopoMap');
  cboProvider.Items.Add('CyclOSM');
  cboProvider.Items.Add('CartoDB Positron');
  cboProvider.Items.Add('CartoDB Dark Matter');
end;

function TFrameMapViewer.SafeStrToFloat(const AValue: string; out AFloat: Double): Boolean;
var
  CleanVal: string;
  FS: TFormatSettings;
begin
  Result := False;
  AFloat := 0.0;
  CleanVal := Trim(AValue);
  if CleanVal = '' then Exit;

  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  CleanVal := StringReplace(CleanVal, ',', '.', [rfReplaceAll]);

  Result := TryStrToFloat(CleanVal, AFloat, FS);
end;

procedure TFrameMapViewer.SetDataSet(ADataSet: TDataSet);
begin
  FDataSet := ADataSet;
  AutoDetectFields;
end;

procedure TFrameMapViewer.AutoDetectFields;
var
  I: Integer;
  FN: string;
begin
  cboLatField.Items.Clear;
  cboLngField.Items.Clear;
  cboLabelField.Items.Clear;

  cboLabelField.Items.Add('(Row / ID Otomatic)');

  if not Assigned(FDataSet) or (FDataSet.FieldCount = 0) then Exit;

  for I := 0 to FDataSet.FieldCount - 1 do
  begin
    FN := FDataSet.Fields[I].FieldName;
    cboLatField.Items.Add(FN);
    cboLngField.Items.Add(FN);
    cboLabelField.Items.Add(FN);

    // Deteksi kolom Latitude
    if (cboLatField.ItemIndex < 0) and (
       SameText(FN, 'lat') or SameText(FN, 'latitude') or
       SameText(FN, 'lintang') or SameText(FN, 'y') or
       SameText(FN, 'geom_lat') or SameText(FN, 'titik_lintang')
    ) then
      cboLatField.ItemIndex := cboLatField.Items.IndexOf(FN);

    // Deteksi kolom Longitude
    if (cboLngField.ItemIndex < 0) and (
       SameText(FN, 'lng') or SameText(FN, 'lon') or SameText(FN, 'longitude') or
       SameText(FN, 'bujur') or SameText(FN, 'x') or
       SameText(FN, 'geom_lng') or SameText(FN, 'titik_bujur')
    ) then
      cboLngField.ItemIndex := cboLngField.Items.IndexOf(FN);

    // Deteksi kolom label/nama entitas
    if (cboLabelField.ItemIndex <= 0) and (
       SameText(FN, 'name') or SameText(FN, 'nama') or SameText(FN, 'title') or
       SameText(FN, 'label') or SameText(FN, 'lokasi') or SameText(FN, 'keterangan')
    ) then
      cboLabelField.ItemIndex := cboLabelField.Items.IndexOf(FN);
  end;

  if cboLabelField.ItemIndex < 0 then
    cboLabelField.ItemIndex := 0;

  if (cboLatField.ItemIndex >= 0) and (cboLngField.ItemIndex >= 0) then
    PlotCoordinates;
end;

procedure TFrameMapViewer.PlotCoordinates;
var
  LatFld, LngFld, LabelFld: TField;
  LatVal, LngVal: Double;
  Bookmark: TBookmark;
  GpsPt: TGpsPoint;
  MarkerTitle: string;
begin
  if not Assigned(FDataSet) or not FDataSet.Active or FDataSet.IsEmpty then
  begin
    ClearMap;
    lblStatus.Caption := 'No data to plot.';
    Exit;
  end;

  LatFld := FDataSet.FindField(cboLatField.Text);
  LngFld := FDataSet.FindField(cboLngField.Text);

  if not Assigned(LatFld) or not Assigned(LngFld) then
  begin
    lblStatus.Caption := 'Please select the Latitude and Longitude columns.';
    Exit;
  end;

  if (cboLabelField.ItemIndex > 0) then
    LabelFld := FDataSet.FindField(cboLabelField.Text)
  else
    LabelFld := nil;

  mapView.GPSItems.Clear(0);
  FTotalPlotted := 0;

  FMinLat := 90.0;   FMaxLat := -90.0;
  FMinLng := 180.0;  FMaxLng := -180.0;

  FDataSet.DisableControls;
  Bookmark := FDataSet.GetBookmark;
  Screen.Cursor := crHourGlass;
  try
    FDataSet.First;
    while not FDataSet.EOF do
    begin
      if not LatFld.IsNull and not LngFld.IsNull then
      begin
        if SafeStrToFloat(LatFld.AsString, LatVal) and
           SafeStrToFloat(LngFld.AsString, LngVal) then
        begin
          // Validasi rentang koordinat WGS84
          if (LatVal >= -90.0) and (LatVal <= 90.0) and
             (LngVal >= -180.0) and (LngVal <= 180.0) and
             not ((LatVal = 0.0) and (LngVal = 0.0)) then
          begin
            if Assigned(LabelFld) and not LabelFld.IsNull then
              MarkerTitle := LabelFld.AsString
            else
              MarkerTitle := Format('Row #%d (%.5f, %.5f)', [FDataSet.RecNo, LatVal, LngVal]);

            // Buat TGpsPoint dengan parameter (Lon, Lat)
            GpsPt := TGpsPoint.Create(LngVal, LatVal);
            GpsPt.Name := MarkerTitle;
            mapView.GPSItems.Add(GpsPt, 0);

            if LatVal < FMinLat then FMinLat := LatVal;
            if LatVal > FMaxLat then FMaxLat := LatVal;
            if LngVal < FMinLng then FMinLng := LngVal;
            if LngVal > FMaxLng then FMaxLng := LngVal;

            Inc(FTotalPlotted);
          end;
        end;
      end;
      FDataSet.Next;
    end;
  finally
    if FDataSet.BookmarkValid(Bookmark) then
      FDataSet.GotoBookmark(Bookmark);
    FDataSet.FreeBookmark(Bookmark);
    FDataSet.EnableControls;
    Screen.Cursor := crDefault;
  end;

  lblStatus.Caption := Format('Total Plotted Points: %d', [FTotalPlotted]);

  if FTotalPlotted > 0 then
    FitMapToBounds;
end;

procedure TFrameMapViewer.FitMapToBounds;
var
  CenterLat, CenterLng, LatDiff, LngDiff, MaxDiff: Double;
  CalculatedZoom: Integer;
begin
  if FTotalPlotted = 0 then Exit;

  CenterLat := (FMinLat + FMaxLat) / 2.0;
  CenterLng := (FMinLng + FMaxLng) / 2.0;

  LatDiff := Abs(FMaxLat - FMinLat);
  LngDiff := Abs(FMaxLng - FMinLng);
  MaxDiff := Max(LatDiff, LngDiff);

  if MaxDiff < 0.01 then CalculatedZoom := 15
  else if MaxDiff < 0.05 then CalculatedZoom := 13
  else if MaxDiff < 0.2 then CalculatedZoom := 11
  else if MaxDiff < 1.0 then CalculatedZoom := 9
  else if MaxDiff < 5.0 then CalculatedZoom := 7
  else if MaxDiff < 15.0 then CalculatedZoom := 5
  else CalculatedZoom := 4;

  mapView.Center := RealPoint(CenterLng, CenterLat);
  mapView.Zoom := CalculatedZoom;
  mapView.Invalidate;
end;

procedure TFrameMapViewer.ClearMap;
begin
  mapView.GPSItems.Clear(0);
  FTotalPlotted := 0;
  lblStatus.Caption := 'Clean Map  (0 point).';
  mapView.Invalidate;
end;

procedure TFrameMapViewer.btnPlotClick(Sender: TObject);
begin
  PlotCoordinates;
end;

procedure TFrameMapViewer.btnClearClick(Sender: TObject);
begin
  ClearMap;
end;

procedure TFrameMapViewer.btnAutoFitClick(Sender: TObject);
begin
  FitMapToBounds;
end;

procedure TFrameMapViewer.cboProviderChange(Sender: TObject);
begin
  if cboProvider.Text <> '' then
  begin
    mapView.MapProvider := cboProvider.Text;
    mapView.Invalidate;
  end;
end;

end.
