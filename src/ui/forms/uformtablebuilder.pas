unit uFormTableBuilder;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  ComCtrls, StdCtrls, Buttons, Grids, Clipbrd,
  SynEdit, SynHighlighterSQL,
  ZConnection,
  uAppTypes, uDBTypes, uModelConnection, uDBDriverBase, uDBConnectionFactory,
  uModelSchemaObject, uModelTableBuilder, uSQLLoggerService;

type
  { TFormTableBuilder }
  TFormTableBuilder = class(TForm)
    pnlTop: TPanel;
    lblTableName: TLabel;
    edtTableName: TEdit;
    lblSchema: TLabel;
    edtSchema: TEdit;
    lblEngine: TLabel;
    cboEngine: TComboBox;
    lblCharset: TLabel;
    cboCharset: TComboBox;

    pgcMain: TPageControl;
    tabColumns: TTabSheet;
    tabIndexes: TTabSheet;
    tabForeignKeys: TTabSheet;
    tabDDLPreview: TTabSheet;

    // Tab Kolom
    pnlColToolbar: TPanel;
    btnAddCol: TSpeedButton;
    btnDelCol: TSpeedButton;
    btnMoveUpCol: TSpeedButton;
    btnMoveDownCol: TSpeedButton;
    gridColumns: TStringGrid;

    // Tab Indeks
    pnlIdxToolbar: TPanel;
    btnAddIdx: TSpeedButton;
    btnDelIdx: TSpeedButton;
    gridIndexes: TStringGrid;

    // Tab Foreign Key
    pnlFKToolbar: TPanel;
    btnAddFK: TSpeedButton;
    btnDelFK: TSpeedButton;
    gridFKs: TStringGrid;

    // Tab DDL Preview
    synDDLPreview: TSynEdit;
    synSQLSyn: TSynSQLSyn;

    // Footer
    pnlBottom: TPanel;
    btnCopyDDL: TSpeedButton;
    btnExecuteDDL: TBitBtn;
    btnClose: TBitBtn;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);

    procedure edtTableNameChange(Sender: TObject);
    procedure edtSchemaChange(Sender: TObject);
    procedure cboEngineChange(Sender: TObject);
    procedure cboCharsetChange(Sender: TObject);

    // Event Kolom & In-Grid ComboBox
    procedure btnAddColClick(Sender: TObject);
    procedure btnDelColClick(Sender: TObject);
    procedure btnMoveUpColClick(Sender: TObject);
    procedure btnMoveDownColClick(Sender: TObject);
    procedure gridColumnsEditingDone(Sender: TObject);
    procedure gridColumnsSelectEditor(Sender: TObject; aCol, aRow: Integer; var Editor: TWinControl);

    // Event Indeks & FK
    procedure btnAddIdxClick(Sender: TObject);
    procedure btnDelIdxClick(Sender: TObject);
    procedure gridIndexesEditingDone(Sender: TObject);

    procedure btnAddFKClick(Sender: TObject);
    procedure btnDelFKClick(Sender: TObject);
    procedure gridFKsEditingDone(Sender: TObject);

    procedure pgcMainChange(Sender: TObject);
    procedure btnCopyDDLClick(Sender: TObject);
    procedure btnExecuteDDLClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
  private
    FProfile: TConnectionProfile;
    FModel: TTableBuilderModel;
    FGeneratedDDL: string;
    FExistingTableName: string;
    FIsEditMode: Boolean;
    FDataTypesList: TStringList;

    procedure PopulateDataTypesList;
    procedure SyncModelFromUI;
    procedure UpdateDDLPreview;
    procedure LoadExistingTable(const ATableName: string; const ASchema: string);
  public
    class procedure Execute(
      AOwner: TComponent;
      AProfile: TConnectionProfile;
      const ATableName: string = '';
      const ADefaultSchema: string = ''
    );
    property Profile: TConnectionProfile read FProfile write FProfile;
  end;

implementation

{$R *.lfm}

{ TFormTableBuilder }

class procedure TFormTableBuilder.Execute(
  AOwner: TComponent;
  AProfile: TConnectionProfile;
  const ATableName: string;
  const ADefaultSchema: string
);
var
  Frm: TFormTableBuilder;
begin
  Frm := TFormTableBuilder.Create(AOwner);
  try
    Frm.Profile := AProfile;
    Frm.FExistingTableName := Trim(ATableName);
    Frm.FIsEditMode := (Frm.FExistingTableName <> '');

    if ADefaultSchema <> '' then
      Frm.edtSchema.Text := ADefaultSchema;

    Frm.ShowModal;
  finally
    Frm.Free;
  end;
end;

procedure TFormTableBuilder.FormCreate(Sender: TObject);
begin
  FModel := TTableBuilderModel.Create;
  FDataTypesList := TStringList.Create;
  FGeneratedDDL := '';
  FExistingTableName := '';
  FIsEditMode := False;
  synDDLPreview.Highlighter := synSQLSyn;

  // Grid Kolom Setup
  gridColumns.ColCount := 8;
  gridColumns.RowCount := 1;
  gridColumns.Cells[0, 0] := 'Nama Kolom';
  gridColumns.Cells[1, 0] := 'Tipe Data';
  gridColumns.Cells[2, 0] := 'Panjang/Presisi';
  gridColumns.Cells[3, 0] := 'PK? (1/0)';
  gridColumns.Cells[4, 0] := 'AutoInc? (1/0)';
  gridColumns.Cells[5, 0] := 'Allow NULL? (1/0)';
  gridColumns.Cells[6, 0] := 'Unique? (1/0)';
  gridColumns.Cells[7, 0] := 'Default Value';

  gridColumns.ColWidths[0] := 150;
  gridColumns.ColWidths[1] := 140;
  gridColumns.ColWidths[2] := 100;
  gridColumns.ColWidths[3] := 60;
  gridColumns.ColWidths[4] := 75;
  gridColumns.ColWidths[5] := 90;
  gridColumns.ColWidths[6] := 70;
  gridColumns.ColWidths[7] := 110;

  // Pasang Handler In-Place Editor Dropdown ComboBox
  gridColumns.OnSelectEditor := @gridColumnsSelectEditor;

  // Grid Indeks Setup
  gridIndexes.ColCount := 3;
  gridIndexes.RowCount := 1;
  gridIndexes.Cells[0, 0] := 'Nama Indeks';
  gridIndexes.Cells[1, 0] := 'Tipe (INDEX/UNIQUE)';
  gridIndexes.Cells[2, 0] := 'Daftar Kolom (koma)';
  gridIndexes.ColWidths[0] := 180;
  gridIndexes.ColWidths[1] := 140;
  gridIndexes.ColWidths[2] := 350;

  // Grid FK Setup
  gridFKs.ColCount := 6;
  gridFKs.RowCount := 1;
  gridFKs.Cells[0, 0] := 'Nama FK';
  gridFKs.Cells[1, 0] := 'Kolom Lokal';
  gridFKs.Cells[2, 0] := 'Tabel Ref';
  gridFKs.Cells[3, 0] := 'Kolom Ref';
  gridFKs.Cells[4, 0] := 'ON UPDATE';
  gridFKs.Cells[5, 0] := 'ON DELETE';
  gridFKs.ColWidths[0] := 140;
  gridFKs.ColWidths[1] := 120;
  gridFKs.ColWidths[2] := 140;
  gridFKs.ColWidths[3] := 120;
  gridFKs.ColWidths[4] := 100;
  gridFKs.ColWidths[5] := 100;
end;

procedure TFormTableBuilder.FormDestroy(Sender: TObject);
begin
  FDataTypesList.Free;
  FModel.Free;
end;

procedure TFormTableBuilder.PopulateDataTypesList;
begin
  FDataTypesList.Clear;
  if not Assigned(FProfile) then
  begin
    FDataTypesList.CommaText := 'INTEGER,TEXT,REAL,BLOB,NUMERIC,VARCHAR';
    Exit;
  end;

  case FProfile.DriverType of
    dtSQLite:
    begin
      FDataTypesList.Add('INTEGER');
      FDataTypesList.Add('TEXT');
      FDataTypesList.Add('REAL');
      FDataTypesList.Add('BLOB');
      FDataTypesList.Add('NUMERIC');
      FDataTypesList.Add('VARCHAR');
      FDataTypesList.Add('BOOLEAN');
      FDataTypesList.Add('DATETIME');
    end;

    dtMySQL, dtMariaDB:
    begin
      FDataTypesList.Add('INT');
      FDataTypesList.Add('BIGINT');
      FDataTypesList.Add('TINYINT');
      FDataTypesList.Add('SMALLINT');
      FDataTypesList.Add('VARCHAR');
      FDataTypesList.Add('CHAR');
      FDataTypesList.Add('TEXT');
      FDataTypesList.Add('MEDIUMTEXT');
      FDataTypesList.Add('LONGTEXT');
      FDataTypesList.Add('DECIMAL');
      FDataTypesList.Add('FLOAT');
      FDataTypesList.Add('DOUBLE');
      FDataTypesList.Add('BOOLEAN');
      FDataTypesList.Add('DATE');
      FDataTypesList.Add('DATETIME');
      FDataTypesList.Add('TIMESTAMP');
      FDataTypesList.Add('TIME');
      FDataTypesList.Add('JSON');
      FDataTypesList.Add('BLOB');
      FDataTypesList.Add('LONGBLOB');
    end;

    dtPostgreSQL:
    begin
      FDataTypesList.Add('INTEGER');
      FDataTypesList.Add('BIGINT');
      FDataTypesList.Add('SMALLINT');
      FDataTypesList.Add('SERIAL');
      FDataTypesList.Add('BIGSERIAL');
      FDataTypesList.Add('VARCHAR');
      FDataTypesList.Add('CHAR');
      FDataTypesList.Add('TEXT');
      FDataTypesList.Add('NUMERIC');
      FDataTypesList.Add('REAL');
      FDataTypesList.Add('DOUBLE PRECISION');
      FDataTypesList.Add('BOOLEAN');
      FDataTypesList.Add('DATE');
      FDataTypesList.Add('TIMESTAMP');
      FDataTypesList.Add('TIMESTAMPTZ');
      FDataTypesList.Add('TIME');
      FDataTypesList.Add('JSON');
      FDataTypesList.Add('JSONB');
      FDataTypesList.Add('BYTEA');
      FDataTypesList.Add('UUID');
    end;

    dtFirebird:
    begin
      FDataTypesList.Add('INTEGER');
      FDataTypesList.Add('BIGINT');
      FDataTypesList.Add('SMALLINT');
      FDataTypesList.Add('VARCHAR');
      FDataTypesList.Add('CHAR');
      FDataTypesList.Add('BLOB');
      FDataTypesList.Add('DECIMAL');
      FDataTypesList.Add('NUMERIC');
      FDataTypesList.Add('FLOAT');
      FDataTypesList.Add('DOUBLE PRECISION');
      FDataTypesList.Add('BOOLEAN');
      FDataTypesList.Add('DATE');
      FDataTypesList.Add('TIME');
      FDataTypesList.Add('TIMESTAMP');
    end;
  end;
end;

procedure TFormTableBuilder.gridColumnsSelectEditor(Sender: TObject; aCol, aRow: Integer; var Editor: TWinControl);
var
  PickListEditor: TPickListCellEditor;
begin
  // Kolom 1 adalah "Tipe Data"
  if (aCol = 1) and (aRow > 0) then
  begin
    Editor := gridColumns.EditorByStyle(cbsPickList);
    if Assigned(Editor) and (Editor is TPickListCellEditor) then
    begin
      PickListEditor := TPickListCellEditor(Editor);
      PickListEditor.Items.Assign(FDataTypesList);
      PickListEditor.Style := csDropDown;
    end;
  end;
end;

procedure TFormTableBuilder.LoadExistingTable(const ATableName: string; const ASchema: string);
var
  Driver: TDBDriverBase;
  Cols: TSchemaColumnList;
  Idxs: TSchemaIndexList;
  FKs: TSchemaForeignKeyList;
  I, R: Integer;
  LenStr: string;
begin
  if not Assigned(FProfile) or (ATableName = '') then Exit;

  Driver := nil;
  Cols := TSchemaColumnList.Create(True);
  Idxs := TSchemaIndexList.Create(True);
  FKs := TSchemaForeignKeyList.Create(True);
  try
    try
      Driver := TDBConnectionFactory.CreateDriver(FProfile);

      // 1. Ekstrak Kolom
      Driver.ExtractColumns(FProfile.DatabaseName, ASchema, ATableName, Cols);
      if Cols.Count > 0 then
      begin
        gridColumns.RowCount := 1;
        for I := 0 to Cols.Count - 1 do
        begin
          gridColumns.RowCount := gridColumns.RowCount + 1;
          R := gridColumns.RowCount - 1;

          gridColumns.Cells[0, R] := Cols[I].Name;
          gridColumns.Cells[1, R] := Cols[I].DataType;

          if Cols[I].Precision > 0 then
            LenStr := Format('%d,%d', [Cols[I].Precision, Cols[I].Scale])
          else if Cols[I].Length > 0 then
            LenStr := IntToStr(Cols[I].Length)
          else
            LenStr := '0';

          gridColumns.Cells[2, R] := LenStr;

          if Cols[I].IsPrimaryKey then gridColumns.Cells[3, R] := '1' else gridColumns.Cells[3, R] := '0';
          if Cols[I].IsAutoIncrement then gridColumns.Cells[4, R] := '1' else gridColumns.Cells[4, R] := '0';
          if Cols[I].IsNullable then gridColumns.Cells[5, R] := '1' else gridColumns.Cells[5, R] := '0';
          if Cols[I].IsPrimaryKey then gridColumns.Cells[6, R] := '1' else gridColumns.Cells[6, R] := '0';
          gridColumns.Cells[7, R] := Cols[I].DefaultValue;
        end;
      end;

      // 2. Ekstrak Indeks
      try
        Driver.ExtractIndexes(FProfile.DatabaseName, ASchema, ATableName, Idxs);
        if Idxs.Count > 0 then
        begin
          gridIndexes.RowCount := 1;
          for I := 0 to Idxs.Count - 1 do
          begin
            gridIndexes.RowCount := gridIndexes.RowCount + 1;
            R := gridIndexes.RowCount - 1;
            gridIndexes.Cells[0, R] := Idxs[I].Name;
            if Idxs[I].IsUnique then
              gridIndexes.Cells[1, R] := 'UNIQUE'
            else
              gridIndexes.Cells[1, R] := 'INDEX';

            if Assigned(Idxs[I].Columns) then
              gridIndexes.Cells[2, R] := Idxs[I].Columns.CommaText;
          end;
        end;
      except
      end;

      // 3. Ekstrak Foreign Keys
      try
        Driver.ExtractForeignKeys(FProfile.DatabaseName, ASchema, ATableName, FKs);
        if FKs.Count > 0 then
        begin
          gridFKs.RowCount := 1;
          for I := 0 to FKs.Count - 1 do
          begin
            gridFKs.RowCount := gridFKs.RowCount + 1;
            R := gridFKs.RowCount - 1;
            gridFKs.Cells[0, R] := FKs[I].Name;
            gridFKs.Cells[1, R] := '';
            gridFKs.Cells[2, R] := FKs[I].RefTableName;
            gridFKs.Cells[3, R] := '';
            gridFKs.Cells[4, R] := FKs[I].OnUpdate;
            gridFKs.Cells[5, R] := FKs[I].OnDelete;
          end;
        end;
      except
      end;

    except
      on E: Exception do
        MessageDlg('Gagal Membaca Skema Tabel', E.Message, mtError, [mbOK], 0);
    end;
  finally
    Cols.Free;
    Idxs.Free;
    FKs.Free;
    if Assigned(Driver) then Driver.Free;
  end;
end;

procedure TFormTableBuilder.FormShow(Sender: TObject);
begin
  if Assigned(FProfile) then
  begin
    lblEngine.Visible := (FProfile.DriverType in [dtMySQL, dtMariaDB]);
    cboEngine.Visible := lblEngine.Visible;
    lblCharset.Visible := lblEngine.Visible;
    cboCharset.Visible := lblEngine.Visible;

    // Muat daftar tipe data sesuai DBMS
    PopulateDataTypesList;

    if FIsEditMode then
    begin
      Caption := Format('Sunting / Modifikasi Tabel "%s" - [%s (%s)]', [FExistingTableName, FProfile.ConnectionName, FProfile.GetDisplayName]);
      edtTableName.Text := FExistingTableName;
      btnExecuteDDL.Caption := '💾 Simpan Perubahan (DDL)';
      LoadExistingTable(FExistingTableName, edtSchema.Text);
    end
    else
    begin
      Caption := Format('Buat Tabel Baru - [%s (%s)]', [FProfile.ConnectionName, FProfile.GetDisplayName]);
      btnExecuteDDL.Caption := '⚡ Buat Tabel (CREATE)';
      if edtTableName.Text = '' then
        edtTableName.Text := 'tabel_baru';

      if gridColumns.RowCount = 1 then
      begin
        gridColumns.RowCount := 2;
        gridColumns.Cells[0, 1] := 'id';
        if FProfile.DriverType = dtPostgreSQL then
          gridColumns.Cells[1, 1] := 'SERIAL'
        else
          gridColumns.Cells[1, 1] := 'INTEGER';
        gridColumns.Cells[2, 1] := '0';
        gridColumns.Cells[3, 1] := '1';
        gridColumns.Cells[4, 1] := '1';
        gridColumns.Cells[5, 1] := '0';
        gridColumns.Cells[6, 1] := '0';
        gridColumns.Cells[7, 1] := '';
      end;
    end;

    UpdateDDLPreview;
  end;
end;

procedure TFormTableBuilder.SyncModelFromUI;
var
  I, Len, Prec, Scale, DotPos: Integer;
  Col: TBuilderColumn;
  Idx: TBuilderIndex;
  FK: TBuilderForeignKey;
  LenStr: string;
  ColTokens: TStringList;
begin
  FModel.Clear;
  FModel.TableName := Trim(edtTableName.Text);
  FModel.SchemaName := Trim(edtSchema.Text);
  FModel.Engine := Trim(cboEngine.Text);
  FModel.Charset := Trim(cboCharset.Text);

  // 1. Ambil Data Kolom
  for I := 1 to gridColumns.RowCount - 1 do
  begin
    if Trim(gridColumns.Cells[0, I]) = '' then Continue;

    Col := TBuilderColumn.Create;
    Col.Name := Trim(gridColumns.Cells[0, I]);
    Col.DataType := UpperCase(Trim(gridColumns.Cells[1, I]));
    if Col.DataType = '' then Col.DataType := 'VARCHAR';

    LenStr := Trim(gridColumns.Cells[2, I]);
    DotPos := Pos(',', LenStr);
    if DotPos > 0 then
    begin
      Prec := StrToIntDef(Copy(LenStr, 1, DotPos - 1), 10);
      Scale := StrToIntDef(Copy(LenStr, DotPos + 1, Length(LenStr)), 2);
      Col.Precision := Prec;
      Col.Scale := Scale;
    end
    else
    begin
      Len := StrToIntDef(LenStr, 0);
      Col.Length := Len;
    end;

    Col.IsPrimaryKey := (Trim(gridColumns.Cells[3, I]) = '1');
    Col.IsAutoIncrement := (Trim(gridColumns.Cells[4, I]) = '1');
    Col.IsNullable := (Trim(gridColumns.Cells[5, I]) = '1') and not Col.IsPrimaryKey;
    Col.IsUnique := (Trim(gridColumns.Cells[6, I]) = '1');
    Col.DefaultValue := Trim(gridColumns.Cells[7, I]);

    FModel.Columns.Add(Col);
  end;

  // 2. Ambil Data Indeks
  ColTokens := TStringList.Create;
  try
    for I := 1 to gridIndexes.RowCount - 1 do
    begin
      if (Trim(gridIndexes.Cells[0, I]) = '') or (Trim(gridIndexes.Cells[2, I]) = '') then Continue;

      Idx := FModel.AddIndex(Trim(gridIndexes.Cells[0, I]), UpperCase(Trim(gridIndexes.Cells[1, I])));
      ColTokens.CommaText := gridIndexes.Cells[2, I];
      Idx.Columns.Assign(ColTokens);
    end;

    // 3. Ambil Data Foreign Key
    for I := 1 to gridFKs.RowCount - 1 do
    begin
      if (Trim(gridFKs.Cells[0, I]) = '') or (Trim(gridFKs.Cells[2, I]) = '') then Continue;

      FK := FModel.AddForeignKey(Trim(gridFKs.Cells[0, I]), Trim(gridFKs.Cells[2, I]));
      ColTokens.CommaText := gridFKs.Cells[1, I];
      FK.Columns.Assign(ColTokens);

      ColTokens.CommaText := gridFKs.Cells[3, I];
      FK.RefColumns.Assign(ColTokens);

      FK.OnUpdate := UpperCase(Trim(gridFKs.Cells[4, I]));
      FK.OnDelete := UpperCase(Trim(gridFKs.Cells[5, I]));
    end;
  finally
    ColTokens.Free;
  end;
end;

procedure TFormTableBuilder.UpdateDDLPreview;
begin
  SyncModelFromUI;
  if Assigned(FProfile) then
    FGeneratedDDL := FModel.GenerateDDL(FProfile.DriverType)
  else
    FGeneratedDDL := FModel.GenerateDDL(dtSQLite);

  synDDLPreview.Lines.Text := FGeneratedDDL;
end;

procedure TFormTableBuilder.edtTableNameChange(Sender: TObject);
begin
  UpdateDDLPreview;
end;

procedure TFormTableBuilder.edtSchemaChange(Sender: TObject);
begin
  UpdateDDLPreview;
end;

procedure TFormTableBuilder.cboEngineChange(Sender: TObject);
begin
  UpdateDDLPreview;
end;

procedure TFormTableBuilder.cboCharsetChange(Sender: TObject);
begin
  UpdateDDLPreview;
end;

procedure TFormTableBuilder.btnAddColClick(Sender: TObject);
var
  R: Integer;
begin
  gridColumns.RowCount := gridColumns.RowCount + 1;
  R := gridColumns.RowCount - 1;
  gridColumns.Cells[0, R] := 'kolom_' + IntToStr(R);

  if (FProfile <> nil) and (FProfile.DriverType = dtSQLite) then
    gridColumns.Cells[1, R] := 'TEXT'
  else
    gridColumns.Cells[1, R] := 'VARCHAR';

  gridColumns.Cells[2, R] := '255';
  gridColumns.Cells[3, R] := '0';
  gridColumns.Cells[4, R] := '0';
  gridColumns.Cells[5, R] := '1';
  gridColumns.Cells[6, R] := '0';
  gridColumns.Cells[7, R] := '';
  UpdateDDLPreview;
end;

procedure TFormTableBuilder.btnDelColClick(Sender: TObject);
begin
  if (gridColumns.RowCount > 1) and (gridColumns.Row >= 1) then
  begin
    gridColumns.DeleteRow(gridColumns.Row);
    UpdateDDLPreview;
  end;
end;

procedure TFormTableBuilder.btnMoveUpColClick(Sender: TObject);
var
  R, C: Integer;
  Temp: string;
begin
  R := gridColumns.Row;
  if R > 1 then
  begin
    for C := 0 to gridColumns.ColCount - 1 do
    begin
      Temp := gridColumns.Cells[C, R];
      gridColumns.Cells[C, R] := gridColumns.Cells[C, R - 1];
      gridColumns.Cells[C, R - 1] := Temp;
    end;
    gridColumns.Row := R - 1;
    UpdateDDLPreview;
  end;
end;

procedure TFormTableBuilder.btnMoveDownColClick(Sender: TObject);
var
  R, C: Integer;
  Temp: string;
begin
  R := gridColumns.Row;
  if (R >= 1) and (R < gridColumns.RowCount - 1) then
  begin
    for C := 0 to gridColumns.ColCount - 1 do
    begin
      Temp := gridColumns.Cells[C, R];
      gridColumns.Cells[C, R] := gridColumns.Cells[C, R + 1];
      gridColumns.Cells[C, R + 1] := Temp;
    end;
    gridColumns.Row := R + 1;
    UpdateDDLPreview;
  end;
end;

procedure TFormTableBuilder.gridColumnsEditingDone(Sender: TObject);
begin
  UpdateDDLPreview;
end;

procedure TFormTableBuilder.btnAddIdxClick(Sender: TObject);
var
  R: Integer;
begin
  gridIndexes.RowCount := gridIndexes.RowCount + 1;
  R := gridIndexes.RowCount - 1;
  gridIndexes.Cells[0, R] := Format('idx_%s_%d', [Trim(edtTableName.Text), R]);
  gridIndexes.Cells[1, R] := 'INDEX';
  gridIndexes.Cells[2, R] := 'id';
  UpdateDDLPreview;
end;

procedure TFormTableBuilder.btnDelIdxClick(Sender: TObject);
begin
  if (gridIndexes.RowCount > 1) and (gridIndexes.Row >= 1) then
  begin
    gridIndexes.DeleteRow(gridIndexes.Row);
    UpdateDDLPreview;
  end;
end;

procedure TFormTableBuilder.gridIndexesEditingDone(Sender: TObject);
begin
  UpdateDDLPreview;
end;

procedure TFormTableBuilder.btnAddFKClick(Sender: TObject);
var
  R: Integer;
begin
  gridFKs.RowCount := gridFKs.RowCount + 1;
  R := gridFKs.RowCount - 1;
  gridFKs.Cells[0, R] := Format('fk_%s_%d', [Trim(edtTableName.Text), R]);
  gridFKs.Cells[1, R] := 'parent_id';
  gridFKs.Cells[2, R] := 'tabel_induk';
  gridFKs.Cells[3, R] := 'id';
  gridFKs.Cells[4, R] := 'NO ACTION';
  gridFKs.Cells[5, R] := 'NO ACTION';
  UpdateDDLPreview;
end;

procedure TFormTableBuilder.btnDelFKClick(Sender: TObject);
begin
  if (gridFKs.RowCount > 1) and (gridFKs.Row >= 1) then
  begin
    gridFKs.DeleteRow(gridFKs.Row);
    UpdateDDLPreview;
  end;
end;

procedure TFormTableBuilder.gridFKsEditingDone(Sender: TObject);
begin
  UpdateDDLPreview;
end;

procedure TFormTableBuilder.pgcMainChange(Sender: TObject);
begin
  if pgcMain.ActivePage = tabDDLPreview then
    UpdateDDLPreview;
end;

procedure TFormTableBuilder.btnCopyDDLClick(Sender: TObject);
begin
  UpdateDDLPreview;
  Clipboard.AsText := synDDLPreview.Lines.Text;
  MessageDlg('Visual Table Builder', 'Skrip CREATE TABLE DDL berhasil disalin ke Clipboard.', mtInformation, [mbOK], 0);
end;

procedure TFormTableBuilder.btnExecuteDDLClick(Sender: TObject);
var
  Conn: TZConnection;
begin
  UpdateDDLPreview;
  if Trim(FGeneratedDDL) = '' then Exit;

  if MessageDlg('Konfirmasi Eksekusi DDL',
    Format('Eksekusi perintah DDL berikut ke database "%s"?%s%s', [FProfile.ConnectionName, LineEnding, FGeneratedDDL]),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

  Screen.Cursor := crHourGlass;
  Conn := TZConnection.Create(nil);
  try
    try
      case FProfile.DriverType of
        dtMySQL:      Conn.Protocol := 'mysql';
        dtMariaDB:    Conn.Protocol := 'mariadb';
        dtPostgreSQL: Conn.Protocol := 'postgresql';
        dtFirebird:   Conn.Protocol := 'firebird';
        dtSQLite:     Conn.Protocol := 'sqlite';
      end;
      Conn.HostName := FProfile.Host;
      Conn.Port := FProfile.Port;
      Conn.Database := FProfile.DatabaseName;
      Conn.User := FProfile.Username;
      Conn.Password := FProfile.Password;
      Conn.AutoCommit := True;
      Conn.Connect;

      Conn.ExecuteDirect(FGeneratedDDL);
      SQLLogger.LogSQL(FGeneratedDDL);

      MessageDlg('Sukses', Format('Struktur tabel "%s" berhasil diperbarui / dibuat di database.', [FModel.TableName]), mtInformation, [mbOK], 0);
      ModalResult := mrOk;
    except
      on E: Exception do
      begin
        SQLLogger.LogError(E.Message, FGeneratedDDL);
        MessageDlg('Gagal Mengeksekusi DDL', E.Message, mtError, [mbOK], 0);
      end;
    end;
  finally
    Conn.Free;
    Screen.Cursor := crDefault;
  end;
end;

procedure TFormTableBuilder.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
