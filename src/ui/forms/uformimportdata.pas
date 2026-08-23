unit uFormImportData;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  ComCtrls, StdCtrls, Buttons, Grids,
  fpjson, jsonparser,Math,
  uAppTypes, uDBTypes, uModelConnection, uDBDriverBase, uDBConnectionFactory,
  uModelSchemaObject, uImportWorkerThread;

type
  { TFormImportData }
  TFormImportData = class(TForm)
    pnlTop: TPanel;
    lblSourceFile: TLabel;
    edtSourceFile: TEdit;
    btnBrowseFile: TSpeedButton;
    lblFormat: TLabel;
    cboFormat: TComboBox;
    lblTargetTable: TLabel;
    cboTargetTable: TComboBox;

    pnlCSVOptions: TPanel;
    lblDelimiter: TLabel;
    cboDelimiter: TComboBox;
    chkHasHeader: TCheckBox;

    pgcMain: TPageControl;
    tabMapping: TTabSheet;
    tabPreview: TTabSheet;

    gridMapping: TStringGrid;
    gridPreview: TStringGrid;

    pnlBottom: TPanel;
    lblBatchSize: TLabel;
    edtBatchSize: TEdit;
    lblErrorAction: TLabel;
    cboErrorAction: TComboBox;
    prgImport: TProgressBar;
    lblStatus: TLabel;
    btnStartImport: TBitBtn;
    btnCancel: TBitBtn;
    btnClose: TBitBtn;

    openDialog: TOpenDialog;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);

    procedure btnBrowseFileClick(Sender: TObject);
    procedure cboFormatChange(Sender: TObject);
    procedure cboTargetTableChange(Sender: TObject);
    procedure cboDelimiterChange(Sender: TObject);
    procedure chkHasHeaderChange(Sender: TObject);

    procedure gridMappingEditingDone(Sender: TObject);
    procedure btnStartImportClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
  private
    FProfile: TConnectionProfile;
    FDriver: TDBDriverBase;
    FWorker: TImportWorkerThread;
    FSourceHeaders: TStringList;
    FTableColumns: TSchemaColumnList;

    procedure LoadDatabaseTables;
    procedure LoadTableColumns(const ATableName: string);
    procedure LoadFilePreview;
    procedure AutoMatchColumns;
    procedure SetUIExecuting(const AExecuting: Boolean);

    procedure HandleWorkerProgress(Sender: TObject; const ACurrentRow, ATotalRows: Int64; const AStatusText: string);
    procedure HandleWorkerComplete(Sender: TObject; const ATotalImported, ATotalSkipped: Int64; const AElapsedMS: Int64);
    procedure HandleWorkerError(Sender: TObject; const AError: string);
  public
    class procedure Execute(AOwner: TComponent; AProfile: TConnectionProfile; const ADefaultTable: string = '');
    property Profile: TConnectionProfile read FProfile write FProfile;
  end;

implementation

{$R *.lfm}

{ TFormImportData }

class procedure TFormImportData.Execute(AOwner: TComponent; AProfile: TConnectionProfile; const ADefaultTable: string);
var
  Frm: TFormImportData;
begin
  Frm := TFormImportData.Create(AOwner);
  try
    Frm.Profile := AProfile;
    if ADefaultTable <> '' then
      Frm.cboTargetTable.Text := ADefaultTable;
    Frm.ShowModal;
  finally
    Frm.Free;
  end;
end;

procedure TFormImportData.FormCreate(Sender: TObject);
begin
  FDriver := nil;
  FWorker := nil;
  FSourceHeaders := TStringList.Create;
  FTableColumns := TSchemaColumnList.Create;

  gridMapping.ColCount := 4;
  gridMapping.RowCount := 1;
  gridMapping.Cells[0, 0] := 'Field Berkas Sumber';
  gridMapping.Cells[1, 0] := '->';
  gridMapping.Cells[2, 0] := 'Kolom Tabel Target';
  gridMapping.Cells[3, 0] := 'Tipe Data Database';
  gridMapping.ColWidths[0] := 200;
  gridMapping.ColWidths[1] := 40;
  gridMapping.ColWidths[2] := 200;
  gridMapping.ColWidths[3] := 150;
end;

procedure TFormImportData.FormDestroy(Sender: TObject);
begin
  if Assigned(FWorker) then
  begin
    FWorker.Terminate;
    FWorker.WaitFor;
    FreeAndNil(FWorker);
  end;

  FTableColumns.Free;
  FSourceHeaders.Free;
  if Assigned(FDriver) then
    FreeAndNil(FDriver);
  //inherited Destroy;
end;

procedure TFormImportData.FormShow(Sender: TObject);
begin
  if Assigned(FProfile) then
  begin
    Caption := Format('Data Importer Wizard - [%s]', [FProfile.ConnectionName]);
    if Assigned(FDriver) then
      FreeAndNil(FDriver);
    FDriver := TDBConnectionFactory.CreateDriver(FProfile);
    LoadDatabaseTables;
  end;
end;

procedure TFormImportData.LoadDatabaseTables;
var
  TablesList: TSchemaObjectList;
  I: Integer;
  SavedTable: string;
begin
  SavedTable := cboTargetTable.Text;
  cboTargetTable.Items.Clear;
  if not Assigned(FDriver) then Exit;

  TablesList := TSchemaObjectList.Create;
  try
    FDriver.ExtractTables('', '', TablesList);
    for I := 0 to TablesList.Count - 1 do
      cboTargetTable.Items.Add(TablesList[I].Name);

    if SavedTable <> '' then
      cboTargetTable.Text := SavedTable
    else if cboTargetTable.Items.Count > 0 then
      cboTargetTable.ItemIndex := 0;

    if cboTargetTable.Text <> '' then
      LoadTableColumns(cboTargetTable.Text);
  finally
    TablesList.Free;
  end;
end;

procedure TFormImportData.LoadTableColumns(const ATableName: string);
begin
  FTableColumns.Clear;
  if Assigned(FDriver) and (ATableName <> '') then
  begin
    try
      FDriver.ExtractColumns('', '', ATableName, FTableColumns);
    except
    end;
  end;
  AutoMatchColumns;
end;

procedure TFormImportData.LoadFilePreview;
var
  FileExt, Line, DelimChar: string;
  SL, Tokens: TStringList;
  I, J, LimitPreview: Integer;
  Parser: TJSONParser;
  JSONData: TJSONData;
  JSONArray: TJSONArray;
  RowObj: TJSONObject;
  FileStream: TFileStream;
begin
  gridPreview.RowCount := 1;
  gridPreview.ColCount := 1;
  FSourceHeaders.Clear;

  if not FileExists(edtSourceFile.Text) then Exit;
  FileExt := LowerCase(ExtractFileExt(edtSourceFile.Text));

  if FileExt = '.json' then
  begin
    FileStream := TFileStream.Create(edtSourceFile.Text, fmOpenRead or fmShareDenyNone);
    try
      Parser := TJSONParser.Create(FileStream);
      try
        JSONData := Parser.Parse;
        try
          if JSONData is TJSONArray then
          begin
            JSONArray := TJSONArray(JSONData);
            if JSONArray.Count > 0 then
            begin
              RowObj := TJSONObject(JSONArray.Objects[0]);
              gridPreview.ColCount := RowObj.Count;
              for J := 0 to RowObj.Count - 1 do
              begin
                gridPreview.Cells[J, 0] := RowObj.Names[J];
                FSourceHeaders.Add(RowObj.Names[J]);
              end;

              LimitPreview := Min(15, JSONArray.Count);
              gridPreview.RowCount := LimitPreview + 1;
              for I := 0 to LimitPreview - 1 do
              begin
                RowObj := TJSONObject(JSONArray.Objects[I]);
                for J := 0 to RowObj.Count - 1 do
                  gridPreview.Cells[J, I + 1] := RowObj.Get(RowObj.Names[J], '');
              end;
            end;
          end;
        finally
          JSONData.Free;
        end;
      finally
        Parser.Free;
      end;
    finally
      FileStream.Free;
    end;
  end
  else
  begin
    // CSV / Delimited File Preview
    SL := TStringList.Create;
    try
      SL.LoadFromFile(edtSourceFile.Text);
      if SL.Count > 0 then
      begin
        if cboDelimiter.Text = 'Titik Koma (;)' then DelimChar := ';'
        else if cboDelimiter.Text = 'Tab (\t)' then DelimChar := #9
        else DelimChar := ',';

        Tokens := TStringList.Create;
        try
          // Header
          Line := SL[0];
          Tokens.Delimiter := DelimChar[1];
          Tokens.StrictDelimiter := True;
          Tokens.DelimitedText := Line;

          gridPreview.ColCount := Max(1, Tokens.Count);
          for J := 0 to Tokens.Count - 1 do
          begin
            if chkHasHeader.Checked then
            begin
              gridPreview.Cells[J, 0] := Tokens[J];
              FSourceHeaders.Add(Tokens[J]);
            end
            else
            begin
              gridPreview.Cells[J, 0] := 'Kolom_' + IntToStr(J + 1);
              FSourceHeaders.Add('Kolom_' + IntToStr(J + 1));
            end;
          end;

          // Baris data
          LimitPreview := Min(15, SL.Count - 1);
          gridPreview.RowCount := LimitPreview + 1;

          for I := 1 to LimitPreview do
          begin
            Tokens.DelimitedText := SL[I];
            for J := 0 to Tokens.Count - 1 do
            begin
              if J < gridPreview.ColCount then
                gridPreview.Cells[J, I] := Tokens[J];
            end;
          end;
        finally
          Tokens.Free;
        end;
      end;
    finally
      SL.Free;
    end;
  end;

  AutoMatchColumns;
end;

procedure TFormImportData.AutoMatchColumns;
var
  I, J, RowIdx: Integer;
  SrcHeader: string;
  ColMatch: TSchemaColumn;
begin
  gridMapping.RowCount := 1;

  for I := 0 to FSourceHeaders.Count - 1 do
  begin
    SrcHeader := FSourceHeaders[I];
    gridMapping.RowCount := gridMapping.RowCount + 1;
    RowIdx := gridMapping.RowCount - 1;

    gridMapping.Cells[0, RowIdx] := SrcHeader;
    gridMapping.Cells[1, RowIdx] := '->';

    ColMatch := nil;
    for J := 0 to FTableColumns.Count - 1 do
    begin
      if SameText(FTableColumns[J].Name, SrcHeader) then
      begin
        ColMatch := FTableColumns[J];
        Break;
      end;
    end;

    if Assigned(ColMatch) then
    begin
      gridMapping.Cells[2, RowIdx] := ColMatch.Name;
      gridMapping.Cells[3, RowIdx] := ColMatch.DataType;
    end
    else
    begin
      gridMapping.Cells[2, RowIdx] := '[LEWATI]';
      gridMapping.Cells[3, RowIdx] := '-';
    end;
  end;
end;

procedure TFormImportData.gridMappingEditingDone(Sender: TObject);
var
  RowIdx, J: Integer;
  TargetName: string;
begin
  RowIdx := gridMapping.Row;
  if RowIdx < 1 then Exit;

  TargetName := Trim(gridMapping.Cells[2, RowIdx]);
  for J := 0 to FTableColumns.Count - 1 do
  begin
    if SameText(FTableColumns[J].Name, TargetName) then
    begin
      gridMapping.Cells[3, RowIdx] := FTableColumns[J].DataType;
      Exit;
    end;
  end;

  if (TargetName = '') or (UpperCase(TargetName) = '[LEWATI]') then
  begin
    gridMapping.Cells[2, RowIdx] := '[LEWATI]';
    gridMapping.Cells[3, RowIdx] := '-';
  end;
end;

procedure TFormImportData.btnBrowseFileClick(Sender: TObject);
var
  Ext: string;
begin
  if openDialog.Execute then
  begin
    edtSourceFile.Text := openDialog.FileName;
    Ext := LowerCase(ExtractFileExt(openDialog.FileName));

    if Ext = '.json' then cboFormat.ItemIndex := 1
    else if Ext = '.sql' then cboFormat.ItemIndex := 2
    else cboFormat.ItemIndex := 0;

    cboFormatChange(Sender);
    LoadFilePreview;
  end;
end;

procedure TFormImportData.cboFormatChange(Sender: TObject);
begin
  pnlCSVOptions.Visible := (cboFormat.ItemIndex = 0);
  tabMapping.TabVisible := (cboFormat.ItemIndex in [0, 1]);
end;

procedure TFormImportData.cboTargetTableChange(Sender: TObject);
begin
  LoadTableColumns(cboTargetTable.Text);
end;

procedure TFormImportData.cboDelimiterChange(Sender: TObject);
begin
  LoadFilePreview;
end;

procedure TFormImportData.chkHasHeaderChange(Sender: TObject);
begin
  LoadFilePreview;
end;

procedure TFormImportData.SetUIExecuting(const AExecuting: Boolean);
begin
  btnStartImport.Enabled := not AExecuting;
  btnCancel.Enabled := AExecuting;
  btnClose.Enabled := not AExecuting;
  btnBrowseFile.Enabled := not AExecuting;
  cboFormat.Enabled := not AExecuting;
  cboTargetTable.Enabled := not AExecuting;
  gridMapping.Enabled := not AExecuting;
end;

procedure TFormImportData.btnStartImportClick(Sender: TObject);
var
  Mappings: TColumnMappingArray;
  I, MappedCount: Integer;
  TargetCol: string;
  DelimChar: Char;
  Fmt: TImportFileFormat;
  ErrAct: TImportErrorAction;
begin
  if not FileExists(edtSourceFile.Text) then
  begin
    MessageDlg('Peringatan', 'Silakan pilih berkas sumber yang valid terlebih dahulu.', mtWarning, [mbOK], 0);
    Exit;
  end;

  if (cboFormat.ItemIndex in [0, 1]) and (Trim(cboTargetTable.Text) = '') then
  begin
    MessageDlg('Peringatan', 'Pilih tabel target database tujuan impor.', mtWarning, [mbOK], 0);
    Exit;
  end;

  case cboFormat.ItemIndex of
    1: Fmt := iffJSON;
    2: Fmt := iffSQL;
    else Fmt := iffCSV;
  end;

  // Persiapkan mapping array
  SetLength(Mappings, gridMapping.RowCount - 1);
  MappedCount := 0;

  for I := 1 to gridMapping.RowCount - 1 do
  begin
    Mappings[I - 1].SourceIndex := I - 1;
    Mappings[I - 1].SourceFieldName := gridMapping.Cells[0, I];
    TargetCol := Trim(gridMapping.Cells[2, I]);

    if (TargetCol <> '') and (TargetCol <> '[LEWATI]') then
    begin
      Mappings[I - 1].TargetColumnName := TargetCol;
      Mappings[I - 1].TargetDataType := gridMapping.Cells[3, I];
      Mappings[I - 1].IsMapped := True;
      Inc(MappedCount);
    end
    else
      Mappings[I - 1].IsMapped := False;
  end;

  if (Fmt in [iffCSV, iffJSON]) and (MappedCount = 0) then
  begin
    MessageDlg('Peringatan', 'Paling tidak satu kolom sumber harus dipetakan ke tabel database.', mtWarning, [mbOK], 0);
    Exit;
  end;

  if cboDelimiter.Text = 'Titik Koma (;)' then DelimChar := ';'
  else if cboDelimiter.Text = 'Tab (\t)' then DelimChar := #9
  else DelimChar := ',';

  if cboErrorAction.ItemIndex = 1 then
    ErrAct := ieaSkipRow
  else
    ErrAct := ieaAbort;

  SetUIExecuting(True);
  prgImport.Position := 0;
  lblStatus.Caption := 'Memulai proses impor data...';

  if Assigned(FWorker) then
  begin
    FWorker.WaitFor;
    FreeAndNil(FWorker);
  end;

  FWorker := TImportWorkerThread.Create(
    FProfile,
    edtSourceFile.Text,
    Fmt,
    cboTargetTable.Text,
    Mappings,
    DelimChar,
    chkHasHeader.Checked,
    StrToIntDef(Trim(edtBatchSize.Text), 500),
    ErrAct
  );
  FWorker.OnProgress := @HandleWorkerProgress;
  FWorker.OnComplete := @HandleWorkerComplete;
  FWorker.OnError := @HandleWorkerError;
  FWorker.Start;
end;

procedure TFormImportData.btnCancelClick(Sender: TObject);
begin
  if Assigned(FWorker) then
  begin
    lblStatus.Caption := 'Membatalkan proses impor...';
    FWorker.Terminate;
  end;
end;

procedure TFormImportData.btnCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TFormImportData.HandleWorkerProgress(Sender: TObject; const ACurrentRow, ATotalRows: Int64; const AStatusText: string);
begin
  lblStatus.Caption := AStatusText;
  if ATotalRows > 0 then
    prgImport.Position := Min(100, (ACurrentRow * 100) div ATotalRows);
end;

procedure TFormImportData.HandleWorkerComplete(Sender: TObject; const ATotalImported, ATotalSkipped: Int64; const AElapsedMS: Int64);
begin
  SetUIExecuting(False);
  prgImport.Position := 100;
  lblStatus.Caption := Format('Selesai! %d baris berhasil diimpor (%d baris dilewati) dalam %d ms.', [ATotalImported, ATotalSkipped, AElapsedMS]);
  MessageDlg('Impor Selesai', Format('Data berhasil diimpor ke database!%s%s- Berhasil: %d baris%s- Dilewati/Error: %d baris%s- Waktu: %d ms', [
    LineEnding, LineEnding, ATotalImported, LineEnding, ATotalSkipped, LineEnding, AElapsedMS
  ]), mtInformation, [mbOK], 0);
end;

procedure TFormImportData.HandleWorkerError(Sender: TObject; const AError: string);
begin
  SetUIExecuting(False);
  lblStatus.Caption := 'Impor gagal.';
  MessageDlg('Kesalahan Impor', AError, mtError, [mbOK], 0);
end;

end.
