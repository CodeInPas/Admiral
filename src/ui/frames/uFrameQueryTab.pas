unit uFrameQueryTab;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  ComCtrls, StdCtrls, Buttons, Menus, Grids, Clipbrd,
  SynEdit, SynHighlighterSQL, SynCompletion, LCLType,
  ZDataset, ColorSpeedButton, uFrameMapViewer,
  uSQLLoggerService, uFormAIExplainer, uFrameVisualChart,
  uFormQueryBuilder, uFormAIDiagnostic, uFormAIOptimizer,
  uSafeModeGuardrails, uFormSafeModeWarning,
  uAppTypes, uDBTypes, uModelConnection, uDBDriverBase, uDBConnectionFactory,
  uModelSchemaObject, uQueryWorkerThread, uHistoryService, uExportService, uFrameDataGrid;

type
  { TFrameQueryTab }
  TFrameQueryTab = class(TFrame)
    btnExecuteR: TColorSpeedButton;
    btnCancel: TColorSpeedButton;
    btnExecuteSelection: TColorSpeedButton;
    btnFormatSQL: TColorSpeedButton;
    btnclearSQL: TColorSpeedButton;
    btnExplain: TColorSpeedButton;
    btnAIOptimizer: TColorSpeedButton;
    btnAIExplainDoc: TColorSpeedButton;
    btnQueryBuilder: TColorSpeedButton;
    Panel1: TPanel;
    pnlMain: TPanel;
    pnlToolbar: TPanel;
    sepTool1: TBevel;
    sepTool2: TBevel;
    lblStatusInfo: TLabel;
    prgExecuting: TProgressBar;

    splVertical: TSplitter;
    pnlEditor: TPanel;
    synEditor: TSynEdit;
    synSQLSyn: TSynSQLSyn;

    pnlResults: TPanel;
    pgcResults: TPageControl;
    tabData: TTabSheet;
    tabMessages: TTabSheet;
    tabExplain: TTabSheet;
    memMessages: TMemo;
    gridExplain: TStringGrid;

    popEditor: TPopupMenu;
    mnuExecAll: TMenuItem;
    mnuExecSel: TMenuItem;
    mnuExplainPlan: TMenuItem;
    mnuSepPop1: TMenuItem;
    mnuCopyText: TMenuItem;
    mnuPasteText: TMenuItem;
    mnuClearAll: TMenuItem;
    btnAIDiagnose: TSpeedButton;
    tabChart: TTabSheet;
    tbsSpatialMap: TTabSheet;

    procedure btnAIExplainDocClick(Sender: TObject);
    procedure btnAIOptimizerClick(Sender: TObject);
    procedure btnAIDiagnoseClick(Sender: TObject);
    procedure btnExecuteClick(Sender: TObject);
    procedure btnExecuteRClick(Sender: TObject);
    procedure btnExplainClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnFormatSQLClick(Sender: TObject);
    procedure btnClearSQLClick(Sender: TObject);
    procedure btnQueryBuilderClick(Sender: TObject);
    procedure synEditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure synEditorUTF8KeyPress(Sender: TObject; var UTF8Key: TUTF8Char);
  private
    FProfile: TConnectionProfile;
    FDatabaseTarget: string;
    FFrameDataGrid: TFrameDataGrid;
    FWorker: TQueryWorkerThread;
    FIsExecuting: Boolean;
    FLastExecutedSQL: string;
    FFrameVisualChart: TFrameVisualChart;

    // Komponen & Cache IntelliSense
    FSynCompletion: TSynCompletion;
    FTableColumnsCache: TStringList;
    FBaseKeywordsList: TStringList;
    FTableNamesList: TStringList;
    FAllColumnsList: TStringList;
    FMapFrame: TFrameMapViewer;

    procedure SetIsExecuting(const AValue: Boolean);
    procedure AppendLogMessage(const AMessage: string; const AIsError: Boolean = False);
    procedure RenderExplainPlan(const APlan: TDBExecutionPlanArray);

    procedure HandleWorkerProgress(Sender: TObject; const AMessage: string);
    procedure HandleWorkerSuccess(Sender: TObject; const AResult: TDBQueryResult; AQuery: TZQuery);
    procedure HandleWorkerError(Sender: TObject; const AResult: TDBQueryResult);

    procedure InitIntelliSense;
    procedure LoadSchemaToIntelliSense;
    procedure PrepareCompletionList;
    procedure HandleCompletionExecute(Sender: TObject);
    procedure TriggerAutoCompletion(Data: PtrInt);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure InitConnection(AProfile: TConnectionProfile; const ADatabaseTarget: string = '');
    procedure SetSQLText(const ASQL: string);
    function GetSQLText: string;
    procedure ExecuteSQL(const ASQL: string);
    procedure ExecuteCurrentOrSelected;
    procedure CancelExecution;
    procedure RefreshGridDisplay;
    procedure RefreshIntelliSense;

    property FrameVisualChart: TFrameVisualChart read FFrameVisualChart;
    property Profile: TConnectionProfile read FProfile;
    property DatabaseTarget: string read FDatabaseTarget write FDatabaseTarget;
    property IsExecuting: Boolean read FIsExecuting;
    property FrameDataGrid: TFrameDataGrid read FFrameDataGrid;
  end;

implementation

{$R *.lfm}

{ TFrameQueryTab }

constructor TFrameQueryTab.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FProfile := TConnectionProfile.Create;
  FDatabaseTarget := '';
  FWorker := nil;
  FIsExecuting := False;
  FLastExecutedSQL := '';

  // Inisialisasi list cache IntelliSense
  FTableColumnsCache := TStringList.Create;
  FTableColumnsCache.Sorted := True;
  FTableColumnsCache.Duplicates := dupIgnore;

  FBaseKeywordsList := TStringList.Create;
  FTableNamesList := TStringList.Create;
  FAllColumnsList := TStringList.Create;

  // Mengembalikan pemetaan tombol bawaan SynEdit
  if Assigned(synEditor) then
  begin
    synEditor.Keystrokes.ResetDefaults;
    synEditor.OnUTF8KeyPress := @synEditorUTF8KeyPress;
  end;

  FFrameDataGrid := TFrameDataGrid.Create(Self);
  FFrameDataGrid.Parent := tabData;
  FFrameDataGrid.Align := alClient;

  gridExplain.ColCount := 5;
  gridExplain.RowCount := 1;
  gridExplain.Cells[0, 0] := 'ID';
  gridExplain.Cells[1, 0] := 'Operation';
  gridExplain.Cells[2, 0] := 'Object Targeted';
  gridExplain.Cells[3, 0] := 'Row Estimation';
  gridExplain.Cells[4, 0] := 'Additional Details';
  gridExplain.ColWidths[0] := 50;
  gridExplain.ColWidths[1] := 180;
  gridExplain.ColWidths[2] := 120;
  gridExplain.ColWidths[3] := 100;
  gridExplain.ColWidths[4] := 350;

  SetIsExecuting(False);

  if not Assigned(tabChart) then
  begin
    tabChart := pgcResults.AddTabSheet;
    tabChart.Caption := '📈 Visual Chart & BI';
  end;

  FFrameVisualChart := TFrameVisualChart.Create(Self);
  FFrameVisualChart.Parent := tabChart;
  FFrameVisualChart.Align := alClient;

  InitIntelliSense;

  FMapFrame := TFrameMapViewer.Create(tbsSpatialMap);
  FMapFrame.Parent := tbsSpatialMap;
  FMapFrame.Align := alClient;
end;

destructor TFrameQueryTab.Destroy;
var
  I: Integer;
begin
  // 1. Putuskan event listener worker thread
  if Assigned(FWorker) then
  begin
    FWorker.OnProgress := nil;
    FWorker.OnSuccess := nil;
    FWorker.OnError := nil;
    if FIsExecuting then
      FWorker.CancelExecution;
  end;

  // 2. Putuskan keterikatan UI terhadap DataSet
  try
    if Assigned(FFrameDataGrid) then
      FFrameDataGrid.Clear;
  except
  end;

  try
    if Assigned(FFrameVisualChart) then
      FFrameVisualChart.Clear;
  except
  end;

  // 3. Hancurkan FWorker
  if Assigned(FWorker) then
  begin
    try
      FWorker.WaitFor;
    except
    end;
    try
      FreeAndNil(FWorker);
    except
    end;
  end;

  // 4. Bebaskan cache kolom
  if Assigned(FTableColumnsCache) then
  begin
    for I := 0 to FTableColumnsCache.Count - 1 do
      if Assigned(FTableColumnsCache.Objects[I]) then
        FTableColumnsCache.Objects[I].Free;
    FreeAndNil(FTableColumnsCache);
  end;

  FreeAndNil(FBaseKeywordsList);
  FreeAndNil(FTableNamesList);
  FreeAndNil(FAllColumnsList);

  // 5. Netralkan komponen editor teks
  try
    if Assigned(synEditor) then
    begin
      synEditor.PopupMenu := nil;
      synEditor.Lines.Clear;
    end;
  except
  end;

  // 6. Bebaskan objek Connection Profile
  try
    FreeAndNil(FProfile);
  except
  end;

  inherited Destroy;
end;

procedure TFrameQueryTab.InitIntelliSense;
begin
  if not Assigned(FSynCompletion) then
  begin
    FSynCompletion := TSynCompletion.Create(Self);
    FSynCompletion.Editor := synEditor;
    FSynCompletion.CaseSensitive := False;
    FSynCompletion.AutoUseSingleIdent := False;
    FSynCompletion.ShowSizeDrag := True;
    FSynCompletion.Width := 340;
    FSynCompletion.LinesInWindow := 12;
    FSynCompletion.ShortCut := ShortCut(VK_SPACE, [ssCtrl]);
    FSynCompletion.OnExecute := @HandleCompletionExecute;
  end;

  FBaseKeywordsList.Clear;

  // 1. Snippet & Template SQL
  FBaseKeywordsList.Add('SELECT * FROM ');
  FBaseKeywordsList.Add('SELECT * FROM  WHERE ');
  FBaseKeywordsList.Add('INSERT INTO  () VALUES ();');
  FBaseKeywordsList.Add('UPDATE  SET  WHERE ;');
  FBaseKeywordsList.Add('DELETE FROM  WHERE ;');
  FBaseKeywordsList.Add('INNER JOIN  ON ');
  FBaseKeywordsList.Add('LEFT JOIN  ON ');
  FBaseKeywordsList.Add('RIGHT JOIN  ON ');
  FBaseKeywordsList.Add('CROSS JOIN ');
  FBaseKeywordsList.Add('GROUP BY ');
  FBaseKeywordsList.Add('HAVING ');
  FBaseKeywordsList.Add('ORDER BY  ASC');
  FBaseKeywordsList.Add('ORDER BY  DESC');
  FBaseKeywordsList.Add('COUNT(*)');
  FBaseKeywordsList.Add('LIMIT 100 OFFSET 0;');
  FBaseKeywordsList.Add('CREATE TABLE  ();');
  FBaseKeywordsList.Add('ALTER TABLE  ADD COLUMN ;');
  FBaseKeywordsList.Add('DROP TABLE IF EXISTS ;');
  FBaseKeywordsList.Add('TRUNCATE TABLE ;');
  FBaseKeywordsList.Add('CREATE INDEX idx_ ON ();');

  // 2. Keyword Standar & Fungsi SQL
  FBaseKeywordsList.Add('SELECT');
  FBaseKeywordsList.Add('FROM');
  FBaseKeywordsList.Add('WHERE');
  FBaseKeywordsList.Add('DISTINCT');
  FBaseKeywordsList.Add('BETWEEN');
  FBaseKeywordsList.Add('LIKE');
  FBaseKeywordsList.Add('ILIKE');
  FBaseKeywordsList.Add('IN');
  FBaseKeywordsList.Add('NOT IN');
  FBaseKeywordsList.Add('IS NULL');
  FBaseKeywordsList.Add('IS NOT NULL');
  FBaseKeywordsList.Add('EXISTS');
  FBaseKeywordsList.Add('NOT EXISTS');
  FBaseKeywordsList.Add('CASE WHEN  THEN  ELSE  END');
  FBaseKeywordsList.Add('UNION ALL');
  FBaseKeywordsList.Add('UNION');
  FBaseKeywordsList.Add('COALESCE');
  FBaseKeywordsList.Add('SUM');
  FBaseKeywordsList.Add('AVG');
  FBaseKeywordsList.Add('MIN');
  FBaseKeywordsList.Add('MAX');
end;

procedure TFrameQueryTab.LoadSchemaToIntelliSense;
var
  Driver: TDBDriverBase;
  Tables, Views: TSchemaObjectList;
  ColList: TSchemaColumnList;
  Cols: TStringList;
  I, J: Integer;
  ObjName, TargetDB, ColName: string;
begin
  if not Assigned(FProfile) or (FProfile.Host = '') then Exit;

  if FDatabaseTarget <> '' then
    TargetDB := FDatabaseTarget
  else
    TargetDB := FProfile.DatabaseName;

  // Bersihkan cache kolom lama
  for I := 0 to FTableColumnsCache.Count - 1 do
    if Assigned(FTableColumnsCache.Objects[I]) then
      FTableColumnsCache.Objects[I].Free;
  FTableColumnsCache.Clear;

  FTableNamesList.Clear;
  FAllColumnsList.Clear;

  Driver := nil;
  Tables := TSchemaObjectList.Create(True);
  Views := TSchemaObjectList.Create(True);
  ColList := TSchemaColumnList.Create(True);
  try
    try
      Driver := TDBConnectionFactory.CreateDriver(FProfile);
      if Assigned(Driver) then
      begin
        // 1. Ekstraksi Tabel & Kolomnya
        Driver.ExtractTables(TargetDB, '', Tables);
        for I := 0 to Tables.Count - 1 do
        begin
          ObjName := Tables[I].Name;
          FTableNamesList.Add(ObjName);

          ColList.Clear;
          try
            Driver.ExtractColumns(TargetDB, '', ObjName, ColList);
            Cols := TStringList.Create;
            for J := 0 to ColList.Count - 1 do
            begin
              ColName := ColList[J].Name;
              Cols.Add(ColName);
              if FAllColumnsList.IndexOf(ColName) < 0 then
                FAllColumnsList.Add(ColName);
            end;
            FTableColumnsCache.AddObject(LowerCase(ObjName), Cols);
          except
          end;
        end;

        // 2. Ekstraksi View
        Driver.ExtractViews(TargetDB, '', Views);
        for I := 0 to Views.Count - 1 do
        begin
          ObjName := Views[I].Name;
          FTableNamesList.Add(ObjName);

          ColList.Clear;
          try
            Driver.ExtractColumns(TargetDB, '', ObjName, ColList);
            Cols := TStringList.Create;
            for J := 0 to ColList.Count - 1 do
            begin
              ColName := ColList[J].Name;
              Cols.Add(ColName);
              if FAllColumnsList.IndexOf(ColName) < 0 then
                FAllColumnsList.Add(ColName);
            end;
            FTableColumnsCache.AddObject(LowerCase(ObjName), Cols);
          except
          end;
        end;
      end;
    except
    end;
  finally
    ColList.Free;
    Views.Free;
    Tables.Free;
    if Assigned(Driver) then Driver.Free;
  end;
end;

procedure TFrameQueryTab.PrepareCompletionList;
var
  LineText, TablePrefix: string;
  CaretCol, P, EndP, Idx, I: Integer;
  IsDotContext: Boolean;
  Cols: TStringList;
begin
  if not Assigned(FSynCompletion) then Exit;

  LineText := synEditor.LineText;
  CaretCol := synEditor.CaretX;

  IsDotContext := False;
  TablePrefix := '';

  // Telusuri karakter ke belakang dari posisi kursor
  P := CaretCol - 1;
  while (P >= 1) and (LineText[P] in ['a'..'z', 'A'..'Z', '0'..'9', '_']) do
    Dec(P);

  // Jika ditemukan tanda titik sebelum kata saat ini
  if (P >= 1) and (LineText[P] = '.') then
  begin
    Dec(P);
    EndP := P;
    while (P >= 1) and (LineText[P] in ['a'..'z', 'A'..'Z', '0'..'9', '_']) do
      Dec(P);

    if EndP >= (P + 1) then
    begin
      TablePrefix := Copy(LineText, P + 1, EndP - P);
      IsDotContext := True;
    end;
  end;

  FSynCompletion.ItemList.Clear;

  // Konteks Tabel Spesifik (nama_tabel.)
  if IsDotContext and (TablePrefix <> '') then
  begin
    Idx := FTableColumnsCache.IndexOf(LowerCase(TablePrefix));
    if Idx >= 0 then
    begin
      Cols := TStringList(FTableColumnsCache.Objects[Idx]);
      if Assigned(Cols) then
      begin
        for I := 0 to Cols.Count - 1 do
          FSynCompletion.ItemList.Add(Cols[I]);
      end;
    end;
  end
  // Konteks Global: Keywords + Snippets + Tabel + Kolom
  else
  begin
    FSynCompletion.ItemList.Assign(FBaseKeywordsList);

    for I := 0 to FTableNamesList.Count - 1 do
      if FSynCompletion.ItemList.IndexOf(FTableNamesList[I]) < 0 then
        FSynCompletion.ItemList.Add(FTableNamesList[I]);

    for I := 0 to FAllColumnsList.Count - 1 do
      if FSynCompletion.ItemList.IndexOf(FAllColumnsList[I]) < 0 then
        FSynCompletion.ItemList.Add(FAllColumnsList[I]);
  end;
end;

procedure TFrameQueryTab.HandleCompletionExecute(Sender: TObject);
begin
  PrepareCompletionList;
end;

procedure TFrameQueryTab.TriggerAutoCompletion(Data: PtrInt);
var
  Token: string;
  Pt: TPoint;
begin
  if Assigned(FSynCompletion) and Assigned(synEditor) then
  begin
    PrepareCompletionList;
    if FSynCompletion.ItemList.Count > 0 then
    begin
      Token := FSynCompletion.CurrentString;

      // Konversi baris/kolom kursor ke koordinat piksel layar
      Pt := synEditor.RowColumnToPixels(synEditor.CaretXY);
      Pt := synEditor.ClientToScreen(Pt);
      Pt.Y := Pt.Y + synEditor.LineHeight; // Tempatkan popup tepat di bawah baris teks aktif

      FSynCompletion.Execute(Token, Pt.X, Pt.Y);
    end;
  end;
end;
procedure TFrameQueryTab.synEditorUTF8KeyPress(Sender: TObject; var UTF8Key: TUTF8Char);
begin
  // Munculkan popup autocomplete secara instan saat user mengetik tanda titik (.)
  if UTF8Key = '.' then
  begin
    Application.QueueAsyncCall(@TriggerAutoCompletion, 0);
  end;
end;

procedure TFrameQueryTab.synEditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_F9) and (Shift = []) then
  begin
    btnExecuteClick(Sender);
    Key := 0;
  end
  else if (Key = VK_F9) and (Shift = [ssCtrl]) then
  begin
    btnExplainClick(Sender);
    Key := 0;
  end
  else if (Key = VK_SPACE) and (Shift = [ssCtrl]) then
  begin
    PrepareCompletionList;
  end;
end;

procedure TFrameQueryTab.RefreshIntelliSense;
begin
  InitIntelliSense;
  LoadSchemaToIntelliSense;
end;

procedure TFrameQueryTab.InitConnection(AProfile: TConnectionProfile; const ADatabaseTarget: string);
begin
  if Assigned(AProfile) then
    FProfile.Assign(AProfile);

  FDatabaseTarget := ADatabaseTarget;

  RefreshIntelliSense;

  AppendLogMessage(Format('Tab Connect to: %s (%s)', [
    FProfile.ConnectionName,
    FProfile.GetDisplayName
  ]));
end;

procedure TFrameQueryTab.SetSQLText(const ASQL: string);
begin
  synEditor.Lines.Text := ASQL;
end;

function TFrameQueryTab.GetSQLText: string;
begin
  Result := synEditor.Lines.Text;
end;

procedure TFrameQueryTab.SetIsExecuting(const AValue: Boolean);
begin
  FIsExecuting := AValue;

  btnExecuteSelection.Enabled := not FIsExecuting;
  btnExecuteR.Enabled := not FIsExecuting;
  btnExplain.Enabled := not FIsExecuting;
  btnCancel.Enabled := FIsExecuting;
  prgExecuting.Visible := FIsExecuting;

  if FIsExecuting then
  begin
    lblStatusInfo.Caption := 'Execute Query...';
    prgExecuting.Style := pbstMarquee;
  end
  else
  begin
    lblStatusInfo.Caption := 'Ready.';
    prgExecuting.Style := pbstNormal;
  end;
end;

procedure TFrameQueryTab.AppendLogMessage(const AMessage: string; const AIsError: Boolean);
var
  TimePrefix, FormattedMsg: string;
begin
  TimePrefix := FormatDateTime('[hh:nn:ss] ', Now);
  FormattedMsg := TimePrefix + AMessage;
  memMessages.Lines.Add(FormattedMsg);

  if AIsError then
    pgcResults.ActivePage := tabMessages;
end;

procedure TFrameQueryTab.ExecuteSQL(const ASQL: string);
var
  CleanSQL: string;
  Analysis: TSafeGuardAnalysis;
begin
  CleanSQL := Trim(ASQL);
  if CleanSQL = '' then
  begin
    AppendLogMessage('No SQL text to execute.', True);
    Exit;
  end;

  if FIsExecuting then
  begin
    AppendLogMessage('Warning: Another query is already running in this tab session.', True);
    Exit;
  end;

  // 1. Safe Mode Guardrail
  Analysis := TSafeModeGuardrails.AnalyzeQuery(FProfile, FDatabaseTarget, CleanSQL);
  if Analysis.IsDestructive then
  begin
    if not TFormSafeModeWarning.PromptConfirmation(Self, Analysis, FDatabaseTarget) then
    begin
      AppendLogMessage('Query execution canceled by Safe Mode Guardrail.', True);
      SQLLogger.LogComment(Format('Execution prevented by Safe Mode Guardrail: %s', [Analysis.Title]));
      Exit;
    end;

    SQLLogger.LogComment(Format('WARNING: User confirmed Safe Mode bypass for operation: %s', [Analysis.AffectedOperation]));
  end;

  // 2. Bersihkan visual dataset lama (Grid, Chart, dan Map)
  if Assigned(FFrameDataGrid) then
    FFrameDataGrid.Clear;

  if Assigned(FFrameVisualChart) then
    FFrameVisualChart.Clear;

  if Assigned(FMapFrame) then
    FMapFrame.ClearMap;

  if Assigned(FWorker) then
  begin
    FWorker.OnProgress := nil;
    FWorker.OnSuccess := nil;
    FWorker.OnError := nil;
    try
      FWorker.WaitFor;
    except
    end;
    FreeAndNil(FWorker);
  end;

  // 3. Eksekusi Kueri Baru di Background Thread
  FLastExecutedSQL := CleanSQL;
  SetIsExecuting(True);

  FWorker := TQueryWorkerThread.Create(FProfile, CleanSQL, FDatabaseTarget);
  FWorker.OnProgress := @HandleWorkerProgress;
  FWorker.OnSuccess := @HandleWorkerSuccess;
  FWorker.OnError := @HandleWorkerError;
  FWorker.Start;
end;

procedure TFrameQueryTab.ExecuteCurrentOrSelected;
var
  TargetSQL: string;
begin
  if Trim(synEditor.SelText) <> '' then
    TargetSQL := synEditor.SelText
  else
    TargetSQL := synEditor.Lines.Text;

  ExecuteSQL(TargetSQL);
end;

procedure TFrameQueryTab.CancelExecution;
begin
  if FIsExecuting and Assigned(FWorker) then
  begin
    AppendLogMessage('Canceling query execution...');
    FWorker.CancelExecution;
  end;
end;

procedure TFrameQueryTab.HandleWorkerProgress(Sender: TObject; const AMessage: string);
begin
  if not (csDestroying in ComponentState) then
    lblStatusInfo.Caption := AMessage;
end;

procedure TFrameQueryTab.HandleWorkerSuccess(Sender: TObject; const AResult: TDBQueryResult; AQuery: TZQuery);
begin
  SetIsExecuting(False);

  HistoryService.LogExecution(FProfile.ID, FDatabaseTarget, FLastExecutedSQL, AResult);
  SQLLogger.LogSQL(FLastExecutedSQL, AResult.ExecutionTimeMS, AResult.RowsAffected);

  if (AResult.StatementType = stSelect) and Assigned(AQuery) and AQuery.Active then
  begin
    // Hubungkan dataset ke Grid Data
    FFrameDataGrid.AttachDataSet(AQuery, AResult.ExecutionTimeMS, AResult.RowsAffected);

    // Hubungkan dataset ke Visual Chart
    if Assigned(FFrameVisualChart) then
      FFrameVisualChart.AttachDataSet(AQuery);

    // Hubungkan dataset ke Peta Geospasial lazmapviewer
    if Assigned(FMapFrame) then
      FMapFrame.SetDataSet(AQuery);

    pgcResults.ActivePage := tabData;
    AppendLogMessage(Format('SELECT query succeeded: %d rows returned (%d ms)."', [
      AResult.RowsAffected,
      AResult.ExecutionTimeMS
    ]));
  end
  else
  begin
    FFrameDataGrid.Clear;
    if Assigned(FFrameVisualChart) then
      FFrameVisualChart.Clear;
    if Assigned(FMapFrame) then
      FMapFrame.ClearMap;

    pgcResults.ActivePage := tabMessages;
    AppendLogMessage(Format('DDL/DML statement executed successfully: %d rows affected (%d ms).', [
      AResult.RowsAffected,
      AResult.ExecutionTimeMS
    ]));
  end;
end;

procedure TFrameQueryTab.HandleWorkerError(Sender: TObject; const AResult: TDBQueryResult);
begin
  SetIsExecuting(False);

  HistoryService.LogExecution(FProfile.ID, FDatabaseTarget, FLastExecutedSQL, AResult);
  SQLLogger.LogError(AResult.ErrorMessage, FLastExecutedSQL);

  AppendLogMessage(Format('Kesalahan Eksekusi SQL (%d ms): %s', [
    AResult.ExecutionTimeMS,
    AResult.ErrorMessage
  ]), True);

  btnAIDiagnose.Visible := True;
  btnAIDiagnose.Caption := '🤖 Diagnosa & Perbaiki dengan AI...';
end;

procedure TFrameQueryTab.RenderExplainPlan(const APlan: TDBExecutionPlanArray);
var
  I, RowIdx: Integer;
begin
  gridExplain.RowCount := 1;
  gridExplain.RowCount := Length(APlan) + 1;

  for I := 0 to High(APlan) do
  begin
    RowIdx := I + 1;
    gridExplain.Cells[0, RowIdx] := IntToStr(APlan[I].ID);
    gridExplain.Cells[1, RowIdx] := APlan[I].Operation;
    gridExplain.Cells[2, RowIdx] := APlan[I].TargetObject;
    gridExplain.Cells[3, RowIdx] := IntToStr(APlan[I].EstimatedRows);
    gridExplain.Cells[4, RowIdx] := APlan[I].Details;
  end;

  pgcResults.ActivePage := tabExplain;
end;

procedure TFrameQueryTab.btnExplainClick(Sender: TObject);
var
  Driver: TDBDriverBase;
  Plan: TDBExecutionPlanArray;
  TargetSQL: string;
begin
  if Trim(synEditor.SelText) <> '' then
    TargetSQL := synEditor.SelText
  else
    TargetSQL := synEditor.Lines.Text;

  if Trim(TargetSQL) = '' then Exit;

  Driver := nil;
  try
    Driver := TDBConnectionFactory.CreateDriver(FProfile);
    if Driver.GetExplainPlan(TargetSQL, Plan) then
    begin
      RenderExplainPlan(Plan);
      AppendLogMessage('Rencana eksekusi (Execution Plan) berhasil dimuat.');
    end
    else
      AppendLogMessage('Driver database tidak mendukung atau gagal menghasilkan Explain Plan.', True);
  finally
    if Assigned(Driver) then
      Driver.Free;
  end;
end;

procedure TFrameQueryTab.btnExecuteClick(Sender: TObject);
begin
  ExecuteSQL(synEditor.Lines.Text);
end;

procedure TFrameQueryTab.btnExecuteRClick(Sender: TObject);
begin
  if Trim(synEditor.SelText) <> '' then
    ExecuteSQL(synEditor.SelText)
  else
    ExecuteSQL(synEditor.Lines.Text);
end;

procedure TFrameQueryTab.btnCancelClick(Sender: TObject);
begin
  CancelExecution;
end;

procedure TFrameQueryTab.btnFormatSQLClick(Sender: TObject);
var
  Formatted: string;
begin
  Formatted := synEditor.Lines.Text;
  Formatted := StringReplace(Formatted, 'select ', 'SELECT ', [rfReplaceAll, rfIgnoreCase]);
  Formatted := StringReplace(Formatted, ' from ', LineEnding + 'FROM ', [rfReplaceAll, rfIgnoreCase]);
  Formatted := StringReplace(Formatted, ' where ', LineEnding + 'WHERE ', [rfReplaceAll, rfIgnoreCase]);
  Formatted := StringReplace(Formatted, ' group by ', LineEnding + 'GROUP BY ', [rfReplaceAll, rfIgnoreCase]);
  Formatted := StringReplace(Formatted, ' order by ', LineEnding + 'ORDER BY ', [rfReplaceAll, rfIgnoreCase]);
  Formatted := StringReplace(Formatted, ' join ', LineEnding + 'JOIN ', [rfReplaceAll, rfIgnoreCase]);
  Formatted := StringReplace(Formatted, ' left join ', LineEnding + 'LEFT JOIN ', [rfReplaceAll, rfIgnoreCase]);
  Formatted := StringReplace(Formatted, ' inner join ', LineEnding + 'INNER JOIN ', [rfReplaceAll, rfIgnoreCase]);

  synEditor.Lines.Text := Formatted;
end;

procedure TFrameQueryTab.btnClearSQLClick(Sender: TObject);
begin
  synEditor.Clear;
end;

procedure TFrameQueryTab.btnQueryBuilderClick(Sender: TObject);
var
  GeneratedSQL: string;
begin
  if TFormQueryBuilder.Execute(Self, FProfile, GeneratedSQL) then
  begin
    if Trim(GeneratedSQL) <> '' then
    begin
      synEditor.Lines.Text := GeneratedSQL;
      AppendLogMessage('SQL query successfully loaded from the Visual Query Builder.');
    end;
  end;
end;

procedure TFrameQueryTab.btnAIDiagnoseClick(Sender: TObject);
var
  FixedSQL, LastError: string;
begin
  if memMessages.Lines.Count > 0 then
    LastError := memMessages.Lines[memMessages.Lines.Count - 1]
  else
    LastError := 'Query execution failed.';

  if TFormAIDiagnostic.ExecuteDiagnostic(
    Self,
    FProfile,
    FLastExecutedSQL,
    LastError,
    FDatabaseTarget,
    FixedSQL
  ) then
  begin
    if Trim(FixedSQL) <> '' then
    begin
      synEditor.Lines.Text := FixedSQL;
      pgcResults.ActivePage := tabData;
      AppendLogMessage('SQL query has been automatically updated using AI fix suggestions.');
    end;
  end;
end;

procedure TFrameQueryTab.btnAIOptimizerClick(Sender: TObject);
var
  TargetSQL, OptimizedSQL: string;
begin
  if Trim(synEditor.SelText) <> '' then
    TargetSQL := synEditor.SelText
  else
    TargetSQL := synEditor.Lines.Text;

  if Trim(TargetSQL) = '' then
  begin
    MessageDlg('Information', 'Please write an SQL query in the editor first to optimize it.', mtInformation, [mbOK], 0);
    Exit;
  end;

  if TFormAIOptimizer.ExecuteOptimizer(
    Self,
    FProfile,
    TargetSQL,
    FDatabaseTarget,
    OptimizedSQL
  ) then
  begin
    if Trim(OptimizedSQL) <> '' then
    begin
      if Trim(synEditor.SelText) <> '' then
        synEditor.SelText := OptimizedSQL
      else
        synEditor.Lines.Text := OptimizedSQL;

      AppendLogMessage('SQL query successfully replaced with the AI-optimized version.');
    end;
  end;
end;

procedure TFrameQueryTab.btnAIExplainDocClick(Sender: TObject);
var
  TargetSQL, AnnotatedSQL: string;
begin
  if Trim(synEditor.SelText) <> '' then
    TargetSQL := synEditor.SelText
  else
    TargetSQL := synEditor.Lines.Text;

  if Trim(TargetSQL) = '' then
  begin
    MessageDlg('Information', 'Please write or select an SQL query in the editor to be explained.', mtInformation, [mbOK], 0);
    Exit;
  end;

  if TFormAIExplainer.ExecuteExplainer(
    Self,
    FProfile,
    TargetSQL,
    FDatabaseTarget,
    AnnotatedSQL
  ) then
  begin
    if Trim(AnnotatedSQL) <> '' then
    begin
      if Trim(synEditor.SelText) <> '' then
        synEditor.SelText := AnnotatedSQL
      else
        synEditor.Lines.Text := AnnotatedSQL;

      AppendLogMessage('SQL query successfully updated with annotations and documentation comments.');
    end;
  end;
end;

procedure TFrameQueryTab.RefreshGridDisplay;
begin
  if Assigned(FFrameDataGrid) then
    FFrameDataGrid.RefreshGridDisplay;
end;

end.
