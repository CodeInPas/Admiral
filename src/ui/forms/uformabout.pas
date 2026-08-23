unit uFormAbout;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Buttons,
  uAppConst;

type
  { TFormAbout }
  TFormAbout = class(TForm)
    pnlHeader: TPanel;
    lblAppName: TLabel;
    lblAppSub: TLabel;
    lblVersion: TLabel;

    pnlBody: TPanel;
    lblDesc: TLabel;
    lblTechStack: TLabel;
    lblDrivers: TLabel;
    lblCopyright: TLabel;

    pnlBottom: TPanel;
    btnClose: TBitBtn;

    procedure btnCloseClick(Sender: TObject);
  public
    class procedure Execute(AOwner: TComponent);
  end;
var
  FormAbout: TFormAbout ;

implementation

{$R *.lfm}

{ TFormAbout }

class procedure TFormAbout.Execute(AOwner: TComponent);
var
  Dlg: TFormAbout;
begin
  Dlg := TFormAbout.Create(AOwner);
  try
    Dlg.ShowModal;
  finally
    Dlg.Free;
  end;
end;

procedure TFormAbout.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
