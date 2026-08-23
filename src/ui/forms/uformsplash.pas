unit uFormSplash;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  ComCtrls, StdCtrls,
  uAppConst;

type
  { TFormSplash }
  TFormSplash = class(TForm)
    pnlContainer: TPanel;
    lblTitle: TLabel;
    lblSubtitle: TLabel;
    lblVersion: TLabel;
    lblStatus: TLabel;
    ProgressBar: TProgressBar;
    TimerLoader: TTimer;

    procedure FormCreate(Sender: TObject);
    procedure TimerLoaderTimer(Sender: TObject);
  private
    FStep: Integer;
  public
    class function ExecuteSplash: TModalResult;
  end;

implementation

{$R *.lfm}

{ TFormSplash }

class function TFormSplash.ExecuteSplash: TModalResult;
var
  Splash: TFormSplash;
begin
  Splash := TFormSplash.Create(Application);
  try
    Result := Splash.ShowModal;
  finally
    Splash.Free;
  end;
end;

procedure TFormSplash.FormCreate(Sender: TObject);
begin
  FStep := 0;
  ProgressBar.Min := 0;
  ProgressBar.Max := 100;
  ProgressBar.Position := 0;
  lblVersion.Caption := 'Versi ' + APP_VERSION + ' (64-bit Native)';
  lblStatus.Caption := 'Memuat konfigurasi lokal & profil koneksi...';
  TimerLoader.Interval := 100;
  TimerLoader.Enabled := True;
end;

procedure TFormSplash.TimerLoaderTimer(Sender: TObject);
begin
  Inc(FStep, 10);
  if FStep > 100 then
    FStep := 100;

  ProgressBar.Position := FStep;

  if FStep < 30 then
    lblStatus.Caption := 'Memuat konfigurasi lokal & profil koneksi...'
  else if FStep < 60 then
    lblStatus.Caption := 'Inisialisasi driver DBMS (MySQL, PG, SQLite, Firebird)...'
  else if FStep < 90 then
    lblStatus.Caption := 'Memuat engine AI & modul generator REST API...'
  else if FStep < 100 then
    lblStatus.Caption := 'Mempersiapkan antarmuka utama workspace...'
  else
  begin
    // Selesai: Matikan timer dan tutup Splash Screen
    TimerLoader.Enabled := False;
    ModalResult := mrOk;
  end;
end;

end.
