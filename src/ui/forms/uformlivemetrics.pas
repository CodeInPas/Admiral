unit uFormLiveMetrics;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Buttons,
  TAGraph, TASeries,
  uAppTypes, uDBTypes, uModelConnection, uServerMetricsCollector;

type
  { TFormLiveMetrics }
  TFormLiveMetrics = class(TForm)
    btnToggleMonitor: TBitBtn;
    cboConnections: TComboBox;
    cboInterval: TComboBox;
    lblCardConnTitle: TLabel;
    lblCardConnVal: TLabel;
    lblCardHitTitle: TLabel;
    lblCardHitVal: TLabel;
    lblCardNetTitle: TLabel;
    lblCardNetVal: TLabel;
    lblCardQPSTitle: TLabel;
    lblCardQPSVal: TLabel;
    lblConn: TLabel;
    lblInterval: TLabel;
    Panel1: TPanel;
    pnlCardConn: TPanel;
    pnlCardHit: TPanel;
    pnlCardNet: TPanel;
    pnlCardQPS: TPanel;
    pnlTop: TPanel;
    lblTitle: TLabel;
    lblSubtitle: TLabel;

    pnlControls: TPanel;

    pnlCards: TPanel;

    pnlCharts: TPanel;
    pnlRowTop: TPanel;
    pnlChartConn: TPanel;
    chartConnections: TChart;
    seriesConnections: TLineSeries;
    splColTop: TSplitter;
    pnlChartQPS: TPanel;
    chartQPS: TChart;
    seriesQPS: TLineSeries;

    splRow: TSplitter;

    pnlRowBottom: TPanel;
    pnlChartHit: TPanel;
    chartHitRatio: TChart;
    seriesHitRatio: TLineSeries;
    splColBottom: TSplitter;
    pnlChartNet: TPanel;
    chartNetwork: TChart;
    seriesNetIn: TLineSeries;
    seriesNetOut: TLineSeries;

    tmrPoll: TTimer;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnToggleMonitorClick(Sender: TObject);
    procedure cboConnectionsChange(Sender: TObject);
    procedure cboIntervalChange(Sender: TObject);
    procedure tmrPollTimer(Sender: TObject);
  private
    FConnections: TConnectionProfileList;
    FCollector: TServerMetricsCollector;
    FPointCounter: Integer;
    const MAX_POINTS = 30;

    procedure PopulateConnections;
    procedure StartMonitoring;
    procedure StopMonitoring;
    procedure UpdateSeriesData(ASeries: TLineSeries; const AVal: Double; const ALabel: string);
  public

    class procedure Execute(
      AOwner: TComponent;
      AConnections: TConnectionProfileList;
      const ASelectedProfile: TConnectionProfile = nil
    );

    class function EmbedToPanel(
      AOwner: TComponent;
      AParentPanel: TPanel;
      AConnections: TConnectionProfileList;
      const ASelectedProfile: TConnectionProfile
    ): TFormLiveMetrics;

  end;

implementation

{$R *.lfm}

{ TFormLiveMetrics }

class procedure TFormLiveMetrics.Execute(
  AOwner: TComponent;
  AConnections: TConnectionProfileList;
  const ASelectedProfile: TConnectionProfile
);
var
  Frm: TFormLiveMetrics;
  Idx: Integer;
begin
  Frm := TFormLiveMetrics.Create(AOwner);
  try
    Frm.FConnections := AConnections;
    Frm.PopulateConnections;

    if Assigned(ASelectedProfile) and Assigned(AConnections) then
    begin
      Idx := AConnections.IndexOf(ASelectedProfile);
      if Idx >= 0 then
        Frm.cboConnections.ItemIndex := Idx;
    end;

    Frm.ShowModal;
  finally
    Frm.Free;
  end;
end;

class function TFormLiveMetrics.EmbedToPanel(
  AOwner: TComponent;
  AParentPanel: TPanel;
  AConnections: TConnectionProfileList;
  const ASelectedProfile: TConnectionProfile
): TFormLiveMetrics;
var
  Idx: Integer;
begin
  // 1. Inisialisasi form tanpa border
  Result := TFormLiveMetrics.Create(AOwner);
  Result.BorderStyle := bsNone;
  Result.Parent := AParentPanel;
  Result.Align := alClient;

  // 2. Muat koneksi & konfigurasi profil (identik dengan Execute)
  Result.FConnections := AConnections;
  Result.PopulateConnections;

  if Assigned(ASelectedProfile) and Assigned(AConnections) then
  begin
    Idx := AConnections.IndexOf(ASelectedProfile);
    if Idx >= 0 then
    begin
      Result.cboConnections.ItemIndex := Idx;

      // 3. Picu event OnChange combobox agar timer & query metrik langsung mulai berjalan
      if Assigned(Result.cboConnections.OnChange) then
        Result.cboConnections.OnChange(Result.cboConnections);
    end;
  end;

  // 4. Tampilkan pada panel
  Result.Show;
end;


procedure TFormLiveMetrics.FormCreate(Sender: TObject);
begin
  FCollector := nil;
  FPointCounter := 0;
  tmrPoll.Enabled := False;
  tmrPoll.Interval := 1000;

  // Inisialisasi properti visual Series secara dinamis agar aman dari streaming error
  seriesConnections.LinePen.Color := $00D36B00;
  seriesConnections.LinePen.Width := 2;

  seriesQPS.LinePen.Color := clGreen;
  seriesQPS.LinePen.Width := 2;

  seriesHitRatio.LinePen.Color := $00AA00AA;
  seriesHitRatio.LinePen.Width := 2;

  seriesNetIn.Title := 'Inbound (KB/s)';
  seriesNetIn.LinePen.Color := clBlue;
  seriesNetIn.LinePen.Width := 2;

  seriesNetOut.Title := 'Outbound (KB/s)';
  seriesNetOut.LinePen.Color := clRed;
  seriesNetOut.LinePen.Width := 2;
end;

procedure TFormLiveMetrics.FormDestroy(Sender: TObject);
begin
  StopMonitoring;
end;

procedure TFormLiveMetrics.FormShow(Sender: TObject);
begin
  if cboConnections.Items.Count > 0 then
    StartMonitoring;
end;

procedure TFormLiveMetrics.PopulateConnections;
var
  I: Integer;
  Prof: TConnectionProfile;
begin
  cboConnections.Items.Clear;
  if not Assigned(FConnections) then Exit;

  for I := 0 to FConnections.Count - 1 do
  begin
    Prof := FConnections[I];
    cboConnections.Items.AddObject(Prof.ConnectionName + ' (' + Prof.GetDisplayName + ')', Prof);
  end;

  if cboConnections.Items.Count > 0 then
    cboConnections.ItemIndex := 0;
end;

procedure TFormLiveMetrics.StartMonitoring;
var
  Prof: TConnectionProfile;
begin
  StopMonitoring;
  if cboConnections.ItemIndex < 0 then Exit;

  Prof := TConnectionProfile(cboConnections.Items.Objects[cboConnections.ItemIndex]);
  FCollector := TServerMetricsCollector.Create(Prof);

  if not FCollector.Connect then
  begin
    MessageDlg('Koneksi Gagal', 'Tidak dapat terhubung ke server database untuk membaca metrik.', mtError, [mbOK], 0);
    FreeAndNil(FCollector);
    Exit;
  end;

  seriesConnections.Clear;
  seriesQPS.Clear;
  seriesHitRatio.Clear;
  seriesNetIn.Clear;
  seriesNetOut.Clear;
  FPointCounter := 0;

  tmrPoll.Enabled := True;
  btnToggleMonitor.Caption := '⏸️ Jeda Pemantauan';
end;

procedure TFormLiveMetrics.StopMonitoring;
begin
  tmrPoll.Enabled := False;
  if Assigned(FCollector) then
  begin
    FCollector.Disconnect;
    FreeAndNil(FCollector);
  end;
  btnToggleMonitor.Caption := '▶️ Mulai Pemantauan';
end;

procedure TFormLiveMetrics.btnToggleMonitorClick(Sender: TObject);
begin
  if tmrPoll.Enabled then
    StopMonitoring
  else
    StartMonitoring;
end;

procedure TFormLiveMetrics.cboConnectionsChange(Sender: TObject);
begin
  if tmrPoll.Enabled then
    StartMonitoring;
end;

procedure TFormLiveMetrics.cboIntervalChange(Sender: TObject);
begin
  case cboInterval.ItemIndex of
    0: tmrPoll.Interval := 1000;
    1: tmrPoll.Interval := 2000;
    2: tmrPoll.Interval := 5000;
    else tmrPoll.Interval := 1000;
  end;
end;

procedure TFormLiveMetrics.UpdateSeriesData(ASeries: TLineSeries; const AVal: Double; const ALabel: string);
begin
  ASeries.AddXY(FPointCounter, AVal, ALabel);
  while ASeries.Count > MAX_POINTS do
    ASeries.Delete(0);
end;

procedure TFormLiveMetrics.tmrPollTimer(Sender: TObject);
var
  Snap: TServerMetricSnapshot;
  TimeStr: string;
begin
  if not Assigned(FCollector) or not FCollector.PollMetrics(Snap) then Exit;

  Inc(FPointCounter);
  TimeStr := FormatDateTime('hh:nn:ss', Snap.Timestamp);

  // Update Status Cards
  lblCardConnVal.Caption := IntToStr(Snap.ActiveConnections);
  lblCardQPSVal.Caption := FormatFloat('0.0', Snap.QueriesPerSec);
  lblCardHitVal.Caption := FormatFloat('0.00', Snap.BufferHitRatio) + ' %';
  lblCardNetVal.Caption := FormatFloat('0.0', Snap.NetworkInKBps) + ' / ' + FormatFloat('0.0', Snap.NetworkOutKBps) + ' KB/s';

  // Update Series Data
  UpdateSeriesData(seriesConnections, Snap.ActiveConnections, TimeStr);
  UpdateSeriesData(seriesQPS, Snap.QueriesPerSec, TimeStr);
  UpdateSeriesData(seriesHitRatio, Snap.BufferHitRatio, TimeStr);
  UpdateSeriesData(seriesNetIn, Snap.NetworkInKBps, TimeStr);
  UpdateSeriesData(seriesNetOut, Snap.NetworkOutKBps, TimeStr);
end;

end.
