unit uFormERDViewer;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Types, Math, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  ComCtrls, StdCtrls, Buttons, Clipbrd,
  uAppTypes, uDBTypes, uModelConnection, uERDModel, uERDService,
  uERDForwardEngine, uFormERDTableEditor;

type
  { TFormERDViewer }
  TFormERDViewer = class(TForm)
    pnlToolbar: TPanel;
    btnReverseDB: TSpeedButton;
    btnAddTable: TSpeedButton;
    btnEditTable: TSpeedButton;
    btnDeleteTable: TSpeedButton;
    btnForwardDDL: TSpeedButton;
    btnSyncToDB: TSpeedButton;
    btnAutoLayout: TSpeedButton;
    btnExportPNG: TSpeedButton;
    sepTool1: TBevel;
    sepTool2: TBevel;
    sepTool3: TBevel;

    lblSearch: TLabel;
    edtSearch: TEdit;
    chkShowTypes: TCheckBox;

    sbCanvas: TScrollBox;
    paintBox: TPaintBox;

    pnlSidebar: TPanel;
    splSidebar: TSplitter;
    lblTableTitle: TLabel;
    lvColumns: TListView;

    saveDialog: TSaveDialog;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);

    procedure paintBoxPaint(Sender: TObject);
    procedure paintBoxMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure paintBoxMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure paintBoxMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure paintBoxDblClick(Sender: TObject);

    procedure btnReverseDBClick(Sender: TObject);
    procedure btnAddTableClick(Sender: TObject);
    procedure btnEditTableClick(Sender: TObject);
    procedure btnDeleteTableClick(Sender: TObject);
    procedure btnForwardDDLClick(Sender: TObject);
    procedure btnSyncToDBClick(Sender: TObject);
    procedure btnAutoLayoutClick(Sender: TObject);
    procedure btnExportPNGClick(Sender: TObject);
    procedure edtSearchChange(Sender: TObject);
    procedure chkShowTypesChange(Sender: TObject);
  private
    FProfile: TConnectionProfile;
    FGraph: TERDGraph;
    FSelectedNode: TERDTableNode;
    FDraggingNode: TERDTableNode;
    FDragOffset: TPoint;

    procedure ReloadGraphFromDB;
    procedure RenderDiagram(ACanvas: TCanvas);
    procedure DrawTableNode(ACanvas: TCanvas; ANode: TERDTableNode);
    procedure DrawRelationLine(ACanvas: TCanvas; ARel: TERDRelation);
    procedure UpdateSidebar(ANode: TERDTableNode);
    procedure ExportToBitmap(ABmp: TBitmap);
    procedure RecalculateCanvasBounds;
  public
    class procedure Execute(AOwner: TComponent; AProfile: TConnectionProfile);
    property Profile: TConnectionProfile read FProfile write FProfile;
  end;

var
  FormERDViewer: TFormERDViewer;

implementation

{$R *.lfm}

{ TFormERDViewer }

class procedure TFormERDViewer.Execute(AOwner: TComponent; AProfile: TConnectionProfile);
var
  Frm: TFormERDViewer;
begin
  Frm := TFormERDViewer.Create(AOwner);
  try
    Frm.Profile := AProfile;
    Frm.ShowModal;
  finally
    Frm.Free;
  end;
end;

procedure TFormERDViewer.FormCreate(Sender: TObject);
begin
  FGraph := TERDGraph.Create;
  FSelectedNode := nil;
  FDraggingNode := nil;
  sbCanvas.DoubleBuffered := True;
end;

procedure TFormERDViewer.FormDestroy(Sender: TObject);
begin
  if Assigned(FGraph) then
    FreeAndNil(FGraph);
end;

procedure TFormERDViewer.FormShow(Sender: TObject);
begin
  if Assigned(FProfile) then
  begin
    Caption := Format('Two-Way ERD Modeler (Forward & Reverse) - %s', [FProfile.ConnectionName]);
    ReloadGraphFromDB;
  end;
end;

procedure TFormERDViewer.RecalculateCanvasBounds;
var
  TotalBounds: TRect;
begin
  if not Assigned(FGraph) then Exit;
  TotalBounds := FGraph.GetTotalBounds;
  paintBox.Width := Max(sbCanvas.ClientWidth, TotalBounds.Right + 120);
  paintBox.Height := Max(sbCanvas.ClientHeight, TotalBounds.Bottom + 120);
  paintBox.Invalidate;
end;

procedure TFormERDViewer.ReloadGraphFromDB;
var
  Err: string;
begin
  if Assigned(FGraph) then
    FreeAndNil(FGraph);

  FSelectedNode := nil;
  UpdateSidebar(nil);

  Screen.Cursor := crHourGlass;
  try
    if TERDService.BuildGraph(FProfile, '', paintBox.Canvas, FGraph, Err) then
    begin
      RecalculateCanvasBounds;
    end
    else
      MessageDlg('Gagal Reverse Engineering', Err, mtError, [mbOK], 0);
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFormERDViewer.DrawTableNode(ACanvas: TCanvas; ANode: TERDTableNode);
var
  R, HRect, RowRect: TRect;
  I, RowY: Integer;
  Col: TERDColumn;
  Prefix, ColStr: string;
begin
  R := ANode.Bounds;

  // 1. Soft Shadow
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := $00E2E8F0;
  ACanvas.Pen.Style := psClear;
  ACanvas.RoundRect(R.Left + 3, R.Top + 3, R.Right + 3, R.Bottom + 3, 10, 10);

  // 2. Card Background
  if ANode.IsSelected then
    ACanvas.Brush.Color := $00FFFBEB
  else
    ACanvas.Brush.Color := clWhite;

  ACanvas.Pen.Style := psSolid;
  if ANode.IsSelected then
  begin
    ACanvas.Pen.Color := $002563EB;
    ACanvas.Pen.Width := 2;
  end
  else
  begin
    ACanvas.Pen.Color := $00CBD5E1;
    ACanvas.Pen.Width := 1;
  end;
  ACanvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, 10, 10);

  // 3. Header Tabel
  HRect := Rect(R.Left, R.Top, R.Right, R.Top + 28);
  if ANode.IsSelected then
    ACanvas.Brush.Color := $001D4ED8
  else
    ACanvas.Brush.Color := $00334155;

  ACanvas.Pen.Style := psClear;
  ACanvas.RoundRect(HRect.Left, HRect.Top, HRect.Right, HRect.Bottom, 10, 10);
  ACanvas.FillRect(Rect(HRect.Left, HRect.Top + 14, HRect.Right, HRect.Bottom));

  ACanvas.Brush.Style := bsClear;
  ACanvas.Font.Style := [fsBold];
  ACanvas.Font.Color := clWhite;
  ACanvas.Font.Size := 9;
  ACanvas.TextOut(HRect.Left + 12, HRect.Top + 6, ANode.Name);

  // 4. Baris Kolom
  for I := 0 to ANode.ColumnCount - 1 do
  begin
    Col := ANode.Columns[I];
    RowY := R.Top + 28 + (I * 20);
    RowRect := Rect(R.Left + 4, RowY, R.Right - 4, RowY + 20);

    if I > 0 then
    begin
      ACanvas.Pen.Style := psSolid;
      ACanvas.Pen.Color := $00F1F5F9;
      ACanvas.Pen.Width := 1;
      ACanvas.Line(R.Left + 6, RowY, R.Right - 6, RowY);
    end;

    ACanvas.Brush.Style := bsClear;
    if Col.IsPK then
    begin
      Prefix := '🔑 ';
      ACanvas.Font.Style := [fsBold];
      ACanvas.Font.Color := $00B45309;
    end
    else
    begin
      Prefix := '   ';
      ACanvas.Font.Style := [];
      ACanvas.Font.Color := $001E293B;
    end;

    ACanvas.Font.Size := 8;
    ACanvas.TextOut(RowRect.Left + 6, RowRect.Top + 3, Prefix + Col.Name);

    if chkShowTypes.Checked then
    begin
      ACanvas.Font.Style := [];
      ACanvas.Font.Color := $0064748B;
      ColStr := Col.DataType;
      ACanvas.TextOut(RowRect.Right - ACanvas.TextWidth(ColStr) - 8, RowRect.Top + 3, ColStr);
    end;
  end;
end;

procedure TFormERDViewer.DrawRelationLine(ACanvas: TCanvas; ARel: TERDRelation);
var
  Pt1, Pt2, Mid1, Mid2: TPoint;
  SrcNode, TgtNode: TERDTableNode;
  SrcY, TgtY: Integer;
begin
  SrcNode := ARel.SourceNode;
  TgtNode := ARel.TargetNode;
  if not Assigned(SrcNode) or not Assigned(TgtNode) then Exit;

  SrcY := SrcNode.GetColumnY(ARel.SourceColumn);
  TgtY := TgtNode.GetColumnY(ARel.TargetColumn);

  if SrcNode.Bounds.Left > TgtNode.Bounds.Right then
  begin
    Pt1 := Point(SrcNode.Bounds.Left, SrcY);
    Pt2 := Point(TgtNode.Bounds.Right, TgtY);
    Mid1 := Point(Pt1.X - 25, Pt1.Y);
    Mid2 := Point(Pt2.X + 25, Pt2.Y);
  end
  else if SrcNode.Bounds.Right < TgtNode.Bounds.Left then
  begin
    Pt1 := Point(SrcNode.Bounds.Right, SrcY);
    Pt2 := Point(TgtNode.Bounds.Left, TgtY);
    Mid1 := Point(Pt1.X + 25, Pt1.Y);
    Mid2 := Point(Pt2.X - 25, Pt2.Y);
  end
  else
  begin
    Pt1 := Point(SrcNode.Bounds.Right, SrcY);
    Pt2 := Point(TgtNode.Bounds.Right, TgtY);
    Mid1 := Point(Max(Pt1.X, Pt2.X) + 30, Pt1.Y);
    Mid2 := Point(Max(Pt1.X, Pt2.X) + 30, Pt2.Y);
  end;

  ACanvas.Pen.Style := psSolid;
  if (SrcNode.IsSelected) or (TgtNode.IsSelected) then
  begin
    ACanvas.Pen.Color := $002563EB;
    ACanvas.Pen.Width := 2;
  end
  else
  begin
    ACanvas.Pen.Color := $0094A3B8;
    ACanvas.Pen.Width := 1;
  end;

  ACanvas.MoveTo(Pt1.X, Pt1.Y);
  ACanvas.LineTo(Mid1.X, Mid1.Y);
  ACanvas.LineTo(Mid2.X, Mid2.Y);
  ACanvas.LineTo(Pt2.X, Pt2.Y);

  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := ACanvas.Pen.Color;
  ACanvas.Ellipse(Pt1.X - 3, Pt1.Y - 3, Pt1.X + 3, Pt1.Y + 3);
  ACanvas.Rectangle(Pt2.X - 3, Pt2.Y - 3, Pt2.X + 3, Pt2.Y + 3);
end;

procedure TFormERDViewer.RenderDiagram(ACanvas: TCanvas);
var
  I, X, Y, GridStep: Integer;
begin
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := $00F8FAFC;
  ACanvas.FillRect(Rect(0, 0, paintBox.Width, paintBox.Height));

  ACanvas.Pen.Color := $00E2E8F0;
  GridStep := 24;
  X := 0;
  while X < paintBox.Width do
  begin
    Y := 0;
    while Y < paintBox.Height do
    begin
      ACanvas.Pixels[X, Y] := $00CBD5E1;
      Inc(Y, GridStep);
    end;
    Inc(X, GridStep);
  end;

  if not Assigned(FGraph) then Exit;

  for I := 0 to FGraph.RelationCount - 1 do
    DrawRelationLine(ACanvas, FGraph.Relations[I]);

  for I := 0 to FGraph.NodeCount - 1 do
    DrawTableNode(ACanvas, FGraph.Nodes[I]);
end;

procedure TFormERDViewer.paintBoxPaint(Sender: TObject);
begin
  RenderDiagram(paintBox.Canvas);
end;

procedure TFormERDViewer.paintBoxMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  ClickedNode: TERDTableNode;
  I: Integer;
begin
  if not Assigned(FGraph) then Exit;

  ClickedNode := FGraph.FindNodeAt(Point(X, Y));
  if Button = mbLeft then
  begin
    for I := 0 to FGraph.NodeCount - 1 do
      FGraph.Nodes[I].IsSelected := False;

    if Assigned(ClickedNode) then
    begin
      ClickedNode.IsSelected := True;
      FSelectedNode := ClickedNode;
      UpdateSidebar(FSelectedNode);

      FDraggingNode := ClickedNode;
      FDragOffset := Point(X - ClickedNode.Bounds.Left, Y - ClickedNode.Bounds.Top);
    end
    else
    begin
      FSelectedNode := nil;
      UpdateSidebar(nil);
    end;

    paintBox.Invalidate;
  end;
end;

procedure TFormERDViewer.paintBoxMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  W, H: Integer;
begin
  if (ssLeft in Shift) and Assigned(FDraggingNode) then
  begin
    W := FDraggingNode.Bounds.Right - FDraggingNode.Bounds.Left;
    H := FDraggingNode.Bounds.Bottom - FDraggingNode.Bounds.Top;

    FDraggingNode.Bounds := Rect(
      Max(10, X - FDragOffset.X),
      Max(10, Y - FDragOffset.Y),
      Max(10, X - FDragOffset.X) + W,
      Max(10, Y - FDragOffset.Y) + H
    );

    RecalculateCanvasBounds;
  end;
end;

procedure TFormERDViewer.paintBoxMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FDraggingNode := nil;
end;

procedure TFormERDViewer.paintBoxDblClick(Sender: TObject);
begin
  if Assigned(FSelectedNode) then
    btnEditTableClick(Sender);
end;

procedure TFormERDViewer.UpdateSidebar(ANode: TERDTableNode);
var
  I: Integer;
  Item: TListItem;
  Col: TERDColumn;
begin
  lvColumns.Items.BeginUpdate;
  try
    lvColumns.Items.Clear;
    if not Assigned(ANode) then
    begin
      lblTableTitle.Caption := 'Pilih sebuah tabel';
      btnEditTable.Enabled := False;
      btnDeleteTable.Enabled := False;
      Exit;
    end;

    btnEditTable.Enabled := True;
    btnDeleteTable.Enabled := True;
    lblTableTitle.Caption := Format('Tabel: %s (%d kolom)', [ANode.Name, ANode.ColumnCount]);

    for I := 0 to ANode.ColumnCount - 1 do
    begin
      Col := ANode.Columns[I];
      Item := lvColumns.Items.Add;
      Item.Caption := Col.Name;
      Item.SubItems.Add(Col.DataType);
      if Col.IsPK then Item.SubItems.Add('PK')
      else if Col.IsFK then Item.SubItems.Add('FK')
      else Item.SubItems.Add('-');
    end;
  finally
    lvColumns.Items.EndUpdate;
  end;
end;

procedure TFormERDViewer.ExportToBitmap(ABmp: TBitmap);
var
  TotalB: TRect;
begin
  if not Assigned(FGraph) then Exit;
  TotalB := FGraph.GetTotalBounds;
  ABmp.SetSize(TotalB.Right + 40, TotalB.Bottom + 40);
  RenderDiagram(ABmp.Canvas);
end;

procedure TFormERDViewer.btnReverseDBClick(Sender: TObject);
begin
  ReloadGraphFromDB;
end;

procedure TFormERDViewer.btnAddTableClick(Sender: TObject);
var
  NewNode: TERDTableNode;
begin
  NewNode := TERDTableNode.Create('tabel_baru_' + IntToStr(FGraph.NodeCount + 1));
  NewNode.AddColumn('id', 'INT', True, False);
  NewNode.AddColumn('nama', 'VARCHAR(100)', False, False);
  NewNode.Bounds := Rect(40 + (FGraph.NodeCount * 30), 40 + (FGraph.NodeCount * 30),
                         220 + (FGraph.NodeCount * 30), 160 + (FGraph.NodeCount * 30));

  if TFormERDTableEditor.ExecuteEditor(Self, NewNode) then
  begin
    FGraph.AddNode(NewNode);
    FSelectedNode := NewNode;
    UpdateSidebar(FSelectedNode);
    RecalculateCanvasBounds;
  end
  else
    NewNode.Free;
end;

procedure TFormERDViewer.btnEditTableClick(Sender: TObject);
begin
  if Assigned(FSelectedNode) then
  begin
    if TFormERDTableEditor.ExecuteEditor(Self, FSelectedNode) then
    begin
      UpdateSidebar(FSelectedNode);
      paintBox.Invalidate;
    end;
  end;
end;

procedure TFormERDViewer.btnDeleteTableClick(Sender: TObject);
var
  I: Integer;
begin
  if not Assigned(FSelectedNode) then Exit;

  if MessageDlg('Konfirmasi', Format('Hapus tabel model "%s" dari diagram kanvas?', [FSelectedNode.Name]),
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    for I := FGraph.RelationCount - 1 downto 0 do
    begin
      if (FGraph.Relations[I].SourceNode = FSelectedNode) or
         (FGraph.Relations[I].TargetNode = FSelectedNode) then
        FGraph.DeleteRelation(I);
    end;

    FGraph.DeleteNode(FSelectedNode);
    FSelectedNode := nil;
    UpdateSidebar(nil);
    paintBox.Invalidate;
  end;
end;

procedure TFormERDViewer.btnForwardDDLClick(Sender: TObject);
var
  DDL: string;
begin
  if not Assigned(FGraph) or (FGraph.NodeCount = 0) then
  begin
    MessageDlg('Informasi', 'The ERD diagram is empty. Please add tables first.', mtInformation, [mbOK], 0);
    Exit;
  end;

  DDL := TERDForwardEngine.GenerateDDLScript(FGraph, FProfile.DriverType, FProfile.DatabaseName);
  Clipboard.AsText := DDL;
  MessageDlg('Forward Engineering DDL Successful',
    'DDL script successfully generated and copied to the clipboard!' + sLineBreak + sLineBreak +
    Copy(DDL, 1, 350) + '...', mtInformation, [mbOK], 0);
end;

procedure TFormERDViewer.btnSyncToDBClick(Sender: TObject);
var
  DDL, Err: string;
begin
  if not Assigned(FGraph) or (FGraph.NodeCount = 0) then Exit;

  if MessageDlg('Forward Sync Confirmation',
    'The canvas diagram model will be compiled and applied directly to the physical database' + sLineBreak +
    'Ensure the target database schema has been backed up. Proceed?',
    mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;

  DDL := TERDForwardEngine.GenerateDDLScript(FGraph, FProfile.DriverType, FProfile.DatabaseName);

  Screen.Cursor := crHourGlass;
  try
    if TERDForwardEngine.ExecuteForwardToDB(FProfile, FProfile.DatabaseName, DDL, Err) then
      MessageDlg('Synchronization Successful', 'Table structure and relationships successfully created in the target database!', mtInformation, [mbOK], 0)
    else
      MessageDlg('Failed to Apply DDL', Err, mtError, [mbOK], 0);
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFormERDViewer.btnAutoLayoutClick(Sender: TObject);
begin
  if not Assigned(FGraph) then Exit;
  FGraph.AutoLayout(sbCanvas.ClientWidth - 20, paintBox.Canvas);
  RecalculateCanvasBounds;
end;

procedure TFormERDViewer.btnExportPNGClick(Sender: TObject);
var
  Bmp: TBitmap;
begin
  if not Assigned(FGraph) or (FGraph.NodeCount = 0) then Exit;

  saveDialog.DefaultExt := '.bmp';
  saveDialog.Filter := 'BMP Image (*.bmp)|*.bmp|All Files (*.*)|*.*';
  saveDialog.FileName := Format('erd_model_%s.bmp', [FormatDateTime('yyyymmdd_hhnnss', Now)]);

  if saveDialog.Execute then
  begin
    Bmp := TBitmap.Create;
    try
      ExportToBitmap(Bmp);
      Bmp.SaveToFile(saveDialog.FileName);
      MessageDlg('Success', 'ERD diagram successfully exported.', mtInformation, [mbOK], 0);
    finally
      Bmp.Free;
    end;
  end;
end;

procedure TFormERDViewer.edtSearchChange(Sender: TObject);
var
  I: Integer;
  FilterText: string;
begin
  if not Assigned(FGraph) then Exit;

  FilterText := LowerCase(Trim(edtSearch.Text));
  for I := 0 to FGraph.NodeCount - 1 do
  begin
    if (FilterText <> '') and (Pos(FilterText, LowerCase(FGraph.Nodes[I].Name)) > 0) then
      FGraph.Nodes[I].IsSelected := True
    else if FilterText <> '' then
      FGraph.Nodes[I].IsSelected := False;
  end;

  paintBox.Invalidate;
end;

procedure TFormERDViewer.chkShowTypesChange(Sender: TObject);
begin
  paintBox.Invalidate;
end;

end.
