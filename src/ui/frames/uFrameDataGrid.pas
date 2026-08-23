unit uFrameDataGrid;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Types, LCLIntf, LCLType, Forms, Controls, Graphics, Dialogs,
  DB, DBGrids, Grids, ExtCtrls, StdCtrls, Buttons, Menus, Clipbrd,
  ZDataset, ZAbstractRODataset, uFormRecordView,
  uAppConst, uAppTypes, uDBTypes, uExportService, uExportWorkerThread,
  uFrameValueInspector,uGridConfig;

type
  { Tipe Mode Filter }
  TGridFilterMode = (gfmNone, gfmGlobalSearch, gfmFieldOp, gfmIsNull, gfmIsNotNull);

  { Event Eksternal }
  TPageChangeEvent = procedure(Sender: TObject; const ANewPage: Integer) of object;
  TFilterApplyEvent = procedure(Sender: TObject; const AFilterCondition: string) of object;

  { TFrameDataGrid }
  TFrameDataGrid = class(TFrame)
    btnFormView: TButton;
    CheckBox1: TCheckBox;
    pnlToolbar: TPanel;
    pnlFooter: TPanel;
    dbGrid: TDBGrid;
    srcData: TDataSource;

    // Panel Inspektor Samping
    splInspector: TSplitter;
    pnlInspectorContainer: TPanel;
    btnToggleInspector: TSpeedButton;
    sepTool3: TBevel;

    // Tombol & Kontrol Toolbar
    btnFirstPage: TSpeedButton;
    btnPriorPage: TSpeedButton;
    btnNextPage: TSpeedButton;
    btnLastPage: TSpeedButton;
    btnRefresh: TSpeedButton;
    btnExport: TSpeedButton;
    sepTool1: TBevel;
    sepTool2: TBevel;
    lblPageInfo: TLabel;
    edtFilter: TEdit;
    btnFilter: TSpeedButton;
    btnClearFilter: TSpeedButton;

    // Komponen Status Footer
    lblRecordCount: TLabel;
    lblExecTime: TLabel;
    lblSelectedCell: TLabel;

    // Menu Konteks & Dialog
    popGrid: TPopupMenu;
    popExport: TPopupMenu;
    mnuCopyCell: TMenuItem;
    mnuCopyRow: TMenuItem;
    mnuCopyAllCSV: TMenuItem;
    mnuSep1: TMenuItem;
    mnuInspectCell: TMenuItem;
    mnuFilterByValue: TMenuItem;
    mnuClearFilter: TMenuItem;
    mnuSep2: TMenuItem;
    mnuExportData: TMenuItem;

    // Item Menu Popup Ekspor
    mnuExpCSV: TMenuItem;
    mnuExpJSON: TMenuItem;
    mnuExpSQL: TMenuItem;
    mnuExpHTML: TMenuItem;
    mnuExpMarkdown: TMenuItem;
    mnuExpXML: TMenuItem;

    saveDialog: TSaveDialog;

    procedure btnFirstPageClick(Sender: TObject);
    procedure btnPriorPageClick(Sender: TObject);
    procedure btnNextPageClick(Sender: TObject);
    procedure btnLastPageClick(Sender: TObject);
    procedure btnRefreshClick(Sender: TObject);
    procedure btnExportClick(Sender: TObject);
    procedure btnFilterClick(Sender: TObject);
    procedure btnClearFilterClick(Sender: TObject);
    procedure btnToggleInspectorClick(Sender: TObject);
    procedure CheckBox1Change(Sender: TObject);
    procedure edtFilterKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);

    procedure dbGridDrawColumnCell(Sender: TObject; const Rect: TRect; DataCol: Integer; Column: TColumn; State: TGridDrawState);
    procedure dbGridTitleClick(Column: TColumn);
    procedure dbGridDblClick(Sender: TObject);
    procedure srcDataDataChange(Sender: TObject; Field: TField);

    procedure mnuCopyCellClick(Sender: TObject);
    procedure mnuCopyRowClick(Sender: TObject);
    procedure mnuCopyAllCSVClick(Sender: TObject);
    procedure mnuFilterByValueClick(Sender: TObject);
    procedure mnuInspectCellClick(Sender: TObject);
    procedure mnuExportOptionClick(Sender: TObject);
    procedure btnFormViewClick(Sender: TObject);
  private
    FDataSet: TZQuery;
    FCurrentPage: Integer;
    FTotalPages: Integer;
    FPageSize: Integer;
    FTotalRecords: Int64;
    FExecutionTimeMS: Int64;
    FSortField: string;
    FSortAscending: Boolean;

    // Komponen Inspektor
    FInspectorFrame: TFrameValueInspector;

    // State Mesin Filter
    FFilterMode: TGridFilterMode;
    FFilterField: string;
    FFilterOp: string;
    FFilterValueStr: string;
    FFilterValueNum: Double;
    FFilterIsNum: Boolean;

    FOnPageChange: TPageChangeEvent;
    FOnRefresh: TNotifyEvent;
    FOnFilterApply: TFilterApplyEvent;

    procedure InitInspectorComponents;
    procedure UpdatePaginationUI;
    procedure UpdateStatusBar;
    function GetSelectedCellValue: string;
    procedure ApplyQuickFilter(const AFieldName, AValue: string);
    procedure ApplyDataSetFilter(const AFilter: string);
    procedure HandleDataSetFilterRecord(DataSet: TDataSet; var Accept: Boolean);
    procedure HandleInspectorClose(Sender: TObject);

    procedure ExportDataSetToFormat(const AFormat: TExportFormat);
    procedure DoExportToFile(const AFileName: string; const AFormat: TExportFormat);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure AttachDataSet(ADataSet: TZQuery; const AExecutionTimeMS: Int64 = 0; const ATotalRecs: Int64 = -1);
    procedure SetPaginationInfo(const ACurrentPage, ATotalPages, APageSize: Integer; const ATotalRecords: Int64);
    procedure SetInspectorVisible(const AVisible: Boolean);
    procedure Clear;

    property DataSet: TZQuery read FDataSet;
    property CurrentPage: Integer read FCurrentPage write FCurrentPage;
    property TotalPages: Integer read FTotalPages;
    property PageSize: Integer read FPageSize write FPageSize;
    property TotalRecords: Int64 read FTotalRecords;

    property OnPageChange: TPageChangeEvent read FOnPageChange write FOnPageChange;
    property OnRefresh: TNotifyEvent read FOnRefresh write FOnRefresh;
    property OnFilterApply: TFilterApplyEvent read FOnFilterApply write FOnFilterApply;
    procedure RefreshGridDisplay;
  end;

implementation

{$R *.lfm}

{ TFrameDataGrid }

procedure TFrameDataGrid.InitInspectorComponents;
begin
  // Inisialisasi Dinamis Panel Inspektor jika belum dimuat dari LFM
  if not Assigned(pnlInspectorContainer) then
  begin
    pnlInspectorContainer := TPanel.Create(Self);
    pnlInspectorContainer.Name := 'pnlInspectorContainer';
    pnlInspectorContainer.Parent := Self;
    pnlInspectorContainer.Align := alRight;
    pnlInspectorContainer.Width := 340;
    pnlInspectorContainer.BevelOuter := bvNone;
    pnlInspectorContainer.Visible := False;
  end;

  if not Assigned(splInspector) then
  begin
    splInspector := TSplitter.Create(Self);
    splInspector.Name := 'splInspector';
    splInspector.Parent := Self;
    splInspector.Align := alRight;
    splInspector.Width := 5;
    splInspector.Visible := False;
  end;

  if not Assigned(btnToggleInspector) and Assigned(pnlToolbar) then
  begin
    btnToggleInspector := TSpeedButton.Create(Self);
    btnToggleInspector.Name := 'btnToggleInspector';
    btnToggleInspector.Parent := pnlToolbar;
    btnToggleInspector.BorderSpacing.Around:=3;
    btnToggleInspector.Align := alRight;
    btnToggleInspector.Width := 65;
    btnToggleInspector.AllowAllUp := True;
    btnToggleInspector.GroupIndex := 101;
    btnToggleInspector.Caption := 'Inspektor';
    btnToggleInspector.Hint := 'Tampilkan/Sembunyikan Panel Inspektor';
    btnToggleInspector.ShowHint := True;
    btnToggleInspector.OnClick := @btnToggleInspectorClick;
  end;

  if not Assigned(FInspectorFrame) then
  begin
    FInspectorFrame := TFrameValueInspector.Create(Self);
    FInspectorFrame.Parent := pnlInspectorContainer;
    FInspectorFrame.Align := alClient;
    FInspectorFrame.OnCloseRequest := @HandleInspectorClose;
  end;
end;

constructor TFrameDataGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDataSet := nil;
  FCurrentPage := 1;
  FTotalPages := 1;
  FPageSize := 100;
  FTotalRecords := 0;
  FExecutionTimeMS := 0;
  FSortField := '';
  FSortAscending := True;
  FFilterMode := gfmNone;

  InitInspectorComponents;
  SetInspectorVisible(False);

  dbGrid.DataSource := srcData;
  dbGrid.PopupMenu := popGrid;
  btnExport.PopupMenu := popExport;
  Clear;
end;

destructor TFrameDataGrid.Destroy;
begin
  // Lepaskan event datasource lebih dulu agar grid tidak menggambar ulang saat objek dibongkar
  srcData.OnDataChange := nil;
  srcData.DataSet := nil;

  if Assigned(FDataSet) then
  begin
    try
      FDataSet.OnFilterRecord := nil;
      FDataSet.Filtered := False;
    except
      // Mengabaikan jika dataset sudah dihancurkan oleh frame query
    end;
    FDataSet := nil;
  end;

  //inherited Destroy;
end;

procedure TFrameDataGrid.SetInspectorVisible(const AVisible: Boolean);
begin
  if Assigned(pnlInspectorContainer) then
    pnlInspectorContainer.Visible := AVisible;

  if Assigned(splInspector) then
    splInspector.Visible := AVisible;

  if Assigned(btnToggleInspector) then
    btnToggleInspector.Down := AVisible;

  if AVisible and Assigned(dbGrid) and Assigned(dbGrid.SelectedField) and Assigned(FInspectorFrame) then
    FInspectorFrame.InspectField(dbGrid.SelectedField);
end;

procedure TFrameDataGrid.HandleInspectorClose(Sender: TObject);
begin
  SetInspectorVisible(False);
end;

procedure TFrameDataGrid.btnToggleInspectorClick(Sender: TObject);
begin
  if Assigned(pnlInspectorContainer) then
    SetInspectorVisible(not pnlInspectorContainer.Visible)
  else
    SetInspectorVisible(True);
end;

procedure TFrameDataGrid.CheckBox1Change(Sender: TObject);
begin
  dbGrid.AutoFillColumns:=CheckBox1.Checked;
end;

procedure TFrameDataGrid.Clear;
begin
  if Assigned(FDataSet) then
  begin
    FDataSet.Filtered := False;
    FDataSet.OnFilterRecord := nil;
  end;
  srcData.DataSet := nil;
  FDataSet := nil;
  FCurrentPage := 1;
  FTotalPages := 1;
  FTotalRecords := 0;
  FExecutionTimeMS := 0;
  FSortField := '';
  FFilterMode := gfmNone;
  edtFilter.Clear;

  if Assigned(FInspectorFrame) then
    FInspectorFrame.Clear;

  UpdatePaginationUI;
  UpdateStatusBar;
end;

procedure TFrameDataGrid.AttachDataSet(ADataSet: TZQuery; const AExecutionTimeMS: Int64; const ATotalRecs: Int64);
begin
  FDataSet := ADataSet;
  srcData.DataSet := FDataSet;
  FExecutionTimeMS := AExecutionTimeMS;
  FFilterMode := gfmNone;

  if Assigned(FDataSet) then
  begin
    FDataSet.Filtered := False;
    FDataSet.OnFilterRecord := @HandleDataSetFilterRecord;
    if ATotalRecs >= 0 then
      FTotalRecords := ATotalRecs
    else if FDataSet.Active then
      FTotalRecords := FDataSet.RecordCount
    else
      FTotalRecords := 0;
  end
  else
    FTotalRecords := 0;

  if Assigned(pnlInspectorContainer) and pnlInspectorContainer.Visible and
     Assigned(dbGrid) and Assigned(dbGrid.SelectedField) and Assigned(FInspectorFrame) then
    FInspectorFrame.InspectField(dbGrid.SelectedField)
  else if Assigned(FInspectorFrame) then
    FInspectorFrame.Clear;

  UpdatePaginationUI;
  UpdateStatusBar;
end;

procedure TFrameDataGrid.SetPaginationInfo(const ACurrentPage, ATotalPages, APageSize: Integer; const ATotalRecords: Int64);
begin
  FCurrentPage := ACurrentPage;
  FTotalPages := ATotalPages;
  FPageSize := APageSize;
  FTotalRecords := ATotalRecords;
  UpdatePaginationUI;
  UpdateStatusBar;
end;

procedure TFrameDataGrid.UpdatePaginationUI;
begin
  btnFirstPage.Enabled := (FCurrentPage > 1);
  btnPriorPage.Enabled := (FCurrentPage > 1);
  btnNextPage.Enabled := (FCurrentPage < FTotalPages);
  btnLastPage.Enabled := (FCurrentPage < FTotalPages);

  if FTotalPages > 0 then
    lblPageInfo.Caption := Format('Halaman %d dari %d', [FCurrentPage, FTotalPages])
  else
    lblPageInfo.Caption := 'Halaman 1 dari 1';
end;

procedure TFrameDataGrid.UpdateStatusBar;
begin
  if Assigned(FDataSet) and FDataSet.Active then
  begin
    if FDataSet.Filtered then
      lblRecordCount.Caption := Format('Jumlah Baris: %d (Terfilter)', [FDataSet.RecordCount])
    else if FTotalRecords >= 0 then
      lblRecordCount.Caption := Format('Jumlah Baris: %d', [FTotalRecords])
    else
      lblRecordCount.Caption := Format('Baris: %d', [FDataSet.RecordCount]);

    lblExecTime.Caption := Format('Waktu Eksekusi: %d ms', [FExecutionTimeMS]);
  end
  else
  begin
    lblRecordCount.Caption := 'Tidak ada data';
    lblExecTime.Caption := '';
    lblSelectedCell.Caption := '';
  end;
end;

function TFrameDataGrid.GetSelectedCellValue: string;
begin
  Result := '';
  if Assigned(FDataSet) and FDataSet.Active and not FDataSet.IsEmpty and Assigned(dbGrid.SelectedField) then
  begin
    if dbGrid.SelectedField.IsNull then
      Result := '<NULL>'
    else
      Result := dbGrid.SelectedField.AsString;
  end;
end;

procedure TFrameDataGrid.dbGridDrawColumnCell(Sender: TObject; const Rect: TRect;
  DataCol: Integer; Column: TColumn; State: TGridDrawState);
var
  Grid: TDBGrid;
  Cfg: TGridConfig;
  Field: TField;
  CellText: string;
begin
  Grid := TDBGrid(Sender);
  Cfg := GridConfig;
  Field := Column.Field;

  if not Assigned(Field) then Exit;

  // 1. Terapkan Font
  Grid.Canvas.Font.Name := Cfg.FontName;
  Grid.Canvas.Font.Size := Cfg.FontSize;

  // 2. Warna Latar Belakang Sel / Baris Bergantian
  if not (gdSelected in State) then
  begin
    if Field.IsNull and Cfg.UseNullBg then
      Grid.Canvas.Brush.Color := Cfg.ColorNullBg
    else if Cfg.UseAltRowColor then
    begin
      if (Grid.DataSource.DataSet.RecNo mod 2 = 0) then
        Grid.Canvas.Brush.Color := Cfg.ColorAltRow2
      else
        Grid.Canvas.Brush.Color := Cfg.ColorAltRow1;
    end;
  end;

  // 3. Warna Teks Berdasarkan Tipe Data
  if not (gdSelected in State) then
  begin
    if Field.IsNull then
      Grid.Canvas.Font.Color := clGray
    else
    begin
      case Field.DataType of
        ftSmallint, ftInteger, ftWord, ftLargeint:
          Grid.Canvas.Font.Color := Cfg.ColorInteger;
        ftFloat, ftCurrency, ftBCD, ftFMTBcd:
          Grid.Canvas.Font.Color := Cfg.ColorFloat;
        ftDate, ftTime, ftDateTime, ftTimeStamp:
          Grid.Canvas.Font.Color := Cfg.ColorDateTime;
        ftBlob, ftMemo, ftGraphic:
          Grid.Canvas.Font.Color := Cfg.ColorBlob;
        else
          Grid.Canvas.Font.Color := Cfg.ColorString;
      end;
    end;
  end;

  // 4. Format Nilai Teks
  if Field.IsNull then
    CellText := '(NULL)'
  else if (Field.DataType in [ftFloat, ftCurrency]) and (Cfg.MaxDecimalZeros >= 0) then
    CellText := FormatFloat('0.' + StringOfChar('#', Cfg.MaxDecimalZeros), Field.AsFloat)
  else
    CellText := Field.AsString;

  Grid.Canvas.FillRect(Rect);
  Grid.Canvas.TextRect(Rect, Rect.Left + 2, Rect.Top + 2, CellText);
end;
procedure TFrameDataGrid.dbGridTitleClick(Column: TColumn);
begin
  if not Assigned(FDataSet) or not FDataSet.Active or not Assigned(Column.Field) then Exit;

  if FSortField = Column.Field.FieldName then
    FSortAscending := not FSortAscending
  else
  begin
    FSortField := Column.Field.FieldName;
    FSortAscending := True;
  end;

  try
    if FSortAscending then
      FDataSet.SortedFields := FSortField + ' ASC'
    else
      FDataSet.SortedFields := FSortField + ' DESC';
  except
  end;
end;

procedure TFrameDataGrid.dbGridDblClick(Sender: TObject);
begin
  SetInspectorVisible(True);
end;

procedure TFrameDataGrid.srcDataDataChange(Sender: TObject; Field: TField);
begin
  if Assigned(dbGrid.SelectedField) then
  begin
    lblSelectedCell.Caption := Format('Kolom: %s [%s] | Nilai: %s', [
      dbGrid.SelectedField.FieldName,
      FieldTypeNames[dbGrid.SelectedField.DataType],
      GetSelectedCellValue
    ]);

    if Assigned(pnlInspectorContainer) and pnlInspectorContainer.Visible and Assigned(FInspectorFrame) then
      FInspectorFrame.InspectField(dbGrid.SelectedField);
  end
  else
  begin
    lblSelectedCell.Caption := '';
    if Assigned(pnlInspectorContainer) and pnlInspectorContainer.Visible and Assigned(FInspectorFrame) then
      FInspectorFrame.Clear;
  end;
end;

procedure TFrameDataGrid.btnFirstPageClick(Sender: TObject);
begin
  if (FCurrentPage > 1) and Assigned(FOnPageChange) then
    FOnPageChange(Self, 1);
end;

procedure TFrameDataGrid.btnPriorPageClick(Sender: TObject);
begin
  if (FCurrentPage > 1) and Assigned(FOnPageChange) then
    FOnPageChange(Self, FCurrentPage - 1);
end;

procedure TFrameDataGrid.btnNextPageClick(Sender: TObject);
begin
  if (FCurrentPage < FTotalPages) and Assigned(FOnPageChange) then
    FOnPageChange(Self, FCurrentPage + 1);
end;

procedure TFrameDataGrid.btnLastPageClick(Sender: TObject);
begin
  if (FCurrentPage < FTotalPages) and Assigned(FOnPageChange) then
    FOnPageChange(Self, FTotalPages);
end;

procedure TFrameDataGrid.btnRefreshClick(Sender: TObject);
begin
  if Assigned(FOnRefresh) then
    FOnRefresh(Self);
end;

procedure TFrameDataGrid.btnExportClick(Sender: TObject);
var
  Pt: TPoint;
begin
  Pt := btnExport.ClientToScreen(Point(0, btnExport.Height));
  popExport.PopUp(Pt.X, Pt.Y);
end;

procedure TFrameDataGrid.ApplyDataSetFilter(const AFilter: string);
var
  S, UpperS, FieldPart, OpPart, ValPart: string;
  P: Integer;
begin
  if not Assigned(FDataSet) or not FDataSet.Active then Exit;

  S := Trim(AFilter);
  if S = '' then
  begin
    FFilterMode := gfmNone;
    FDataSet.Filtered := False;
    UpdateStatusBar;
    Exit;
  end;

  if (Length(S) >= 2) and (((S[1] = '''') and (S[Length(S)] = '''')) or ((S[1] = '"') and (S[Length(S)] = '"'))) then
    S := Copy(S, 2, Length(S) - 2);

  UpperS := UpperCase(S);

  if UpperS.EndsWith(' IS NOT NULL') then
  begin
    FFilterMode := gfmIsNotNull;
    FFilterField := Trim(Copy(S, 1, Length(S) - 12));
  end
  else if UpperS.EndsWith(' IS NULL') then
  begin
    FFilterMode := gfmIsNull;
    FFilterField := Trim(Copy(S, 1, Length(S) - 8));
  end
  else
  begin
    OpPart := '';
    if Pos('>=', S) > 0 then OpPart := '>='
    else if Pos('<=', S) > 0 then OpPart := '<='
    else if Pos('<>', S) > 0 then OpPart := '<>'
    else if Pos('!=', S) > 0 then OpPart := '<>'
    else if Pos(' LIKE ', UpperS) > 0 then OpPart := 'LIKE'
    else if Pos('=', S) > 0 then OpPart := '='
    else if Pos('>', S) > 0 then OpPart := '>'
    else if Pos('<', S) > 0 then OpPart := '<'
    else if Pos(':', S) > 0 then OpPart := ':';

    if OpPart <> '' then
    begin
      if OpPart = 'LIKE' then
        P := Pos(' LIKE ', UpperS)
      else
        P := Pos(OpPart, S);

      FieldPart := Trim(Copy(S, 1, P - 1));
      if OpPart = 'LIKE' then
        ValPart := Trim(Copy(S, P + 6, Length(S)))
      else
        ValPart := Trim(Copy(S, P + Length(OpPart), Length(S)));

      while (ValPart <> '') and (ValPart[1] in ['''', '"', '%']) do
        Delete(ValPart, 1, 1);
      while (ValPart <> '') and (ValPart[Length(ValPart)] in ['''', '"', '%']) do
        Delete(ValPart, Length(ValPart), 1);

      if (FieldPart <> '') and (FDataSet.FindField(FieldPart) <> nil) then
      begin
        FFilterMode := gfmFieldOp;
        FFilterField := FieldPart;
        if OpPart = ':' then
          FFilterOp := 'LIKE'
        else
          FFilterOp := OpPart;
        FFilterValueStr := ValPart;
        FFilterIsNum := TryStrToFloat(ValPart, FFilterValueNum);
      end
      else
      begin
        FFilterMode := gfmGlobalSearch;
        FFilterValueStr := S;
      end;
    end
    else
    begin
      FFilterMode := gfmGlobalSearch;
      FFilterValueStr := S;
    end;
  end;

  try
    FDataSet.Filtered := False;
    FDataSet.OnFilterRecord := @HandleDataSetFilterRecord;
    FDataSet.Filtered := (FFilterMode <> gfmNone);
    UpdateStatusBar;
  except
    on E: Exception do
    begin
      FDataSet.Filtered := False;
      MessageDlg('Pencarian Gagal', E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TFrameDataGrid.HandleDataSetFilterRecord(DataSet: TDataSet; var Accept: Boolean);
var
  I: Integer;
  Fld: TField;
  CellStr, SearchSub: string;
  CellNum: Double;
begin
  Accept := True;
  if FFilterMode = gfmNone then Exit;

  case FFilterMode of
    gfmGlobalSearch:
    begin
      Accept := False;
      SearchSub := AnsiLowerCase(FFilterValueStr);
      for I := 0 to DataSet.FieldCount - 1 do
      begin
        Fld := DataSet.Fields[I];
        if not Fld.IsNull then
        begin
          CellStr := Fld.AsString;
          if (Pos(SearchSub, AnsiLowerCase(CellStr)) > 0) or (Pos(FFilterValueStr, CellStr) > 0) then
          begin
            Accept := True;
            Exit;
          end;
        end;
      end;
    end;

    gfmIsNull:
    begin
      Fld := DataSet.FindField(FFilterField);
      if Assigned(Fld) then Accept := Fld.IsNull;
    end;

    gfmIsNotNull:
    begin
      Fld := DataSet.FindField(FFilterField);
      if Assigned(Fld) then Accept := not Fld.IsNull;
    end;

    gfmFieldOp:
    begin
      Fld := DataSet.FindField(FFilterField);
      if not Assigned(Fld) or Fld.IsNull then
      begin
        Accept := False;
        Exit;
      end;

      if FFilterOp = 'LIKE' then
      begin
        CellStr := Fld.AsString;
        Accept := (Pos(AnsiLowerCase(FFilterValueStr), AnsiLowerCase(CellStr)) > 0) or
                  (Pos(FFilterValueStr, CellStr) > 0);
      end
      else if FFilterIsNum and (Fld.DataType in [ftSmallint, ftInteger, ftWord, ftFloat, ftCurrency, ftBCD, ftLargeint, ftFMTBcd]) then
      begin
        CellNum := Fld.AsFloat;
        if FFilterOp = '=' then Accept := (CellNum = FFilterValueNum)
        else if (FFilterOp = '<>') or (FFilterOp = '!=') then Accept := (CellNum <> FFilterValueNum)
        else if FFilterOp = '>' then Accept := (CellNum > FFilterValueNum)
        else if FFilterOp = '<' then Accept := (CellNum < FFilterValueNum)
        else if FFilterOp = '>=' then Accept := (CellNum >= FFilterValueNum)
        else if FFilterOp = '<=' then Accept := (CellNum <= FFilterValueNum);
      end
      else
      begin
        CellStr := Fld.AsString;
        if FFilterOp = '=' then Accept := SameText(CellStr, FFilterValueStr)
        else if (FFilterOp = '<>') or (FFilterOp = '!=') then Accept := not SameText(CellStr, FFilterValueStr)
        else if FFilterOp = '>' then Accept := (AnsiCompareText(CellStr, FFilterValueStr) > 0)
        else if FFilterOp = '<' then Accept := (AnsiCompareText(CellStr, FFilterValueStr) < 0)
        else if FFilterOp = '>=' then Accept := (AnsiCompareText(CellStr, FFilterValueStr) >= 0)
        else if FFilterOp = '<=' then Accept := (AnsiCompareText(CellStr, FFilterValueStr) <= 0);
      end;
    end;
  end;
end;

procedure TFrameDataGrid.btnFilterClick(Sender: TObject);
begin
  ApplyDataSetFilter(Trim(edtFilter.Text));
  if Assigned(FOnFilterApply) then
    FOnFilterApply(Self, Trim(edtFilter.Text));
end;

procedure TFrameDataGrid.btnClearFilterClick(Sender: TObject);
begin
  edtFilter.Clear;
  ApplyDataSetFilter('');
  if Assigned(FOnFilterApply) then
    FOnFilterApply(Self, '');
end;

procedure TFrameDataGrid.edtFilterKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = 13 then
  begin
    btnFilterClick(Sender);
    Key := 0;
  end;
end;

procedure TFrameDataGrid.mnuCopyCellClick(Sender: TObject);
begin
  Clipboard.AsText := GetSelectedCellValue;
end;

procedure TFrameDataGrid.mnuCopyRowClick(Sender: TObject);
var
  I: Integer;
  RowStr: string;
begin
  if not Assigned(FDataSet) or not FDataSet.Active or FDataSet.IsEmpty then Exit;

  RowStr := '';
  for I := 0 to FDataSet.FieldCount - 1 do
  begin
    if I > 0 then RowStr := RowStr + #9;
    if FDataSet.Fields[I].IsNull then
      RowStr := RowStr + 'NULL'
    else
      RowStr := RowStr + FDataSet.Fields[I].AsString;
  end;
  Clipboard.AsText := RowStr;
end;

procedure TFrameDataGrid.mnuCopyAllCSVClick(Sender: TObject);
var
  I: Integer;
  CSVData, Line: string;
  Bookmark: TBookmark;
begin
  if not Assigned(FDataSet) or not FDataSet.Active or FDataSet.IsEmpty then Exit;

  CSVData := '';
  FDataSet.DisableControls;
  Bookmark := FDataSet.GetBookmark;
  try
    Line := '';
    for I := 0 to FDataSet.FieldCount - 1 do
    begin
      if I > 0 then Line := Line + ',';
      Line := Line + '"' + StringReplace(FDataSet.Fields[I].FieldName, '"', '""', [rfReplaceAll]) + '"';
    end;
    CSVData := CSVData + Line + LineEnding;

    FDataSet.First;
    while not FDataSet.EOF do
    begin
      Line := '';
      for I := 0 to FDataSet.FieldCount - 1 do
      begin
        if I > 0 then Line := Line + ',';
        if FDataSet.Fields[I].IsNull then
          Line := Line + 'NULL'
        else
          Line := Line + '"' + StringReplace(FDataSet.Fields[I].AsString, '"', '""', [rfReplaceAll]) + '"';
      end;
      CSVData := CSVData + Line + LineEnding;
      FDataSet.Next;
    end;

    Clipboard.AsText := CSVData;
  finally
    if FDataSet.BookmarkValid(Bookmark) then
      FDataSet.GotoBookmark(Bookmark);
    FDataSet.FreeBookmark(Bookmark);
    FDataSet.EnableControls;
  end;
end;

procedure TFrameDataGrid.ApplyQuickFilter(const AFieldName, AValue: string);
var
  Condition: string;
begin
  if AValue = '<NULL>' then
    Condition := Format('%s IS NULL', [AFieldName])
  else
    Condition := Format('%s = %s', [AFieldName, AValue]);

  edtFilter.Text := Condition;
  ApplyDataSetFilter(Condition);
  if Assigned(FOnFilterApply) then
    FOnFilterApply(Self, Condition);
end;

procedure TFrameDataGrid.mnuFilterByValueClick(Sender: TObject);
begin
  if Assigned(dbGrid.SelectedField) then
    ApplyQuickFilter(dbGrid.SelectedField.FieldName, GetSelectedCellValue);
end;

procedure TFrameDataGrid.mnuInspectCellClick(Sender: TObject);
begin
  SetInspectorVisible(True);
end;

procedure TFrameDataGrid.DoExportToFile(const AFileName: string; const AFormat: TExportFormat);
var
  SL: TStringList;
  Bookmark: TBookmark;
  I: Integer;
  Line, ColName, ValStr, TableName: string;
begin
  SL := TStringList.Create;
  try
    FDataSet.DisableControls;
    Bookmark := FDataSet.GetBookmark;
    try
      TableName := 'data_export';

      case AFormat of
        efCSV:
        begin
          Line := '';
          for I := 0 to FDataSet.FieldCount - 1 do
          begin
            if I > 0 then Line := Line + ',';
            Line := Line + '"' + StringReplace(FDataSet.Fields[I].FieldName, '"', '""', [rfReplaceAll]) + '"';
          end;
          SL.Add(Line);

          FDataSet.First;
          while not FDataSet.EOF do
          begin
            Line := '';
            for I := 0 to FDataSet.FieldCount - 1 do
            begin
              if I > 0 then Line := Line + ',';
              if FDataSet.Fields[I].IsNull then
                Line := Line + 'NULL'
              else
                Line := Line + '"' + StringReplace(FDataSet.Fields[I].AsString, '"', '""', [rfReplaceAll]) + '"';
            end;
            SL.Add(Line);
            FDataSet.Next;
          end;
        end;

        efJSON:
        begin
          SL.Add('[');
          FDataSet.First;
          while not FDataSet.EOF do
          begin
            Line := '  {';
            for I := 0 to FDataSet.FieldCount - 1 do
            begin
              ColName := StringReplace(FDataSet.Fields[I].FieldName, '"', '\"', [rfReplaceAll]);
              if FDataSet.Fields[I].IsNull then
                ValStr := 'null'
              else
              begin
                case FDataSet.Fields[I].DataType of
                  ftSmallint, ftInteger, ftWord, ftLargeint:
                    ValStr := FDataSet.Fields[I].AsString;
                  ftFloat, ftCurrency, ftBCD, ftFMTBcd:
                    ValStr := StringReplace(FDataSet.Fields[I].AsString, ',', '.', [rfReplaceAll]);
                  ftBoolean:
                  begin
                    if FDataSet.Fields[I].AsBoolean then
                      ValStr := 'true'
                    else
                      ValStr := 'false';
                  end;
                  else
                  begin
                    ValStr := FDataSet.Fields[I].AsString;
                    ValStr := StringReplace(ValStr, '\', '\\', [rfReplaceAll]);
                    ValStr := StringReplace(ValStr, '"', '\"', [rfReplaceAll]);
                    ValStr := StringReplace(ValStr, #13#10, '\n', [rfReplaceAll]);
                    ValStr := StringReplace(ValStr, #10, '\n', [rfReplaceAll]);
                    ValStr := '"' + ValStr + '"';
                  end;
                end;
              end;
              Line := Line + Format('"%s": %s', [ColName, ValStr]);
              if I < FDataSet.FieldCount - 1 then
                Line := Line + ', ';
            end;
            Line := Line + '}';
            FDataSet.Next;
            if not FDataSet.EOF then
              Line := Line + ',';
            SL.Add(Line);
          end;
          SL.Add(']');
        end;

        efSQL:
        begin
          SL.Add('-- SiAdmin Export Dump');
          SL.Add('-- Generated at: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
          SL.Add('');
          FDataSet.First;
          while not FDataSet.EOF do
          begin
            Line := Format('INSERT INTO "%s" (', [TableName]);
            for I := 0 to FDataSet.FieldCount - 1 do
            begin
              if I > 0 then Line := Line + ', ';
              Line := Line + '"' + FDataSet.Fields[I].FieldName + '"';
            end;
            Line := Line + ') VALUES (';
            for I := 0 to FDataSet.FieldCount - 1 do
            begin
              if I > 0 then Line := Line + ', ';
              if FDataSet.Fields[I].IsNull then
                Line := Line + 'NULL'
              else
              begin
                case FDataSet.Fields[I].DataType of
                  ftSmallint, ftInteger, ftWord, ftLargeint:
                    Line := Line + FDataSet.Fields[I].AsString;
                  ftFloat, ftCurrency, ftBCD, ftFMTBcd:
                    Line := Line + StringReplace(FDataSet.Fields[I].AsString, ',', '.', [rfReplaceAll]);
                  ftBoolean:
                  begin
                    if FDataSet.Fields[I].AsBoolean then
                      Line := Line + '1'
                    else
                      Line := Line + '0';
                  end;
                  else
                    Line := Line + '''' + StringReplace(FDataSet.Fields[I].AsString, '''', '''''', [rfReplaceAll]) + '''';
                end;
              end;
            end;
            Line := Line + ');';
            SL.Add(Line);
            FDataSet.Next;
          end;
        end;

        efHTML:
        begin
          SL.Add('<!DOCTYPE html>');
          SL.Add('<html>');
          SL.Add('<head>');
          SL.Add('  <meta charset="UTF-8">');
          SL.Add('  <title>SiAdmin Data Export</title>');
          SL.Add('  <style>');
          SL.Add('    body { font-family: Arial, sans-serif; margin: 20px; }');
          SL.Add('    table { border-collapse: collapse; width: 100%; margin-top: 10px; }');
          SL.Add('    th, td { border: 1px solid #ccc; padding: 8px; text-align: left; }');
          SL.Add('    th { background-color: #2563eb; color: white; }');
          SL.Add('    tr:nth-child(even) { background-color: #f8fafc; }');
          SL.Add('  </style>');
          SL.Add('</head>');
          SL.Add('<body>');
          SL.Add('  <h2>Data Export (' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ')</h2>');
          SL.Add('  <table>');
          SL.Add('    <thead><tr>');
          for I := 0 to FDataSet.FieldCount - 1 do
            SL.Add('      <th>' + FDataSet.Fields[I].FieldName + '</th>');
          SL.Add('    </tr></thead>');
          SL.Add('    <tbody>');
          FDataSet.First;
          while not FDataSet.EOF do
          begin
            SL.Add('      <tr>');
            for I := 0 to FDataSet.FieldCount - 1 do
            begin
              if FDataSet.Fields[I].IsNull then
                SL.Add('        <td><em>NULL</em></td>')
              else
              begin
                ValStr := FDataSet.Fields[I].AsString;
                ValStr := StringReplace(ValStr, '&', '&amp;', [rfReplaceAll]);
                ValStr := StringReplace(ValStr, '<', '&lt;', [rfReplaceAll]);
                ValStr := StringReplace(ValStr, '>', '&gt;', [rfReplaceAll]);
                SL.Add('        <td>' + ValStr + '</td>');
              end;
            end;
            SL.Add('      </tr>');
            FDataSet.Next;
          end;
          SL.Add('    </tbody>');
          SL.Add('  </table>');
          SL.Add('</body>');
          SL.Add('</html>');
        end;

        efMarkdown:
        begin
          Line := '|';
          for I := 0 to FDataSet.FieldCount - 1 do
            Line := Line + ' ' + FDataSet.Fields[I].FieldName + ' |';
          SL.Add(Line);

          Line := '|';
          for I := 0 to FDataSet.FieldCount - 1 do
            Line := Line + ' --- |';
          SL.Add(Line);

          FDataSet.First;
          while not FDataSet.EOF do
          begin
            Line := '|';
            for I := 0 to FDataSet.FieldCount - 1 do
            begin
              if FDataSet.Fields[I].IsNull then
                Line := Line + ' NULL |'
              else
              begin
                ValStr := FDataSet.Fields[I].AsString;
                ValStr := StringReplace(ValStr, '|', '\|', [rfReplaceAll]);
                ValStr := StringReplace(ValStr, #13#10, '<br>', [rfReplaceAll]);
                ValStr := StringReplace(ValStr, #10, '<br>', [rfReplaceAll]);
                Line := Line + ' ' + ValStr + ' |';
              end;
            end;
            SL.Add(Line);
            FDataSet.Next;
          end;
        end;

        efXML:
        begin
          SL.Add('<?xml version="1.0" encoding="UTF-8"?>');
          SL.Add('<data>');
          FDataSet.First;
          while not FDataSet.EOF do
          begin
            SL.Add('  <row>');
            for I := 0 to FDataSet.FieldCount - 1 do
            begin
              ColName := FDataSet.Fields[I].FieldName;
              if FDataSet.Fields[I].IsNull then
                SL.Add('    <' + ColName + ' null="true"/>')
              else
              begin
                ValStr := FDataSet.Fields[I].AsString;
                ValStr := StringReplace(ValStr, '&', '&amp;', [rfReplaceAll]);
                ValStr := StringReplace(ValStr, '<', '&lt;', [rfReplaceAll]);
                ValStr := StringReplace(ValStr, '>', '&gt;', [rfReplaceAll]);
                SL.Add('    <' + ColName + '>' + ValStr + '</' + ColName + '>');
              end;
            end;
            SL.Add('  </row>');
            FDataSet.Next;
          end;
          SL.Add('</data>');
        end;
      end;

      SL.SaveToFile(AFileName);
    finally
      if FDataSet.BookmarkValid(Bookmark) then
        FDataSet.GotoBookmark(Bookmark);
      FDataSet.FreeBookmark(Bookmark);
      FDataSet.EnableControls;
    end;
  finally
    SL.Free;
  end;
end;

procedure TFrameDataGrid.ExportDataSetToFormat(const AFormat: TExportFormat);
var
  DefExt, FilterStr: string;
begin
  if not Assigned(FDataSet) or not FDataSet.Active or FDataSet.IsEmpty then
  begin
    MessageDlg('Informasi', 'Tidak ada data untuk diekspor.', mtInformation, [mbOK], 0);
    Exit;
  end;

  case AFormat of
    efCSV:
    begin
      DefExt := '.csv';
      FilterStr := 'Comma-Separated Values (*.csv)|*.csv|All Files (*.*)|*.*';
    end;
    efJSON:
    begin
      DefExt := '.json';
      FilterStr := 'JSON Files (*.json)|*.json|All Files (*.*)|*.*';
    end;
    efSQL:
    begin
      DefExt := '.sql';
      FilterStr := 'SQL Insert Script (*.sql)|*.sql|All Files (*.*)|*.*';
    end;
    efHTML:
    begin
      DefExt := '.html';
      FilterStr := 'HTML Web Page (*.html)|*.html|All Files (*.*)|*.*';
    end;
    efMarkdown:
    begin
      DefExt := '.md';
      FilterStr := 'Markdown Documents (*.md)|*.md|All Files (*.*)|*.*';
    end;
    efXML:
    begin
      DefExt := '.xml';
      FilterStr := 'XML Data (*.xml)|*.xml|All Files (*.*)|*.*';
    end;
  end;

  saveDialog.DefaultExt := DefExt;
  saveDialog.Filter := FilterStr;
  saveDialog.FileName := Format('export_%s%s', [FormatDateTime('yyyymmdd_hhnnss', Now), DefExt]);

  if saveDialog.Execute then
  begin
    Screen.Cursor := crHourGlass;
    try
      DoExportToFile(saveDialog.FileName, AFormat);
      MessageDlg('Ekspor Selesai', Format('Data berhasil diekspor ke:%s%s', [LineEnding, saveDialog.FileName]), mtInformation, [mbOK], 0);
    except
      on E: Exception do
        MessageDlg('Gagal Ekspor', 'Kesalahan saat menyimpan berkas: ' + E.Message, mtError, [mbOK], 0);
    end;
    Screen.Cursor := crDefault;
  end;
end;

procedure TFrameDataGrid.mnuExportOptionClick(Sender: TObject);
begin
  if Sender = mnuExpCSV then ExportDataSetToFormat(efCSV)
  else if Sender = mnuExpJSON then ExportDataSetToFormat(efJSON)
  else if Sender = mnuExpSQL then ExportDataSetToFormat(efSQL)
  else if Sender = mnuExpHTML then ExportDataSetToFormat(efHTML)
  else if Sender = mnuExpMarkdown then ExportDataSetToFormat(efMarkdown)
  else if Sender = mnuExpXML then ExportDataSetToFormat(efXML);
end;

procedure TFrameDataGrid.btnFormViewClick(Sender: TObject);
begin
  // Izinkan FormRecordView terbuka selama dataset aktif dan memiliki struktur kolom (FieldCount > 0)
  if not Assigned(FDataSet) or not FDataSet.Active or (FDataSet.FieldCount = 0) then
  begin
    MessageDlg('Informasi', 'Dataset kueri tidak aktif atau tidak memiliki definisi kolom.', mtInformation, [mbOK], 0);
    Exit;
  end;

  TFormRecordView.Execute(Self, FDataSet);
end;

procedure TFrameDataGrid.RefreshGridDisplay;
begin
  if Assigned(dbGrid) then
  begin
    dbGrid.Font.Name := GridConfig.FontName;
    dbGrid.Font.Size := GridConfig.FontSize;
    dbGrid.Invalidate; // Gambar ulang seluruh grid sesuai setting
  end;
end;

end.
