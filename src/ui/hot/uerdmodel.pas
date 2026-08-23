unit uERDModel;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Types, Graphics, Math;

type
  { TERDColumn }
  TERDColumn = class
  public
    Name: string;
    DataType: string;
    IsPK: Boolean;
    IsFK: Boolean;
  end;

  { TERDTableNode }
  TERDTableNode = class
  private
    FColumns: TList;
    function GetColumnCount: Integer;
    function GetColumn(Index: Integer): TERDColumn;
  public
    Name: string;
    SchemaName: string;
    Bounds: TRect;
    HeaderColor: TColor;
    IsSelected: Boolean;
    IsHovered: Boolean;

    constructor Create(const AName: string; const ASchema: string = '');
    destructor Destroy; override;

    procedure AddColumn(const AName, ADataType: string; const AIsPK: Boolean = False; const AIsFK: Boolean = False);
    procedure ClearColumns;
    procedure CalculateBounds(const AX, AY: Integer; ACanvas: TCanvas);
    function GetColumnY(const AColName: string): Integer;
    function ContainsPoint(const Pt: TPoint): Boolean;
    function HeaderContainsPoint(const Pt: TPoint): Boolean;

    property ColumnCount: Integer read GetColumnCount;
    property Columns[Index: Integer]: TERDColumn read GetColumn;
  end;

  { TERDRelation }
  TERDRelation = class
  public
    FKName: string;
    SourceTable: string;
    SourceColumn: string;
    TargetTable: string;
    TargetColumn: string;
    SourceNode: TERDTableNode;
    TargetNode: TERDTableNode;
  end;

  { TERDGraph }
  TERDGraph = class
  private
    FNodes: TList;
    FRelations: TList;
    function GetNodeCount: Integer;
    function GetNode(Index: Integer): TERDTableNode;
    function GetRelationCount: Integer;
    function GetRelation(Index: Integer): TERDRelation;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;
    function AddNode(const AName: string; const ASchema: string = ''): TERDTableNode; overload;
    function AddNode(ANode: TERDTableNode): TERDTableNode; overload;
    procedure DeleteNode(ANode: TERDTableNode); overload;
    procedure DeleteNode(const AIndex: Integer); overload;
    function FindNode(const AName: string): TERDTableNode;

    procedure AddRelation(const AFKName, ASrcTable, ASrcCol, ATgtTable, ATgtCol: string);
    procedure DeleteRelation(const AIndex: Integer); overload;
    procedure DeleteRelation(ARel: TERDRelation); overload;
    procedure ResolveRelationNodes;

    procedure AutoLayout(const ACanvasWidth: Integer; ACanvas: TCanvas);
    function FindNodeAt(const Pt: TPoint): TERDTableNode;
    function GetTotalBounds: TRect;

    property NodeCount: Integer read GetNodeCount;
    property Nodes[Index: Integer]: TERDTableNode read GetNode;
    property RelationCount: Integer read GetRelationCount;
    property Relations[Index: Integer]: TERDRelation read GetRelation;
  end;

implementation

{ TERDTableNode }

constructor TERDTableNode.Create(const AName: string; const ASchema: string);
begin
  inherited Create;
  Name := AName;
  SchemaName := ASchema;
  FColumns := TList.Create;
  HeaderColor := $00C06010;
  IsSelected := False;
  IsHovered := False;
  Bounds := Rect(0, 0, 180, 80);
end;

destructor TERDTableNode.Destroy;
begin
  ClearColumns;
  FColumns.Free;
  inherited Destroy;
end;

procedure TERDTableNode.ClearColumns;
var
  I: Integer;
begin
  for I := 0 to FColumns.Count - 1 do
    TERDColumn(FColumns[I]).Free;
  FColumns.Clear;
end;

function TERDTableNode.GetColumnCount: Integer;
begin
  Result := FColumns.Count;
end;

function TERDTableNode.GetColumn(Index: Integer): TERDColumn;
begin
  Result := TERDColumn(FColumns[Index]);
end;

procedure TERDTableNode.AddColumn(const AName, ADataType: string; const AIsPK: Boolean; const AIsFK: Boolean);
var
  Col: TERDColumn;
begin
  Col := TERDColumn.Create;
  Col.Name := AName;
  Col.DataType := ADataType;
  Col.IsPK := AIsPK;
  Col.IsFK := AIsFK;
  FColumns.Add(Col);
end;

procedure TERDTableNode.CalculateBounds(const AX, AY: Integer; ACanvas: TCanvas);
var
  I, MaxW, TextW: Integer;
  LineStr: string;
begin
  MaxW := ACanvas.TextWidth(Name) + 40;
  for I := 0 to FColumns.Count - 1 do
  begin
    LineStr := Columns[I].Name + ' : ' + Columns[I].DataType;
    TextW := ACanvas.TextWidth(LineStr) + 48;
    if TextW > MaxW then
      MaxW := TextW;
  end;

  if MaxW < 180 then MaxW := 180;
  if MaxW > 320 then MaxW := 320;

  Bounds := Rect(AX, AY, AX + MaxW, AY + 28 + (FColumns.Count * 20) + 6);
end;

function TERDTableNode.GetColumnY(const AColName: string): Integer;
var
  I: Integer;
begin
  Result := Bounds.Top + 38;
  for I := 0 to FColumns.Count - 1 do
  begin
    if SameText(Columns[I].Name, AColName) then
    begin
      Result := Bounds.Top + 28 + (I * 20) + 10;
      Exit;
    end;
  end;
end;

function TERDTableNode.ContainsPoint(const Pt: TPoint): Boolean;
begin
  Result := PtInRect(Bounds, Pt);
end;

function TERDTableNode.HeaderContainsPoint(const Pt: TPoint): Boolean;
var
  HRect: TRect;
begin
  HRect := Rect(Bounds.Left, Bounds.Top, Bounds.Right, Bounds.Top + 28);
  Result := PtInRect(HRect, Pt);
end;

{ TERDGraph }

constructor TERDGraph.Create;
begin
  inherited Create;
  FNodes := TList.Create;
  FRelations := TList.Create;
end;

destructor TERDGraph.Destroy;
begin
  Clear;
  FNodes.Free;
  FRelations.Free;
  inherited Destroy;
end;

procedure TERDGraph.Clear;
var
  I: Integer;
begin
  for I := 0 to FNodes.Count - 1 do
    TERDTableNode(FNodes[I]).Free;
  FNodes.Clear;

  for I := 0 to FRelations.Count - 1 do
    TERDRelation(FRelations[I]).Free;
  FRelations.Clear;
end;

function TERDGraph.GetNodeCount: Integer;
begin
  Result := FNodes.Count;
end;

function TERDGraph.GetNode(Index: Integer): TERDTableNode;
begin
  Result := TERDTableNode(FNodes[Index]);
end;

function TERDGraph.GetRelationCount: Integer;
begin
  Result := FRelations.Count;
end;

function TERDGraph.GetRelation(Index: Integer): TERDRelation;
begin
  Result := TERDRelation(FRelations[Index]);
end;

function TERDGraph.AddNode(const AName: string; const ASchema: string): TERDTableNode;
begin
  Result := TERDTableNode.Create(AName, ASchema);
  FNodes.Add(Result);
end;

function TERDGraph.AddNode(ANode: TERDTableNode): TERDTableNode;
begin
  if Assigned(ANode) then
    FNodes.Add(ANode);
  Result := ANode;
end;

procedure TERDGraph.DeleteNode(const AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex < FNodes.Count) then
  begin
    TERDTableNode(FNodes[AIndex]).Free;
    FNodes.Delete(AIndex);
  end;
end;

procedure TERDGraph.DeleteNode(ANode: TERDTableNode);
var
  Idx: Integer;
begin
  Idx := FNodes.IndexOf(ANode);
  if Idx >= 0 then
    DeleteNode(Idx);
end;

function TERDGraph.FindNode(const AName: string): TERDTableNode;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FNodes.Count - 1 do
  begin
    if SameText(TERDTableNode(FNodes[I]).Name, AName) then
    begin
      Result := TERDTableNode(FNodes[I]);
      Exit;
    end;
  end;
end;

procedure TERDGraph.AddRelation(const AFKName, ASrcTable, ASrcCol, ATgtTable, ATgtCol: string);
var
  Rel: TERDRelation;
begin
  Rel := TERDRelation.Create;
  Rel.FKName := AFKName;
  Rel.SourceTable := ASrcTable;
  Rel.SourceColumn := ASrcCol;
  Rel.TargetTable := ATgtTable;
  Rel.TargetColumn := ATgtCol;
  Rel.SourceNode := nil;
  Rel.TargetNode := nil;
  FRelations.Add(Rel);
end;

procedure TERDGraph.DeleteRelation(const AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex < FRelations.Count) then
  begin
    TERDRelation(FRelations[AIndex]).Free;
    FRelations.Delete(AIndex);
  end;
end;

procedure TERDGraph.DeleteRelation(ARel: TERDRelation);
var
  Idx: Integer;
begin
  Idx := FRelations.IndexOf(ARel);
  if Idx >= 0 then
    DeleteRelation(Idx);
end;

procedure TERDGraph.ResolveRelationNodes;
var
  I: Integer;
  Rel: TERDRelation;
begin
  for I := 0 to FRelations.Count - 1 do
  begin
    Rel := TERDRelation(FRelations[I]);
    Rel.SourceNode := FindNode(Rel.SourceTable);
    Rel.TargetNode := FindNode(Rel.TargetTable);
  end;
end;

procedure TERDGraph.AutoLayout(const ACanvasWidth: Integer; ACanvas: TCanvas);
var
  I, CurX, CurY, MaxRowH, ColWidth, SpacingX, SpacingY: Integer;
  N: TERDTableNode;
begin
  CurX := 40;
  CurY := 40;
  MaxRowH := 0;
  SpacingX := 45;
  SpacingY := 40;

  for I := 0 to FNodes.Count - 1 do
  begin
    N := TERDTableNode(FNodes[I]);
    N.CalculateBounds(CurX, CurY, ACanvas);
    ColWidth := N.Bounds.Right - N.Bounds.Left;

    if (N.Bounds.Bottom - N.Bounds.Top) > MaxRowH then
      MaxRowH := N.Bounds.Bottom - N.Bounds.Top;

    CurX := CurX + ColWidth + SpacingX;

    if (CurX + 220 > ACanvasWidth) and (I < FNodes.Count - 1) then
    begin
      CurX := 40;
      CurY := CurY + MaxRowH + SpacingY;
      MaxRowH := 0;
    end;
  end;
end;

function TERDGraph.FindNodeAt(const Pt: TPoint): TERDTableNode;
var
  I: Integer;
begin
  Result := nil;
  for I := FNodes.Count - 1 downto 0 do
  begin
    if TERDTableNode(FNodes[I]).ContainsPoint(Pt) then
    begin
      Result := TERDTableNode(FNodes[I]);
      Exit;
    end;
  end;
end;

function TERDGraph.GetTotalBounds: TRect;
var
  I: Integer;
  N: TERDTableNode;
begin
  Result := Rect(0, 0, 800, 600);
  for I := 0 to FNodes.Count - 1 do
  begin
    N := TERDTableNode(FNodes[I]);
    if N.Bounds.Right + 50 > Result.Right then Result.Right := N.Bounds.Right + 50;
    if N.Bounds.Bottom + 50 > Result.Bottom then Result.Bottom := N.Bounds.Bottom + 50;
  end;
end;

end.
