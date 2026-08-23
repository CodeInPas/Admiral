unit uFormQueryBuilder;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  ComCtrls, StdCtrls, Buttons, Grids, CheckLst, Menus, Clipbrd, Types,
  SynEdit, SynHighlighterSQL,
  uAppTypes, uDBTypes, uModelConnection, uDBDriverBase, uDBConnectionFactory,
  uModelSchemaObject, uModelVisualQuery, cyPageControl;

type
  { TFormQueryBuilder }
  TFormQueryBuilder = class(TForm)
    btnAddJoin: TSpeedButton;
    btnAddWhere: TSpeedButton;
    btnCopySQL: TSpeedButton;
    btnDeleteJoin: TSpeedButton;
    btnDeleteWhere: TSpeedButton;
    btnInsertToEditor: TSpeedButton;
    btnResetBuilder: TSpeedButton;
    chkDistinct: TCheckBox;
    pgDesain: TcyPageControl;
    edtLimit: TEdit;
    edtOffset: TEdit;
    gridColumns: TStringGrid;
    gridJoins: TStringGrid;
    gridWhere: TStringGrid;
    lblLimit: TLabel;
    lblOffset: TLabel;
    lblSQLPreview: TLabel;
    pgcConfig: TPageControl;
    pnlBottomToolbar: TPanel;
    pnlJoinActions: TPanel;
    pnlLeft: TPanel;
    pnlWhereActions: TPanel;
    splLeft: TSplitter;
    pnlCenter: TPanel;
    splBottom: TSplitter;
    pnlBottom: TPanel;

    // Kiri
    pnlLeftHeader: TPanel;
    lblSchemaTables: TLabel;
    lbTables: TListBox;
    btnAddSelectedTable: TSpeedButton;

    // Canvas
    pnlTablesCanvas: TPanel;
    sbCanvas: TScrollBox;

    synSQLPreview: TSynEdit;
    tabColumns: TTabSheet;
    tabJoins: TTabSheet;
    tabOptions: TTabSheet;
    tbsDesain: TTabSheet;
    tbsScript: TTabSheet;





    synSQLSyn: TSynSQLSyn;
    tabWhere: TTabSheet;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);

    procedure btnAddSelectedTableClick(Sender: TObject);
    procedure lbTablesDblClick(Sender: TObject);
    procedure btnAddJoinClick(Sender: TObject);
    procedure btnDeleteJoinClick(Sender: TObject);
    procedure btnAddWhereClick(Sender: TObject);
    procedure btnDeleteWhereClick(Sender: TObject);

    procedure gridColumnsEditingDone(Sender: TObject);
    procedure gridJoinsEditingDone(Sender: TObject);
    procedure gridWhereEditingDone(Sender: TObject);

    procedure chkDistinctChange(Sender: TObject);
    procedure edtLimitChange(Sender: TObject);

    procedure btnCopySQLClick(Sender: TObject);
    procedure btnInsertToEditorClick(Sender: TObject);
    procedure btnResetBuilderClick(Sender: TObject);

    procedure sbCanvasPaint(Sender: TObject);
  private
    FProfile: TConnectionProfile;
    FDriver: TDBDriverBase;
    FModel: TVisualQueryModel;
    FGeneratedSQL: string;

    // State Dragging untuk Perpindahan Card Tabel
    FMovingPanel: TPanel;
    FDragStartMousePos: TPoint;
    FDragStartPanelPos: TPoint;

    // State Dragging Field untuk Pembuatan Relasi JOIN
    FDragSourceTable: TVisualTable;
    FDragSourceColName: string;

    procedure AsyncDestroyControl(Data: PtrInt);
    procedure LoadDatabaseTables;
    procedure AddTableToBuilder(const ATableName: string);
    procedure RebuildColumnsGrid;
    procedure RebuildJoinsGrid;
    procedure UpdateGeneratedSQL;
    procedure HandleTableBoxClose(Sender: TObject);
    procedure HandleTableColumnCheck(Sender: TObject);

    // Event Handler Interaktif Card & Drag-and-Drop JOIN
    procedure TableHeadMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure TableHeadMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure TableHeadMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);

    procedure ColumnListStartDrag(Sender: TObject; var DragObject: TDragObject);
    procedure ColumnListDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
    procedure ColumnListDragDrop(Sender, Source: TObject; X, Y: Integer);

    function FindTablePanel(const AAlias: string): TPanel;
    function GetFieldCenterPoint(const AAlias, AColName: string): TPoint;
  public
    class function Execute(AOwner: TComponent; AProfile: TConnectionProfile; out ASQL: string): Boolean;
    property Profile: TConnectionProfile read FProfile write FProfile;
  end;

implementation

{$R *.lfm}

{ TFormQueryBuilder }

class function TFormQueryBuilder.Execute(AOwner: TComponent; AProfile: TConnectionProfile; out ASQL: string): Boolean;
var
  Frm: TFormQueryBuilder;
begin
  Result := False;
  ASQL := '';
  Frm := TFormQueryBuilder.Create(AOwner);
  try
    Frm.Profile := AProfile;
    if Frm.ShowModal = mrOk then
    begin
      ASQL := Frm.FGeneratedSQL;
      Result := True;
    end;
  finally
    Frm.Free;
  end;
end;

procedure TFormQueryBuilder.FormCreate(Sender: TObject);
begin
  FModel := TVisualQueryModel.Create;
  FDriver := nil;
  FGeneratedSQL := '';
  FMovingPanel := nil;
  FDragSourceTable := nil;
  FDragSourceColName := '';

  sbCanvas.DoubleBuffered := True;
  synSQLPreview.Highlighter := synSQLSyn;

  // Header Grid Kolom
  gridColumns.ColCount := 5;
  gridColumns.RowCount := 1;
  gridColumns.Cells[0, 0] := 'Tabel';
  gridColumns.Cells[1, 0] := 'Kolom';
  gridColumns.Cells[2, 0] := 'Alias Output';
  gridColumns.Cells[3, 0] := 'Agregasi (COUNT/SUM/AVG/MIN/MAX)';
  gridColumns.Cells[4, 0] := 'Urutan (ASC/DESC)';

  // Header Grid JOIN
  gridJoins.ColCount := 4;
  gridJoins.RowCount := 1;
  gridJoins.Cells[0, 0] := 'Tipe JOIN (INNER/LEFT/RIGHT)';
  gridJoins.Cells[1, 0] := 'Kolom Kiri (t1.kolom)';
  gridJoins.Cells[2, 0] := '=';
  gridJoins.Cells[3, 0] := 'Kolom Kanan (t2.kolom)';

  // Header Grid WHERE
  gridWhere.ColCount := 4;
  gridWhere.RowCount := 1;
  gridWhere.Cells[0, 0] := 'Kolom (t1.kolom)';
  gridWhere.Cells[1, 0] := 'Operator (=, LIKE, >, <)';
  gridWhere.Cells[2, 0] := 'Nilai / Nilai String';
  gridWhere.Cells[3, 0] := 'Konektor (AND/OR)';
end;

procedure TFormQueryBuilder.FormDestroy(Sender: TObject);
begin
  if Assigned(FDriver) then
    FreeAndNil(FDriver);
  FModel.Free;
  //inherited Destroy;
end;

procedure TFormQueryBuilder.FormShow(Sender: TObject);
begin
  if Assigned(FProfile) then
  begin
    Caption := Format('Visual Query Builder - [%s]', [FProfile.ConnectionName]);
    if Assigned(FDriver) then
      FreeAndNil(FDriver);
    FDriver := TDBConnectionFactory.CreateDriver(FProfile);
    LoadDatabaseTables;
  end;
end;

procedure TFormQueryBuilder.LoadDatabaseTables;
var
  SchemaList: TSchemaObjectList;
  I: Integer;
begin
  lbTables.Items.Clear;
  if not Assigned(FDriver) then Exit;

  SchemaList := TSchemaObjectList.Create;
  try
    try
      FDriver.ExtractTables('', '', SchemaList);
      for I := 0 to SchemaList.Count - 1 do
        lbTables.Items.Add(SchemaList[I].Name);
    except
      on E: Exception do
        MessageDlg('Peringatan Skema', 'Gagal memuat daftar tabel: ' + E.Message, mtWarning, [mbOK], 0);
    end;
  finally
    SchemaList.Free;
  end;
end;

procedure TFormQueryBuilder.AddTableToBuilder(const ATableName: string);
var
  Tbl: TVisualTable;
  ColList: TSchemaColumnList;
  I: Integer;
  VCol: TVisualColumn;
  PnlTable, PnlTableHead: TPanel;
  LblName: TLabel;
  BtnClose: TSpeedButton;
  ChkList: TCheckListBox;
begin
  if Trim(ATableName) = '' then Exit;
  if not Assigned(FDriver) then Exit;

  Tbl := FModel.AddTable(ATableName, '', '');

  ColList := TSchemaColumnList.Create;
  try
    try
      FDriver.ExtractColumns('', '', ATableName, ColList);
    except
    end;

    // Kolom wildcard default (*)
    VCol := TVisualColumn.Create;
    VCol.TableAlias := Tbl.Alias;
    VCol.ColumnName := '*';
    VCol.IsSelected := False;
    Tbl.Columns.Add(VCol);

    for I := 0 to ColList.Count - 1 do
    begin
      VCol := TVisualColumn.Create;
      VCol.TableAlias := Tbl.Alias;
      VCol.ColumnName := ColList[I].Name;
      VCol.IsSelected := False;
      Tbl.Columns.Add(VCol);
    end;
  finally
    ColList.Free;
  end;

  // 1. Container Card Visual
  PnlTable := TPanel.Create(sbCanvas);
  PnlTable.Parent := sbCanvas;
  PnlTable.Width := 210;
  PnlTable.Height := 230;
  PnlTable.Left := (FModel.Tables.Count - 1) * 230 + 15;
  PnlTable.Top := 15;
  PnlTable.BevelOuter := bvRaised;
  PnlTable.Tag := PtrInt(Tbl);

  // 2. Header Panel Card (Movable)
  PnlTableHead := TPanel.Create(PnlTable);
  PnlTableHead.Parent := PnlTable;
  PnlTableHead.Align := alTop;
  PnlTableHead.Height := 28;
  PnlTableHead.Color := clMenuHighlight;
  PnlTableHead.BevelOuter := bvNone;
  PnlTableHead.Cursor := crSizeAll;
  PnlTableHead.Tag := PtrInt(PnlTable);
  PnlTableHead.OnMouseDown := @TableHeadMouseDown;
  PnlTableHead.OnMouseMove := @TableHeadMouseMove;
  PnlTableHead.OnMouseUp := @TableHeadMouseUp;

  LblName := TLabel.Create(PnlTableHead);
  LblName.Parent := PnlTableHead;
  LblName.Left := 6;
  LblName.Top := 6;
  LblName.Caption := Format('%s (%s)', [Tbl.TableName, Tbl.Alias]);
  LblName.Font.Color := clHighlightText;
  LblName.Font.Style := [fsBold];
  LblName.Cursor := crSizeAll;
  LblName.Tag := PtrInt(PnlTable);
  LblName.OnMouseDown := @TableHeadMouseDown;
  LblName.OnMouseMove := @TableHeadMouseMove;
  LblName.OnMouseUp := @TableHeadMouseUp;

  BtnClose := TSpeedButton.Create(PnlTableHead);
  BtnClose.Parent := PnlTableHead;
  BtnClose.Align := alRight;
  BtnClose.Width := 24;
  BtnClose.Caption := '✕';
  BtnClose.Flat := True;
  BtnClose.Font.Color := clHighlightText;
  BtnClose.Tag := PtrInt(PnlTable);
  BtnClose.OnClick := @HandleTableBoxClose;

  // 3. Daftar Field (Dapat Dicentang & Di-drag untuk JOIN)
  ChkList := TCheckListBox.Create(PnlTable);
  ChkList.Parent := PnlTable;
  ChkList.Align := alClient;
  ChkList.Tag := PtrInt(Tbl);
  ChkList.DragMode := dmAutomatic; // Mengaktifkan drag-and-drop antar field

  for I := 0 to Tbl.Columns.Count - 1 do
  begin
    ChkList.Items.Add(TVisualColumn(Tbl.Columns[I]).ColumnName);
    ChkList.Checked[I] := TVisualColumn(Tbl.Columns[I]).IsSelected;
  end;

  ChkList.OnClickCheck := @HandleTableColumnCheck;
  ChkList.OnStartDrag := @ColumnListStartDrag;
  ChkList.OnDragOver := @ColumnListDragOver;
  ChkList.OnDragDrop := @ColumnListDragDrop;

  RebuildColumnsGrid;
  UpdateGeneratedSQL;
  sbCanvas.Invalidate;
end;

procedure TFormQueryBuilder.TableHeadMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Ctrl: TControl;
begin
  if Button = mbLeft then
  begin
    Ctrl := TControl(Sender);
    FMovingPanel := TPanel(Ctrl.Tag);
    if Assigned(FMovingPanel) then
    begin
      FMovingPanel.BringToFront;
      FDragStartMousePos := Mouse.CursorPos;
      FDragStartPanelPos := Point(FMovingPanel.Left, FMovingPanel.Top);
    end;
  end;
end;

procedure TFormQueryBuilder.TableHeadMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  CurPos: TPoint;
  NewLeft, NewTop: Integer;
begin
  if (ssLeft in Shift) and Assigned(FMovingPanel) then
  begin
    CurPos := Mouse.CursorPos;
    NewLeft := FDragStartPanelPos.X + (CurPos.X - FDragStartMousePos.X);
    NewTop := FDragStartPanelPos.Y + (CurPos.Y - FDragStartMousePos.Y);

    if NewLeft < 5 then NewLeft := 5;
    if NewTop < 5 then NewTop := 5;

    FMovingPanel.Left := NewLeft;
    FMovingPanel.Top := NewTop;
    sbCanvas.Invalidate; // Redraw garis koneksi saat card tabel bergeser
  end;
end;

procedure TFormQueryBuilder.TableHeadMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FMovingPanel := nil;
  sbCanvas.Invalidate;
end;

procedure TFormQueryBuilder.ColumnListStartDrag(Sender: TObject; var DragObject: TDragObject);
var
  ChkList: TCheckListBox;
begin
  ChkList := TCheckListBox(Sender);
  FDragSourceTable := TVisualTable(ChkList.Tag);
  if (ChkList.ItemIndex >= 0) and (ChkList.Items[ChkList.ItemIndex] <> '*') then
    FDragSourceColName := ChkList.Items[ChkList.ItemIndex]
  else
  begin
    FDragSourceTable := nil;
    FDragSourceColName := '';
  end;
end;

procedure TFormQueryBuilder.ColumnListDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
var
  TargetChkList: TCheckListBox;
  TargetIndex: Integer;
begin
  Accept := False;
  if (Source is TCheckListBox) and (Source <> Sender) and Assigned(FDragSourceTable) and (FDragSourceColName <> '') then
  begin
    TargetChkList := TCheckListBox(Sender);
    TargetIndex := TargetChkList.ItemAtPos(Point(X, Y), True);
    if (TargetIndex >= 0) and (TargetChkList.Items[TargetIndex] <> '*') then
      Accept := True;
  end;
end;

procedure TFormQueryBuilder.ColumnListDragDrop(Sender, Source: TObject; X, Y: Integer);
var
  TargetChkList: TCheckListBox;
  TargetTable: TVisualTable;
  TargetIndex: Integer;
  TargetColName: string;
begin
  if (Source is TCheckListBox) and (Source <> Sender) and Assigned(FDragSourceTable) and (FDragSourceColName <> '') then
  begin
    TargetChkList := TCheckListBox(Sender);
    TargetTable := TVisualTable(TargetChkList.Tag);
    TargetIndex := TargetChkList.ItemAtPos(Point(X, Y), True);

    if (TargetIndex >= 0) and Assigned(TargetTable) then
    begin
      TargetColName := TargetChkList.Items[TargetIndex];

      // Daftarkan relasi INNER JOIN ke model visual
      FModel.AddJoin(qjtInner, FDragSourceTable.Alias, FDragSourceColName, TargetTable.Alias, TargetColName);

      RebuildJoinsGrid;
      UpdateGeneratedSQL;
      sbCanvas.Invalidate;
    end;
  end;

  FDragSourceTable := nil;
  FDragSourceColName := '';
end;

function TFormQueryBuilder.FindTablePanel(const AAlias: string): TPanel;
var
  I: Integer;
  Pnl: TPanel;
  Tbl: TVisualTable;
begin
  Result := nil;
  for I := 0 to sbCanvas.ControlCount - 1 do
  begin
    if sbCanvas.Controls[I] is TPanel then
    begin
      Pnl := TPanel(sbCanvas.Controls[I]);
      if Pnl.Tag <> 0 then
      begin
        Tbl := TVisualTable(Pnl.Tag);
        if Assigned(Tbl) and SameText(Tbl.Alias, AAlias) then
          Exit(Pnl);
      end;
    end;
  end;
end;

function TFormQueryBuilder.GetFieldCenterPoint(const AAlias, AColName: string): TPoint;
var
  Pnl: TPanel;
  ChkList: TCheckListBox;
  I, ItemIdx: Integer;
  ItemY, ItemH: Integer;
begin
  Result := Point(0, 0);
  Pnl := FindTablePanel(AAlias);
  if not Assigned(Pnl) then Exit;

  ChkList := nil;
  for I := 0 to Pnl.ControlCount - 1 do
  begin
    if Pnl.Controls[I] is TCheckListBox then
    begin
      ChkList := TCheckListBox(Pnl.Controls[I]);
      Break;
    end;
  end;

  if not Assigned(ChkList) then Exit;

  ItemIdx := ChkList.Items.IndexOf(AColName);
  if ItemIdx < 0 then ItemIdx := 0;

  ItemH := ChkList.ItemHeight;
  if ItemH <= 0 then ItemH := 18;

  ItemY := Pnl.Top + 28 + (ItemIdx * ItemH) + (ItemH div 2);
  Result := Point(Pnl.Left, ItemY);
end;

procedure TFormQueryBuilder.sbCanvasPaint(Sender: TObject);
var
  I: Integer;
  Jn: TVisualJoin;
  Pt1, Pt2: TPoint;
  Pnl1, Pnl2: TPanel;
  MidX, MidY: Integer;
  BadgeRect: TRect;
begin
  sbCanvas.Canvas.Pen.Color := $00D07020; // Warna aksen garis koneksi
  sbCanvas.Canvas.Pen.Width := 2;
  sbCanvas.Canvas.Brush.Color := $00F0F0F0;
  sbCanvas.Canvas.Font.Size := 8;

  for I := 0 to FModel.Joins.Count - 1 do
  begin
    Jn := TVisualJoin(FModel.Joins[I]);
    Pnl1 := FindTablePanel(Jn.LeftTableAlias);
    Pnl2 := FindTablePanel(Jn.RightTableAlias);

    if Assigned(Pnl1) and Assigned(Pnl2) then
    begin
      Pt1 := GetFieldCenterPoint(Jn.LeftTableAlias, Jn.LeftColumn);
      Pt2 := GetFieldCenterPoint(Jn.RightTableAlias, Jn.RightColumn);

      // Tentukan posisi anchor sisi kanan / kiri panel
      if Pnl1.Left < Pnl2.Left then
      begin
        Pt1.X := Pnl1.Left + Pnl1.Width;
        Pt2.X := Pnl2.Left;
      end
      else
      begin
        Pt1.X := Pnl1.Left;
        Pt2.X := Pnl2.Left + Pnl2.Width;
      end;

      // 1. Gambar Titik Temu Pin
      sbCanvas.Canvas.Brush.Color := $00D07020;
      sbCanvas.Canvas.Ellipse(Pt1.X - 4, Pt1.Y - 4, Pt1.X + 4, Pt1.Y + 4);
      sbCanvas.Canvas.Ellipse(Pt2.X - 4, Pt2.Y - 4, Pt2.X + 4, Pt2.Y + 4);

      // 2. Gambar Garis Konektor (Bezier Style)
      sbCanvas.Canvas.MoveTo(Pt1.X, Pt1.Y);
      MidX := (Pt1.X + Pt2.X) div 2;
      MidY := (Pt1.Y + Pt2.Y) div 2;
      sbCanvas.Canvas.LineTo(MidX, Pt1.Y);
      sbCanvas.Canvas.LineTo(MidX, Pt2.Y);
      sbCanvas.Canvas.LineTo(Pt2.X, Pt2.Y);

      // 3. Gambar Badge Jenis Relasi [ = ]
      sbCanvas.Canvas.Brush.Color := clWhite;
      BadgeRect := Rect(MidX - 14, MidY - 9, MidX + 14, MidY + 9);
      sbCanvas.Canvas.Rectangle(BadgeRect);
      sbCanvas.Canvas.TextOut(MidX - 7, MidY - 7, '=');
    end;
  end;
end;

procedure TFormQueryBuilder.RebuildJoinsGrid;
var
  I, RowIdx: Integer;
  Jn: TVisualJoin;
  JTypeStr: string;
begin
  gridJoins.RowCount := 1;
  RowIdx := 1;

  for I := 0 to FModel.Joins.Count - 1 do
  begin
    Jn := TVisualJoin(FModel.Joins[I]);
    gridJoins.RowCount := RowIdx + 1;

    case Jn.JoinType of
      qjtInner: JTypeStr := 'INNER JOIN';
      qjtLeft:  JTypeStr := 'LEFT JOIN';
      qjtRight: JTypeStr := 'RIGHT JOIN';
      qjtFull:  JTypeStr := 'FULL OUTER JOIN';
      qjtCross: JTypeStr := 'CROSS JOIN';
    end;

    gridJoins.Cells[0, RowIdx] := JTypeStr;
    gridJoins.Cells[1, RowIdx] := Format('%s.%s', [Jn.LeftTableAlias, Jn.LeftColumn]);
    gridJoins.Cells[2, RowIdx] := '=';
    gridJoins.Cells[3, RowIdx] := Format('%s.%s', [Jn.RightTableAlias, Jn.RightColumn]);

    Inc(RowIdx);
  end;
end;

procedure TFormQueryBuilder.AsyncDestroyControl(Data: PtrInt);
var
  Ctrl: TControl;
begin
  Ctrl := TControl(Data);
  if Assigned(Ctrl) then
    Ctrl.Free;
end;

procedure TFormQueryBuilder.HandleTableBoxClose(Sender: TObject);
var
  Btn: TSpeedButton;
  PnlTable: TPanel;
  Tbl: TVisualTable;
begin
  Btn := TSpeedButton(Sender);
  PnlTable := TPanel(Btn.Tag);
  if not Assigned(PnlTable) then Exit;
  Tbl := TVisualTable(PnlTable.Tag);

  if Assigned(Tbl) then
    FModel.RemoveTable(Tbl.Alias);

  PnlTable.Visible := False;
  PnlTable.Parent := nil;
  Application.QueueAsyncCall(@AsyncDestroyControl, PtrInt(PnlTable));

  RebuildColumnsGrid;
  RebuildJoinsGrid;
  UpdateGeneratedSQL;
  sbCanvas.Invalidate;
end;

procedure TFormQueryBuilder.HandleTableColumnCheck(Sender: TObject);
var
  ChkList: TCheckListBox;
  Tbl: TVisualTable;
  I: Integer;
begin
  ChkList := TCheckListBox(Sender);
  Tbl := TVisualTable(ChkList.Tag);

  for I := 0 to ChkList.Count - 1 do
    TVisualColumn(Tbl.Columns[I]).IsSelected := ChkList.Checked[I];

  RebuildColumnsGrid;
  UpdateGeneratedSQL;
end;

procedure TFormQueryBuilder.RebuildColumnsGrid;
var
  I, J, RowIdx: Integer;
  Tbl: TVisualTable;
  Col: TVisualColumn;
begin
  gridColumns.RowCount := 1;
  RowIdx := 1;

  for I := 0 to FModel.Tables.Count - 1 do
  begin
    Tbl := TVisualTable(FModel.Tables[I]);
    for J := 0 to Tbl.Columns.Count - 1 do
    begin
      Col := TVisualColumn(Tbl.Columns[J]);
      if Col.IsSelected then
      begin
        gridColumns.RowCount := RowIdx + 1;
        gridColumns.Cells[0, RowIdx] := Tbl.Alias;
        gridColumns.Cells[1, RowIdx] := Col.ColumnName;
        gridColumns.Cells[2, RowIdx] := Col.OutputAlias;

        case Col.Aggregate of
          qaCount: gridColumns.Cells[3, RowIdx] := 'COUNT';
          qaCountDistinct: gridColumns.Cells[3, RowIdx] := 'COUNT(DISTINCT)';
          qaSum: gridColumns.Cells[3, RowIdx] := 'SUM';
          qaAvg: gridColumns.Cells[3, RowIdx] := 'AVG';
          qaMin: gridColumns.Cells[3, RowIdx] := 'MIN';
          qaMax: gridColumns.Cells[3, RowIdx] := 'MAX';
          else gridColumns.Cells[3, RowIdx] := '';
        end;

        case Col.SortDir of
          qsdAsc: gridColumns.Cells[4, RowIdx] := 'ASC';
          qsdDesc: gridColumns.Cells[4, RowIdx] := 'DESC';
          else gridColumns.Cells[4, RowIdx] := '';
        end;

        Inc(RowIdx);
      end;
    end;
  end;
end;

procedure TFormQueryBuilder.gridColumnsEditingDone(Sender: TObject);
var
  RowIdx: Integer;
  TblAlias, ColName, AliasOut, AggStr, SortStr: string;
  Tbl: TVisualTable;
  Col: TVisualColumn;
  I: Integer;
begin
  RowIdx := gridColumns.Row;
  if RowIdx < 1 then Exit;

  TblAlias := gridColumns.Cells[0, RowIdx];
  ColName := gridColumns.Cells[1, RowIdx];
  AliasOut := Trim(gridColumns.Cells[2, RowIdx]);
  AggStr := UpperCase(Trim(gridColumns.Cells[3, RowIdx]));
  SortStr := UpperCase(Trim(gridColumns.Cells[4, RowIdx]));

  Tbl := FModel.FindTableByAlias(TblAlias);
  if Assigned(Tbl) then
  begin
    for I := 0 to Tbl.Columns.Count - 1 do
    begin
      Col := TVisualColumn(Tbl.Columns[I]);
      if Col.ColumnName = ColName then
      begin
        Col.OutputAlias := AliasOut;

        if AggStr = 'COUNT' then Col.Aggregate := qaCount
        else if (AggStr = 'COUNT(DISTINCT)') or (AggStr = 'COUNT_DISTINCT') then Col.Aggregate := qaCountDistinct
        else if AggStr = 'SUM' then Col.Aggregate := qaSum
        else if AggStr = 'AVG' then Col.Aggregate := qaAvg
        else if AggStr = 'MIN' then Col.Aggregate := qaMin
        else if AggStr = 'MAX' then Col.Aggregate := qaMax
        else Col.Aggregate := qaNone;

        if SortStr = 'ASC' then Col.SortDir := qsdAsc
        else if SortStr = 'DESC' then Col.SortDir := qsdDesc
        else Col.SortDir := qsdNone;

        Break;
      end;
    end;
    UpdateGeneratedSQL;
  end;
end;

procedure TFormQueryBuilder.UpdateGeneratedSQL;
begin
  FModel.Distinct := chkDistinct.Checked;
  FModel.Limit := StrToIntDef(Trim(edtLimit.Text), 0);
  FModel.Offset := StrToIntDef(Trim(edtOffset.Text), 0);

  if Assigned(FProfile) then
    FGeneratedSQL := FModel.GenerateSQL(FProfile.DriverType)
  else
    FGeneratedSQL := FModel.GenerateSQL(dtSQLite);

  synSQLPreview.Lines.Text := FGeneratedSQL;
end;

procedure TFormQueryBuilder.btnAddSelectedTableClick(Sender: TObject);
begin
  if lbTables.ItemIndex >= 0 then
    AddTableToBuilder(lbTables.Items[lbTables.ItemIndex]);
end;

procedure TFormQueryBuilder.lbTablesDblClick(Sender: TObject);
begin
  btnAddSelectedTableClick(Sender);
end;

procedure TFormQueryBuilder.btnAddJoinClick(Sender: TObject);
var
  R: Integer;
begin
  gridJoins.RowCount := gridJoins.RowCount + 1;
  R := gridJoins.RowCount - 1;
  gridJoins.Cells[0, R] := 'INNER JOIN';
  gridJoins.Cells[1, R] := 't1.id';
  gridJoins.Cells[2, R] := '=';
  gridJoins.Cells[3, R] := 't2.id';
end;

procedure TFormQueryBuilder.btnDeleteJoinClick(Sender: TObject);
begin
  if (gridJoins.RowCount > 1) and (gridJoins.Row >= 1) then
  begin
    gridJoins.DeleteRow(gridJoins.Row);
    gridJoinsEditingDone(Sender);
  end;
end;

procedure TFormQueryBuilder.gridJoinsEditingDone(Sender: TObject);
var
  I, DotPos1, DotPos2: Integer;
  JTypeStr, LeftStr, RightStr, LAlias, LCol, RAlias, RCol: string;
  JType: TQueryJoinType;
begin
  for I := 0 to FModel.Joins.Count - 1 do
    TVisualJoin(FModel.Joins[I]).Free;
  FModel.Joins.Clear;

  for I := 1 to gridJoins.RowCount - 1 do
  begin
    JTypeStr := UpperCase(Trim(gridJoins.Cells[0, I]));
    LeftStr := Trim(gridJoins.Cells[1, I]);
    RightStr := Trim(gridJoins.Cells[3, I]);

    if Pos('LEFT', JTypeStr) > 0 then JType := qjtLeft
    else if Pos('RIGHT', JTypeStr) > 0 then JType := qjtRight
    else if Pos('FULL', JTypeStr) > 0 then JType := qjtFull
    else if Pos('CROSS', JTypeStr) > 0 then JType := qjtCross
    else JType := qjtInner;

    DotPos1 := Pos('.', LeftStr);
    DotPos2 := Pos('.', RightStr);

    if (DotPos1 > 0) and (DotPos2 > 0) then
    begin
      LAlias := Copy(LeftStr, 1, DotPos1 - 1);
      LCol := Copy(LeftStr, DotPos1 + 1, Length(LeftStr));
      RAlias := Copy(RightStr, 1, DotPos2 - 1);
      RCol := Copy(RightStr, DotPos2 + 1, Length(RightStr));
      FModel.AddJoin(JType, LAlias, LCol, RAlias, RCol);
    end;
  end;

  UpdateGeneratedSQL;
  sbCanvas.Invalidate;
end;

procedure TFormQueryBuilder.btnAddWhereClick(Sender: TObject);
var
  R: Integer;
begin
  gridWhere.RowCount := gridWhere.RowCount + 1;
  R := gridWhere.RowCount - 1;
  gridWhere.Cells[0, R] := 't1.id';
  gridWhere.Cells[1, R] := '=';
  gridWhere.Cells[2, R] := '1';
  gridWhere.Cells[3, R] := 'AND';
end;

procedure TFormQueryBuilder.btnDeleteWhereClick(Sender: TObject);
begin
  if (gridWhere.RowCount > 1) and (gridWhere.Row >= 1) then
  begin
    gridWhere.DeleteRow(gridWhere.Row);
    gridWhereEditingDone(Sender);
  end;
end;

procedure TFormQueryBuilder.gridWhereEditingDone(Sender: TObject);
var
  I, DotPos: Integer;
  TargetStr, OpStr, ValStr, ConnStr, TAlias, ColName: string;
begin
  for I := 0 to FModel.Conditions.Count - 1 do
    TVisualCondition(FModel.Conditions[I]).Free;
  FModel.Conditions.Clear;

  for I := 1 to gridWhere.RowCount - 1 do
  begin
    TargetStr := Trim(gridWhere.Cells[0, I]);
    OpStr := Trim(gridWhere.Cells[1, I]);
    ValStr := Trim(gridWhere.Cells[2, I]);
    ConnStr := Trim(gridWhere.Cells[3, I]);

    DotPos := Pos('.', TargetStr);
    if DotPos > 0 then
    begin
      TAlias := Copy(TargetStr, 1, DotPos - 1);
      ColName := Copy(TargetStr, DotPos + 1, Length(TargetStr));
      FModel.AddCondition(TAlias, ColName, OpStr, ValStr, ConnStr);
    end;
  end;

  UpdateGeneratedSQL;
end;

procedure TFormQueryBuilder.chkDistinctChange(Sender: TObject);
begin
  UpdateGeneratedSQL;
end;

procedure TFormQueryBuilder.edtLimitChange(Sender: TObject);
begin
  UpdateGeneratedSQL;
end;

procedure TFormQueryBuilder.btnCopySQLClick(Sender: TObject);
begin
  Clipboard.AsText := synSQLPreview.Lines.Text;
  MessageDlg('Visual Query Builder', 'Kueri SQL berhasil disalin ke Clipboard.', mtInformation, [mbOK], 0);
end;

procedure TFormQueryBuilder.btnInsertToEditorClick(Sender: TObject);
begin
  UpdateGeneratedSQL;
  ModalResult := mrOk;
end;

procedure TFormQueryBuilder.btnResetBuilderClick(Sender: TObject);
var
  I: Integer;
begin
  FModel.Clear;
  for I := sbCanvas.ControlCount - 1 downto 0 do
    sbCanvas.Controls[I].Free;

  gridColumns.RowCount := 1;
  gridJoins.RowCount := 1;
  gridWhere.RowCount := 1;
  chkDistinct.Checked := False;
  edtLimit.Text := '';
  edtOffset.Text := '';
  UpdateGeneratedSQL;
  sbCanvas.Invalidate;
end;

end.
