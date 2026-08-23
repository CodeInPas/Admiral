unit uFormServerVariables;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  ComCtrls, StdCtrls, Buttons, Clipbrd,
  uAppTypes, uDBTypes, uModelConnection, uDBServerVariablesService;

type
  { TFormServerVariables }
  TFormServerVariables = class(TForm)
    pnlToolbar: TPanel;
    btnRefresh: TSpeedButton;
    btnCopyValue: TSpeedButton;
    btnCopyName: TSpeedButton;
    btnExport: TSpeedButton;
    sepTool1: TBevel;
    sepTool2: TBevel;

    lblMode: TLabel;
    cboMode: TComboBox;
    lblSearch: TLabel;
    edtSearch: TEdit;

    pnlStatus: TPanel;
    lblTotalCount: TLabel;
    lblSelectedInfo: TLabel;

    lvVariables: TListView;
    saveDialog: TSaveDialog;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);

    procedure btnRefreshClick(Sender: TObject);
    procedure btnCopyValueClick(Sender: TObject);
    procedure btnCopyNameClick(Sender: TObject);
    procedure btnExportClick(Sender: TObject);
    procedure cboModeChange(Sender: TObject);
    procedure edtSearchChange(Sender: TObject);
    procedure lvVariablesSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
  private
    FProfile: TConnectionProfile;
    FVariableList: TList;
    FSelectedVariable: TDBServerVariable;

    procedure ClearVariableList;
    procedure ReloadVariables;
    procedure PopulateListView;
  public
    class procedure Execute(AOwner: TComponent; AProfile: TConnectionProfile);
    property Profile: TConnectionProfile read FProfile write FProfile;
  end;

implementation

{$R *.lfm}

{ TFormServerVariables }

class procedure TFormServerVariables.Execute(AOwner: TComponent; AProfile: TConnectionProfile);
var
  Frm: TFormServerVariables;
begin
  Frm := TFormServerVariables.Create(AOwner);
  try
    Frm.Profile := AProfile;
    Frm.ShowModal;
  finally
    Frm.Free;
  end;
end;

procedure TFormServerVariables.FormCreate(Sender: TObject);
begin
  FVariableList := TList.Create;
  FSelectedVariable := nil;
end;

procedure TFormServerVariables.FormDestroy(Sender: TObject);
begin
  ClearVariableList;
  FVariableList.Free;
end;

procedure TFormServerVariables.FormShow(Sender: TObject);
begin
  if Assigned(FProfile) then
  begin
    Caption := Format('Server Variables & Status - %s (%s)', [FProfile.ConnectionName, FProfile.GetDisplayName]);

    if FProfile.DriverType in [dtMySQL, dtMariaDB] then
    begin
      cboMode.Visible := True;
      lblMode.Visible := True;
    end
    else
    begin
      cboMode.Visible := False;
      lblMode.Visible := False;
    end;

    ReloadVariables;
  end;
end;

procedure TFormServerVariables.ClearVariableList;
var
  I: Integer;
begin
  for I := 0 to FVariableList.Count - 1 do
    TDBServerVariable(FVariableList[I]).Free;
  FVariableList.Clear;
  FSelectedVariable := nil;
end;

procedure TFormServerVariables.ReloadVariables;
var
  Err: string;
  IsStatus: Boolean;
begin
  ClearVariableList;
  IsStatus := (cboMode.ItemIndex = 1);

  Screen.Cursor := crHourGlass;
  try
    if not TDBServerVariablesService.FetchVariables(FProfile, IsStatus, FVariableList, Err) then
    begin
      MessageDlg('Perhatian', Err, mtWarning, [mbOK], 0);
      Exit;
    end;

    PopulateListView;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFormServerVariables.PopulateListView;
var
  I: Integer;
  VInfo: TDBServerVariable;
  Item: TListItem;
  FilterText: string;
  Matched: Boolean;
begin
  FilterText := LowerCase(Trim(edtSearch.Text));
  lvVariables.Items.BeginUpdate;
  try
    lvVariables.Items.Clear;
    for I := 0 to FVariableList.Count - 1 do
    begin
      VInfo := TDBServerVariable(FVariableList[I]);

      Matched := True;
      if FilterText <> '' then
      begin
        Matched := (Pos(FilterText, LowerCase(VInfo.Name)) > 0) or
                   (Pos(FilterText, LowerCase(VInfo.Value)) > 0) or
                   (Pos(FilterText, LowerCase(VInfo.Category)) > 0) or
                   (Pos(FilterText, LowerCase(VInfo.Description)) > 0);
      end;

      if Matched then
      begin
        Item := lvVariables.Items.Add;
        Item.Caption := VInfo.Name;
        Item.SubItems.Add(VInfo.Value);
        Item.SubItems.Add(VInfo.UnitType);
        Item.SubItems.Add(VInfo.Category);
        Item.SubItems.Add(VInfo.Description);
        Item.Data := VInfo;
      end;
    end;
  finally
    lvVariables.Items.EndUpdate;
  end;

  lblTotalCount.Caption := Format('Total Variabel: %d (Ditampilkan: %d)', [FVariableList.Count, lvVariables.Items.Count]);
end;

procedure TFormServerVariables.lvVariablesSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  if Selected and Assigned(Item) and Assigned(Item.Data) then
  begin
    FSelectedVariable := TDBServerVariable(Item.Data);
    lblSelectedInfo.Caption := Format('%s = %s', [FSelectedVariable.Name, FSelectedVariable.Value]);
  end
  else
  begin
    FSelectedVariable := nil;
    lblSelectedInfo.Caption := '-';
  end;
end;

procedure TFormServerVariables.btnRefreshClick(Sender: TObject);
begin
  ReloadVariables;
end;

procedure TFormServerVariables.btnCopyValueClick(Sender: TObject);
begin
  if Assigned(FSelectedVariable) then
    Clipboard.AsText := FSelectedVariable.Value;
end;

procedure TFormServerVariables.btnCopyNameClick(Sender: TObject);
begin
  if Assigned(FSelectedVariable) then
    Clipboard.AsText := FSelectedVariable.Name;
end;

procedure TFormServerVariables.btnExportClick(Sender: TObject);
var
  SL: TStringList;
  I: Integer;
  VInfo: TDBServerVariable;
begin
  if FVariableList.Count = 0 then Exit;

  saveDialog.DefaultExt := '.csv';
  saveDialog.Filter := 'CSV Files (*.csv)|*.csv|Text Files (*.txt)|*.txt|All Files (*.*)|*.*';
  saveDialog.FileName := Format('variables_%s.csv', [FormatDateTime('yyyymmdd_hhnnss', Now)]);

  if saveDialog.Execute then
  begin
    SL := TStringList.Create;
    try
      SL.Add('Name,Value,Unit,Category,Description');
      for I := 0 to FVariableList.Count - 1 do
      begin
        VInfo := TDBServerVariable(FVariableList[I]);
        SL.Add(Format('"%s","%s","%s","%s","%s"', [
          StringReplace(VInfo.Name, '"', '""', [rfReplaceAll]),
          StringReplace(VInfo.Value, '"', '""', [rfReplaceAll]),
          StringReplace(VInfo.UnitType, '"', '""', [rfReplaceAll]),
          StringReplace(VInfo.Category, '"', '""', [rfReplaceAll]),
          StringReplace(VInfo.Description, '"', '""', [rfReplaceAll])
        ]));
      end;
      SL.SaveToFile(saveDialog.FileName);
      MessageDlg('Sukses', 'Data variabel berhasil disimpan ke berkas.', mtInformation, [mbOK], 0);
    finally
      SL.Free;
    end;
  end;
end;

procedure TFormServerVariables.cboModeChange(Sender: TObject);
begin
  ReloadVariables;
end;

procedure TFormServerVariables.edtSearchChange(Sender: TObject);
begin
  PopulateListView;
end;

end.
