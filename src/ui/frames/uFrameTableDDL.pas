unit uFrameTableDDL;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Buttons, Clipbrd, SynEdit, SynHighlighterSQL,
  uAppTypes, uDBTypes, uModelConnection, uDBDriverBase, uDBConnectionFactory;

type
  { TFrameTableDDL }
  TFrameTableDDL = class(TFrame)
    pnlToolbar: TPanel;
    btnCopy: TBitBtn;
    btnSave: TBitBtn;
    btnRefresh: TBitBtn;
    pnlStatus: TPanel;
    lblInfo: TLabel;
    synEditor: TSynEdit;
    synSQLSyn: TSynSQLSyn;
    saveDialog: TSaveDialog;
    procedure btnCopyClick(Sender: TObject);
    procedure btnRefreshClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
  private
    FProfile: TConnectionProfile;
    FDatabaseName: string;
    FSchemaName: string;
    FTableName: string;
    procedure UpdateInfoLabel;
    procedure SetStatus(const AText: string; const AIsError: Boolean = False);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure LoadDDL(AProfile: TConnectionProfile; const ADBName, ASchema, ATableName: string);
    procedure SetDDLText(const AText: string);
    procedure Clear;

    property CurrentDatabase: string read FDatabaseName;
    property CurrentSchema: string read FSchemaName;
    property CurrentTable: string read FTableName;
  end;

implementation

{$R *.lfm}

{ TFrameTableDDL }

constructor TFrameTableDDL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FProfile := TConnectionProfile.Create;
  FDatabaseName := '';
  FSchemaName := '';
  FTableName := '';
  synEditor.Highlighter := synSQLSyn;
  Clear;
end;

destructor TFrameTableDDL.Destroy;
begin
  FreeAndNil(FProfile);
  inherited Destroy;
end;

procedure TFrameTableDDL.Clear;
begin
  synEditor.Clear;
  lblInfo.Caption := 'No table or view selected.';
  lblInfo.Font.Color := clGray;
  btnCopy.Enabled := False;
  btnSave.Enabled := False;
  btnRefresh.Enabled := False;
end;

procedure TFrameTableDDL.SetStatus(const AText: string; const AIsError: Boolean);
begin
  lblInfo.Caption := AText;
  if AIsError then
    lblInfo.Font.Color := clRed
  else
    lblInfo.Font.Color := clWindowText;
end;

procedure TFrameTableDDL.UpdateInfoLabel;
var
  TargetText: string;
begin
  if FTableName = '' then
  begin
    Clear;
    Exit;
  end;

  TargetText := '';
  if FDatabaseName <> '' then
    TargetText := FDatabaseName + '.';
  if FSchemaName <> '' then
    TargetText := TargetText + FSchemaName + '.';
  TargetText := TargetText + FTableName;

  SetStatus(Format('DDL For: %s', [TargetText]));
  btnCopy.Enabled := (synEditor.Lines.Count > 0);
  btnSave.Enabled := (synEditor.Lines.Count > 0);
  btnRefresh.Enabled := True;
end;

procedure TFrameTableDDL.SetDDLText(const AText: string);
begin
  synEditor.Lines.Text := AText;
  UpdateInfoLabel;
end;

procedure TFrameTableDDL.LoadDDL(AProfile: TConnectionProfile; const ADBName, ASchema, ATableName: string);
var
  Driver: TDBDriverBase;
  GeneratedDDL: string;
begin
  if not Assigned(AProfile) or (ATableName = '') then
  begin
    Clear;
    Exit;
  end;

  FProfile.Assign(AProfile);
  FDatabaseName := ADBName;
  FSchemaName := ASchema;
  FTableName := ATableName;

  Screen.Cursor := crHourGlass;
  SetStatus('Fetching schema structure and generating DDL..');
  Application.ProcessMessages;

  Driver := nil;
  try
    try
      Driver := TDBConnectionFactory.CreateDriver(FProfile);

      // 1. Coba ambil definisi VIEW terlebih dahulu
      GeneratedDDL := Driver.GetViewDDL(FDatabaseName, FSchemaName, FTableName);

      // 2. Jika bukan View atau kosong, ambil DDL Tabel fisik biasa
      if Trim(GeneratedDDL) = '' then
        GeneratedDDL := Driver.GetTableDDL(FDatabaseName, FSchemaName, FTableName);

      if Trim(GeneratedDDL) = '' then
        GeneratedDDL := Format('-- DDL cannot be generated or the object "%s" not found.', [FTableName]);

      synEditor.Lines.Text := GeneratedDDL;
      UpdateInfoLabel;
    except
      on E: Exception do
      begin
        synEditor.Lines.Text := Format('-- failed to extract DDL:%s-- %s', [LineEnding, E.Message]);
        SetStatus(Format('Fail: %s', [E.Message]), True);
      end;
    end;
  finally
    if Assigned(Driver) then
      Driver.Free;
    Screen.Cursor := crDefault;
  end;
end;

procedure TFrameTableDDL.btnCopyClick(Sender: TObject);
begin
  if synEditor.Lines.Count > 0 then
  begin
    Clipboard.AsText := synEditor.Lines.Text;
    SetStatus('DDL successfully copied to the clipboard.');
  end;
end;

procedure TFrameTableDDL.btnRefreshClick(Sender: TObject);
begin
  if (FTableName <> '') and (FProfile.ConnectionName <> '') then
    LoadDDL(FProfile, FDatabaseName, FSchemaName, FTableName);
end;

procedure TFrameTableDDL.btnSaveClick(Sender: TObject);
begin
  if synEditor.Lines.Count = 0 then Exit;

  saveDialog.FileName := Format('%s_schema.sql', [FTableName]);
  if saveDialog.Execute then
  begin
    try
      synEditor.Lines.SaveToFile(saveDialog.FileName);
      SetStatus(Format('DDL Saved to: %s', [ExtractFileName(saveDialog.FileName)]));
    except
      on E: Exception do
        SetStatus(Format('Failed save file: %s', [E.Message]), True);
    end;
  end;
end;

end.
