unit uFormERDTableEditor;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Buttons, Grids,
  uERDModel;

type
  { TFormERDTableEditor }
  TFormERDTableEditor = class(TForm)
    pnlHeader: TPanel;
    lblTableName: TLabel;
    edtTableName: TEdit;

    pnlBottom: TPanel;
    btnOK: TBitBtn;
    btnCancel: TBitBtn;

    pnlGridToolbar: TPanel;
    btnAddCol: TSpeedButton;
    btnDelCol: TSpeedButton;
    gridCols: TStringGrid;

    procedure FormCreate(Sender: TObject);
    procedure btnAddColClick(Sender: TObject);
    procedure btnDelColClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
  private
    FNode: TERDTableNode;
    procedure LoadNodeData;
    procedure SaveToNode;
  public
    class function ExecuteEditor(AOwner: TComponent; ANode: TERDTableNode): Boolean;
    property Node: TERDTableNode read FNode write FNode;
  end;

implementation

{$R *.lfm}

{ TFormERDTableEditor }

class function TFormERDTableEditor.ExecuteEditor(AOwner: TComponent; ANode: TERDTableNode): Boolean;
var
  Dlg: TFormERDTableEditor;
begin
  Dlg := TFormERDTableEditor.Create(AOwner);
  try
    Dlg.Node := ANode;
    Dlg.LoadNodeData;
    Result := (Dlg.ShowModal = mrOk);
    if Result then
      Dlg.SaveToNode;
  finally
    Dlg.Free;
  end;
end;

procedure TFormERDTableEditor.FormCreate(Sender: TObject);
begin
  gridCols.ColCount := 3;
  gridCols.RowCount := 1;
  gridCols.Cells[0, 0] := 'Nama Kolom';
  gridCols.Cells[1, 0] := 'Tipe Data (e.g. INT, VARCHAR(100))';
  gridCols.Cells[2, 0] := 'Primary Key (Y/N)';
  gridCols.ColWidths[0] := 180;
  gridCols.ColWidths[1] := 220;
  gridCols.ColWidths[2] := 110;
end;

procedure TFormERDTableEditor.LoadNodeData;
var
  I, RowIdx: Integer;
  Col: TERDColumn;
begin
  if not Assigned(FNode) then Exit;

  edtTableName.Text := FNode.Name;
  gridCols.RowCount := 1;
  gridCols.RowCount := FNode.ColumnCount + 1;

  for I := 0 to FNode.ColumnCount - 1 do
  begin
    Col := FNode.Columns[I];
    RowIdx := I + 1;
    gridCols.Cells[0, RowIdx] := Col.Name;
    gridCols.Cells[1, RowIdx] := Col.DataType;
    if Col.IsPK then
      gridCols.Cells[2, RowIdx] := 'Y'
    else
      gridCols.Cells[2, RowIdx] := 'N';
  end;
end;

procedure TFormERDTableEditor.SaveToNode;
var
  RowIdx: Integer;
  ColName, DType, PKStr: string;
  IsPK: Boolean;
begin
  if not Assigned(FNode) then Exit;

  FNode.Name := Trim(edtTableName.Text);
  FNode.ClearColumns;

  for RowIdx := 1 to gridCols.RowCount - 1 do
  begin
    ColName := Trim(gridCols.Cells[0, RowIdx]);
    DType := Trim(gridCols.Cells[1, RowIdx]);
    PKStr := UpperCase(Trim(gridCols.Cells[2, RowIdx]));

    if ColName <> '' then
    begin
      if DType = '' then DType := 'VARCHAR(255)';
      IsPK := (PKStr = 'Y') or (PKStr = 'YES') or (PKStr = 'TRUE') or (PKStr = '1');
      FNode.AddColumn(ColName, DType, IsPK, False);
    end;
  end;
end;

procedure TFormERDTableEditor.btnAddColClick(Sender: TObject);
var
  NewRow: Integer;
begin
  gridCols.RowCount := gridCols.RowCount + 1;
  NewRow := gridCols.RowCount - 1;
  gridCols.Cells[0, NewRow] := 'column_' + IntToStr(NewRow);
  gridCols.Cells[1, NewRow] := 'VARCHAR(255)';
  gridCols.Cells[2, NewRow] := 'N';
end;

procedure TFormERDTableEditor.btnDelColClick(Sender: TObject);
begin
  if gridCols.RowCount > 2 then
    gridCols.DeleteRow(gridCols.Row);
end;

procedure TFormERDTableEditor.btnOKClick(Sender: TObject);
begin
  if Trim(edtTableName.Text) = '' then
  begin
    MessageDlg('Validasi', 'Nama tabel tidak boleh kosong.', mtWarning, [mbOK], 0);
    edtTableName.SetFocus;
    Exit;
  end;
  ModalResult := mrOk;
end;

end.
