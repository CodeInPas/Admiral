unit uFrameWelcomeDashboard;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Buttons, ComCtrls,
  uAppConst, uAppTypes, uDBTypes, uModelConnection;

type
  { Event Handler }
  TQuickActionEvent = procedure(Sender: TObject) of object;
  TConnectProfileEvent = procedure(Sender: TObject; AProfile: TConnectionProfile) of object;

  { TFrameWelcomeDashboard }
  TFrameWelcomeDashboard = class(TFrame)
    sbMain: TScrollBox;
    pnlContainer: TPanel;

    // Header Hero / Identitas Aplikasi
    pnlHero: TPanel;
    lblAppTitle: TLabel;
    lblAppSubtitle: TLabel;
    lblVersionTag: TLabel;
    lblBuildTag: TLabel;

    // Baris 1: Informasi Sistem & Mesin DBMS
    pnlRow1: TPanel;
    pnlCardAppInfo: TPanel;
    lblTitleAppInfo: TLabel;
    lblInfoAppName: TLabel;
    lblInfoVersion: TLabel;
    lblInfoLazarusFPC: TLabel;
    lblInfoPlatform: TLabel;
    lblInfoAuthor: TLabel;

    pnlCardDBEngine: TPanel;
    lblTitleDBEngine: TLabel;
    lblDBMySQL: TLabel;
    lblDBPostgres: TLabel;
    lblDBSQLite: TLabel;
    lblDBFirebird: TLabel;
    lblDBStatus: TLabel;

    // Baris 2: Modul Utama & AI Intelligence
    pnlRow2: TPanel;
    pnlCardModules: TPanel;
    lblTitleModules: TLabel;
    lblModSQL: TLabel;
    lblModTableBuilder: TLabel;
    lblModSchemaDiff: TLabel;
    lblModLiveMetrics: TLabel;
    lblModDataTransfer: TLabel;

    pnlCardAI: TPanel;
    lblTitleAI: TLabel;
    lblAINL2SQL: TLabel;
    lblAIOptimizer: TLabel;
    lblAIDiagnostic: TLabel;
    lblAIRoutine: TLabel;
    lblAISafeMode: TLabel;


    procedure btnOpenNewQueryClick(Sender: TObject);
  private
    FConnections: TConnectionProfileList;
    FOnNewQuery: TQuickActionEvent;
    FOnNL2SQL: TQuickActionEvent;
    FOnBackupRestore: TQuickActionEvent;
    FOnLiveMetrics: TQuickActionEvent;
    FOnTableBuilder: TQuickActionEvent;
    FOnPHPCRUD: TQuickActionEvent;
    FOnRoutineGen: TQuickActionEvent;
    FOnSchemaDiff: TQuickActionEvent;
    FOnNewConnection: TQuickActionEvent;
    FOnConnectProfile: TConnectProfileEvent;

    procedure RefreshSystemSpecs;
  public
    constructor Create(AOwner: TComponent); override;
    procedure RefreshConnectionList(AConnections: TConnectionProfileList);

    property OnNewQuery: TQuickActionEvent read FOnNewQuery write FOnNewQuery;
    property OnNL2SQL: TQuickActionEvent read FOnNL2SQL write FOnNL2SQL;
    property OnBackupRestore: TQuickActionEvent read FOnBackupRestore write FOnBackupRestore;
    property OnLiveMetrics: TQuickActionEvent read FOnLiveMetrics write FOnLiveMetrics;
    property OnTableBuilder: TQuickActionEvent read FOnTableBuilder write FOnTableBuilder;
    property OnPHPCRUD: TQuickActionEvent read FOnPHPCRUD write FOnPHPCRUD;
    property OnRoutineGen: TQuickActionEvent read FOnRoutineGen write FOnRoutineGen;
    property OnSchemaDiff: TQuickActionEvent read FOnSchemaDiff write FOnSchemaDiff;
    property OnNewConnection: TQuickActionEvent read FOnNewConnection write FOnNewConnection;
    property OnConnectProfile: TConnectProfileEvent read FOnConnectProfile write FOnConnectProfile;
  end;

implementation

{$R *.lfm}

{ TFrameWelcomeDashboard }

constructor TFrameWelcomeDashboard.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FConnections := nil;
  RefreshSystemSpecs;
end;

procedure TFrameWelcomeDashboard.RefreshSystemSpecs;
begin
  //lblSysOS.Caption := '• Sistem Operasi : Windows (64-bit)';
 // lblSysTime.Caption := Format('• Waktu Sistem    : %s', [FormatDateTime('dddd, dd mmmm yyyy hh:nn:ss', Now)]);
 // lblVersionTag.Caption := 'v' + APP_VERSION + ' • Production Ready';
end;

procedure TFrameWelcomeDashboard.RefreshConnectionList(AConnections: TConnectionProfileList);
var
  CountVal: Integer;
begin
  FConnections := AConnections;
  if Assigned(FConnections) then
    CountVal := FConnections.Count
  else
    CountVal := 0;

 /// lblSysProfileCount.Caption := Format('• Profil Terdaftar : %d Koneksi Database', [CountVal]);
end;

procedure TFrameWelcomeDashboard.btnOpenNewQueryClick(Sender: TObject);
begin
  if Assigned(FOnNewQuery) then
    FOnNewQuery(Self);
end;

end.
