unit uFormSchemaDiff;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  ComCtrls, StdCtrls, Buttons, Grids, Clipbrd,
  SynEdit, SynHighlighterSQL,
  ZConnection,
  uAppTypes, uDBTypes, uModelConnection, uSchemaDiffEngine;

type
  { TFormSchemaDiff }
  TFormSchemaDiff = class(TForm)
    pnlTop: TPanel;
    lblSourceDB: TLabel;
    cboSourceDB: TComboBox;
    lblTargetDB: TLabel;
    cboTargetDB: TComboBox;
    btnCompare: TBitBtn;

    pnlMain: TPanel;
    pnlLeftDiff: TPanel;
    splMain: TSplitter;
    pnlRightScript: TPanel;

    // Header Kiri
    pnlDiffHeader: TPanel;
    lblDiffSummary: TLabel;
    btnSelectAll: TSpeedButton;
    btnClearAll: TSpeedButton;
    gridDiff: TStringGrid;

    // Header Kanan
    pnlScriptHeader: TPanel;
    lblScriptTitle: TLabel;
    btnCopyScript: TSpeedButton;
    btnSaveScript: TSpeedButton;
    btnExecuteSync: TBitBtn;
    synSyncScript: TSynEdit;
    synSQLSyn: TSynSQLSyn;

    saveDialog: TSaveDialog;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);

    procedure btnCompareClick(Sender: TObject);
    procedure btnSelectAllClick(Sender: TObject);
    procedure btnClearAllClick(Sender: TObject);
    procedure gridDiffCheckboxToggled(Sender: TObject; aCol, aRow: Integer; aState: TCheckboxState);
    procedure gridDiffDrawCell(Sender: TObject; aCol, aRow: Integer; aRect: TRect; aState: TGridDrawState);

    procedure btnCopyScriptClick(Sender: TObject);
    procedure btnSaveScriptClick(Sender: TObject);
    procedure btnExecuteSyncClick(Sender: TObject);
  private
    FProfilesList: TConnectionProfileList; // Menggunakan TConnectionProfileList
    FDiffList: TList;                     // List of TSchemaDiffItem
    FSourceProfile: TConnectionProfile;
    FTargetProfile: TConnectionProfile;

    procedure PopulateProfileCombos;
    procedure DisplayDiffResults;
    procedure RefreshSyncScript;
  public
    class procedure Execute(AOwner: TComponent; AProfiles: TConnectionProfileList; const ADefaultSource: TConnectionProfile = nil);
    property ProfilesList: TConnectionProfileList read FProfilesList write FProfilesList;
  end;

implementation

{$R *.lfm}

{ TFormSchemaDiff }

class procedure TFormSchemaDiff.Execute(AOwner: TComponent; AProfiles: TConnectionProfileList; const ADefaultSource: TConnectionProfile);
var
  Frm: TFormSchemaDiff;
begin
  Frm := TFormSchemaDiff.Create(AOwner);
  try
    Frm.ProfilesList := AProfiles;
    Frm.FSourceProfile := ADefaultSource;
    Frm.ShowModal;
  finally
    Frm.Free;
  end;
end;

procedure TFormSchemaDiff.FormCreate(Sender: TObject);
begin
  FProfilesList := nil;
  FDiffList := TList.Create;
  FSourceProfile := nil;
  FTargetProfile := nil;

  synSyncScript.Highlighter := synSQLSyn;

  gridDiff.ColCount := 5;
  gridDiff.RowCount := 1;
  gridDiff.Cells[0, 0] := 'Pilih';
  gridDiff.Cells[1, 0] := 'Aksi';
  gridDiff.Cells[2, 0] := 'Tipe Objek';
  gridDiff.Cells[3, 0] := 'Nama Objek';
  gridDiff.Cells[4, 0] := 'Rincian Perbedaan';

  gridDiff.ColWidths[0] := 50;
  gridDiff.ColWidths[1] := 80;
  gridDiff.ColWidths[2] := 90;
  gridDiff.ColWidths[3] := 150;
  gridDiff.ColWidths[4] := 250;
end;

procedure TFormSchemaDiff.FormDestroy(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to FDiffList.Count - 1 do
    TSchemaDiffItem(FDiffList[I]).Free;
  FDiffList.Free;
  //inherited Destroy;
end;

procedure TFormSchemaDiff.FormShow(Sender: TObject);
begin
  PopulateProfileCombos;
end;

procedure TFormSchemaDiff.PopulateProfileCombos;
var
  I: Integer;
  Prof: TConnectionProfile;
begin
  cboSourceDB.Items.Clear;
  cboTargetDB.Items.Clear;

  if not Assigned(FProfilesList) then Exit;

  for I := 0 to FProfilesList.Count - 1 do
  begin
    Prof := FProfilesList[I];
    cboSourceDB.Items.AddObject(Prof.ConnectionName + ' (' + Prof.GetDisplayName + ')', Prof);
    cboTargetDB.Items.AddObject(Prof.ConnectionName + ' (' + Prof.GetDisplayName + ')', Prof);
  end;

  if cboSourceDB.Items.Count > 0 then
  begin
    if Assigned(FSourceProfile) then
      cboSourceDB.ItemIndex := FProfilesList.IndexOf(FSourceProfile)
    else
      cboSourceDB.ItemIndex := 0;

    if cboSourceDB.Items.Count > 1 then
      cboTargetDB.ItemIndex := 1
    else
      cboTargetDB.ItemIndex := 0;
  end;
end;

procedure TFormSchemaDiff.btnCompareClick(Sender: TObject);
var
  Err: string;
begin
  if (cboSourceDB.ItemIndex < 0) or (cboTargetDB.ItemIndex < 0) then
  begin
    MessageDlg('Peringatan', 'Pilih koneksi database Sumber dan Target.', mtWarning, [mbOK], 0);
    Exit;
  end;

  if cboSourceDB.ItemIndex = cboTargetDB.ItemIndex then
  begin
    MessageDlg('Peringatan', 'Pilih dua koneksi database yang berbeda untuk dibandingkan.', mtWarning, [mbOK], 0);
    Exit;
  end;

  FSourceProfile := TConnectionProfile(cboSourceDB.Items.Objects[cboSourceDB.ItemIndex]);
  FTargetProfile := TConnectionProfile(cboTargetDB.Items.Objects[cboTargetDB.ItemIndex]);

  Screen.Cursor := crHourGlass;
  try
    if TSchemaDiffEngine.CompareSchemas(FSourceProfile, FTargetProfile, FDiffList, Err) then
    begin
      DisplayDiffResults;
      RefreshSyncScript;
    end
    else
      MessageDlg('Gagal Komparasi Skema', Err, mtError, [mbOK], 0);
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFormSchemaDiff.DisplayDiffResults;
var
  I, RowIdx: Integer;
  Item: TSchemaDiffItem;
  ActStr, TypeStr: string;
begin
  gridDiff.RowCount := 1;

  for I := 0 to FDiffList.Count - 1 do
  begin
    Item := TSchemaDiffItem(FDiffList[I]);
    gridDiff.RowCount := gridDiff.RowCount + 1;
    RowIdx := gridDiff.RowCount - 1;

    case Item.Action of
      daCreate: ActStr := '+ Tambah';
      daDrop:   ActStr := '- Hapus';
      daAlter:  ActStr := '~ Ubah';
      else      ActStr := 'Identik';
    end;

    case Item.ObjType of
      dotTable: TypeStr := 'Tabel';
      dotColumn: TypeStr := 'Kolom';
      dotIndex: TypeStr := 'Indeks';
      dotForeignKey: TypeStr := 'Foreign Key';
    end;

    gridDiff.Cells[0, RowIdx] := '1';
    gridDiff.Cells[1, RowIdx] := ActStr;
    gridDiff.Cells[2, RowIdx] := TypeStr;
    gridDiff.Cells[3, RowIdx] := Item.ParentTableName + '.' + Item.ObjectName;
    gridDiff.Cells[4, RowIdx] := Item.Details;
  end;

  lblDiffSummary.Caption := Format('Hasil Perbedaan: %d perubahan terdeteksi', [FDiffList.Count]);
end;

procedure TFormSchemaDiff.RefreshSyncScript;
begin
  if Assigned(FTargetProfile) then
    synSyncScript.Lines.Text := TSchemaDiffEngine.GenerateSyncScript(FDiffList, FTargetProfile.DriverType)
  else
    synSyncScript.Lines.Text := TSchemaDiffEngine.GenerateSyncScript(FDiffList, dtSQLite);
end;

procedure TFormSchemaDiff.gridDiffCheckboxToggled(Sender: TObject; aCol, aRow: Integer; aState: TCheckboxState);
var
  ItemIdx: Integer;
begin
  ItemIdx := aRow - 1;
  if (ItemIdx >= 0) and (ItemIdx < FDiffList.Count) then
  begin
    TSchemaDiffItem(FDiffList[ItemIdx]).IsSelected := (aState = cbChecked);
    RefreshSyncScript;
  end;
end;

procedure TFormSchemaDiff.gridDiffDrawCell(Sender: TObject; aCol, aRow: Integer; aRect: TRect; aState: TGridDrawState);
var
  ActStr: string;
begin
  if (aRow >= 1) and not (gdSelected in aState) then
  begin
    ActStr := gridDiff.Cells[1, aRow];
    if Pos('Tambah', ActStr) > 0 then
      gridDiff.Canvas.Brush.Color := $00E6FFE6
    else if Pos('Hapus', ActStr) > 0 then
      gridDiff.Canvas.Brush.Color := $00E6E6FF
    else if Pos('Ubah', ActStr) > 0 then
      gridDiff.Canvas.Brush.Color := $00FFF4E6;

    gridDiff.Canvas.FillRect(aRect);
    gridDiff.Canvas.TextOut(aRect.Left + 2, aRect.Top + 2, gridDiff.Cells[aCol, aRow]);
  end;
end;

procedure TFormSchemaDiff.btnSelectAllClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to FDiffList.Count - 1 do
    TSchemaDiffItem(FDiffList[I]).IsSelected := True;
  for I := 1 to gridDiff.RowCount - 1 do
    gridDiff.Cells[0, I] := '1';
  RefreshSyncScript;
end;

procedure TFormSchemaDiff.btnClearAllClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to FDiffList.Count - 1 do
    TSchemaDiffItem(FDiffList[I]).IsSelected := False;
  for I := 1 to gridDiff.RowCount - 1 do
    gridDiff.Cells[0, I] := '0';
  RefreshSyncScript;
end;

procedure TFormSchemaDiff.btnCopyScriptClick(Sender: TObject);
begin
  Clipboard.AsText := synSyncScript.Lines.Text;
  MessageDlg('Schema Diff', 'Skrip sinkronisasi DDL berhasil disalin ke Clipboard.', mtInformation, [mbOK], 0);
end;

procedure TFormSchemaDiff.btnSaveScriptClick(Sender: TObject);
var
  SL: TStringList;
begin
  saveDialog.DefaultExt := '.sql';
  saveDialog.Filter := 'SQL Migration Script (*.sql)|*.sql|All Files (*.*)|*.*';
  saveDialog.FileName := Format('schema_sync_%s.sql', [FormatDateTime('YYYYMMDD_HHNNSS', Now)]);

  if saveDialog.Execute then
  begin
    SL := TStringList.Create;
    try
      SL.Text := synSyncScript.Lines.Text;
      SL.SaveToFile(saveDialog.FileName);
      MessageDlg('Skrip Tersimpan', Format('Skrip migrasi berhasil disimpan ke:%s%s', [LineEnding, saveDialog.FileName]), mtInformation, [mbOK], 0);
    finally
      SL.Free;
    end;
  end;
end;

procedure TFormSchemaDiff.btnExecuteSyncClick(Sender: TObject);
var
  Conn: TZConnection;
  I: Integer;
  Item: TSchemaDiffItem;
  ExecutedCount: Integer;
begin
  if not Assigned(FTargetProfile) or (FDiffList.Count = 0) then Exit;

  if MessageDlg('Konfirmasi Sinkronisasi Skema',
    Format('Eksekusi skrip perubahan DDL langsung ke target database "%s"?%sTindakan ini akan mengubah struktur database target.', [
      FTargetProfile.ConnectionName, LineEnding
    ]), mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;

  Screen.Cursor := crHourGlass;
  Conn := TZConnection.Create(nil);
  try
    try
      case FTargetProfile.DriverType of
        dtMySQL: Conn.Protocol := 'mysql';
        dtMariaDB: Conn.Protocol := 'mariadb';
        dtPostgreSQL: Conn.Protocol := 'postgresql';
        dtFirebird: Conn.Protocol := 'firebird';
        dtSQLite: Conn.Protocol := 'sqlite';
      end;
      Conn.HostName := FTargetProfile.Host;
      Conn.Port := FTargetProfile.Port;
      Conn.Database := FTargetProfile.DatabaseName;
      Conn.User := FTargetProfile.Username;
      Conn.Password := FTargetProfile.Password;
      Conn.AutoCommit := True;
      Conn.Connect;

      ExecutedCount := 0;
      for I := 0 to FDiffList.Count - 1 do
      begin
        Item := TSchemaDiffItem(FDiffList[I]);
        if Item.IsSelected and (Trim(Item.SyncSQL) <> '') then
        begin
          Conn.ExecuteDirect(Item.SyncSQL);
          Inc(ExecutedCount);
        end;
      end;

      MessageDlg('Sinkronisasi Sukses', Format('%d perintah DDL berhasil dieksekusi ke database target.', [ExecutedCount]), mtInformation, [mbOK], 0);
      btnCompareClick(Sender);
    except
      on E: Exception do
        MessageDlg('Gagal Sinkronisasi', E.Message, mtError, [mbOK], 0);
    end;
  finally
    Conn.Free;
    Screen.Cursor := crDefault;
  end;
end;

end.
