unit uFormRecordView;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  ComCtrls, StdCtrls, Buttons, Grids, Clipbrd, DB,
  SynEdit,
  ZDataset,
  // Unit Decoder & Encoder Grafis Lazarus / FPC
  FPReadPNG, FPReadJPEG, FPReadGIF, FPReadBMP,
  FPWritePNG, FPWriteJPEG,
  uAppTypes, uDBTypes;

type
  { TFormRecordView }
  TFormRecordView = class(TForm)
    synValue: TMemo;
    pnlToolbar: TPanel;
    btnFirst: TSpeedButton;
    btnPrior: TSpeedButton;
    btnNext: TSpeedButton;
    btnLast: TSpeedButton;
    sepNav: TBevel;
    lblRecInfo: TLabel;
    btnAddRecord: TSpeedButton;
    btnDeleteRecord: TSpeedButton;
    btnPost: TSpeedButton;
    btnCancelEdit: TSpeedButton;
    sepEdit: TBevel;
    btnCopyRecord: TSpeedButton;
    btnRefresh: TSpeedButton;

    pnlMain: TPanel;
    gridFields: TStringGrid;
    splDetailSide: TSplitter;
    splSplitter: TSplitter;

    pnlDetailEditor: TPanel;
    pnlDetailHeader: TPanel;
    lblActiveFieldName: TLabel;
    lblFieldSize: TLabel;
    btnLoadPicture: TSpeedButton;
    btnSavePicture: TSpeedButton;
    btnSetNull: TSpeedButton;
    btnApplyFieldDetail: TSpeedButton;

    pnlDetailBody: TPanel;
    pnlImageContainer: TPanel;
    imgPreview: TImage;

    openPicDialog: TOpenDialog;
    savePicDialog: TSaveDialog;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);

    procedure btnFirstClick(Sender: TObject);
    procedure btnPriorClick(Sender: TObject);
    procedure btnNextClick(Sender: TObject);
    procedure btnLastClick(Sender: TObject);
    procedure btnRefreshClick(Sender: TObject);

    procedure btnAddRecordClick(Sender: TObject);
    procedure btnDeleteRecordClick(Sender: TObject);
    procedure btnPostClick(Sender: TObject);
    procedure btnCancelEditClick(Sender: TObject);
    procedure btnCopyRecordClick(Sender: TObject);

    procedure gridFieldsSelectCell(Sender: TObject; aCol, aRow: Integer; var CanSelect: Boolean);
    procedure gridFieldsEditingDone(Sender: TObject);
    procedure btnSetNullClick(Sender: TObject);
    procedure btnApplyFieldDetailClick(Sender: TObject);
    procedure btnLoadPictureClick(Sender: TObject);
    procedure btnSavePictureClick(Sender: TObject);
  private
    FDataSet: TZQuery;
    FCurrentFieldIndex: Integer;
    FIsModified: Boolean;

    function ExtractBlobToStream(AField: TField; AOutStream: TMemoryStream): Boolean;
    function DetectImageExtension(AStream: TStream; out AOffset: Integer): string;
    function TryLoadImageFromStream(AStream: TStream; APicture: TPicture; out AFormatName: string): Boolean;
    function GenerateHexDump(AStream: TStream; AMaxBytes: Integer = 2048): string;
    function IsBlobOrGraphicField(AField: TField): Boolean;

    procedure EnsureEditOrInsertState;
    procedure RefreshRecordData;
    procedure UpdateNavigationUI;
    procedure LoadFieldDetail(const AFieldIdx: Integer);
    procedure ApplyCurrentDetailValue;
  public
    class procedure Execute(AOwner: TComponent; ADataSet: TZQuery);
    property DataSet: TZQuery read FDataSet write FDataSet;
  end;

implementation

{$R *.lfm}

{ TFormRecordView }

class procedure TFormRecordView.Execute(AOwner: TComponent; ADataSet: TZQuery);
var
  Frm: TFormRecordView;
begin
  if not Assigned(ADataSet) or not ADataSet.Active then
  begin
    MessageDlg('Informasi', 'Dataset kueri tidak aktif.', mtInformation, [mbOK], 0);
    Exit;
  end;

  Frm := TFormRecordView.Create(AOwner);
  try
    Frm.DataSet := ADataSet;
    Frm.ShowModal;
  finally
    Frm.Free;
  end;
end;

procedure TFormRecordView.FormCreate(Sender: TObject);
begin
  FDataSet := nil;
  FCurrentFieldIndex := 0;
  FIsModified := False;

  gridFields.ColCount := 4;
  gridFields.RowCount := 1;
  gridFields.Cells[0, 0] := 'Nama Kolom';
  gridFields.Cells[1, 0] := 'Tipe Data';
  gridFields.Cells[2, 0] := 'NULL?';
  gridFields.Cells[3, 0] := 'Nilai';

  gridFields.ColWidths[0] := 160;
  gridFields.ColWidths[1] := 110;
  gridFields.ColWidths[2] := 60;
  gridFields.ColWidths[3] := 380;
end;

procedure TFormRecordView.FormDestroy(Sender: TObject);
begin
end;

procedure TFormRecordView.FormShow(Sender: TObject);
begin
  RefreshRecordData;
end;

function TFormRecordView.IsBlobOrGraphicField(AField: TField): Boolean;
begin
  Result := Assigned(AField) and (
    (AField is TBlobField) or
    (AField.DataType in [ftBlob, ftMemo, ftGraphic, ftFmtMemo, ftParadoxOle,
                         ftDBaseOle, ftTypedBinary, ftCursor, ftOraBlob, ftOraClob])
  );
end;

function TFormRecordView.ExtractBlobToStream(AField: TField; AOutStream: TMemoryStream): Boolean;
var
  BlobStream: TStream;
begin
  Result := False;
  AOutStream.Clear;
  if not Assigned(AField) or AField.IsNull then Exit;

  try
    BlobStream := FDataSet.CreateBlobStream(AField, bmRead);
    try
      if Assigned(BlobStream) and (BlobStream.Size > 0) then
      begin
        AOutStream.CopyFrom(BlobStream, BlobStream.Size);
        Result := (AOutStream.Size > 0);
      end;
    finally
      BlobStream.Free;
    end;
  except
  end;

  if (not Result) and (AField is TBlobField) then
  begin
    try
      TBlobField(AField).SaveToStream(AOutStream);
      Result := (AOutStream.Size > 0);
    except
    end;
  end;

  AOutStream.Position := 0;
end;

function TFormRecordView.DetectImageExtension(AStream: TStream; out AOffset: Integer): string;
var
  Buffer: array[0..4095] of Byte;
  ReadBytes, I: Integer;
begin
  Result := '';
  AOffset := 0;
  if not Assigned(AStream) or (AStream.Size < 4) then Exit;

  AStream.Position := 0;
  ReadBytes := AStream.Read(Buffer, SizeOf(Buffer));
  AStream.Position := 0;

  if ReadBytes < 4 then Exit;

  // 1. Cek Signature dari Offset 0
  if (ReadBytes >= 8) and (Buffer[0] = $89) and (Buffer[1] = $50) and (Buffer[2] = $4E) and (Buffer[3] = $47) then
    Exit('png');

  if (Buffer[0] = $FF) and (Buffer[1] = $D8) then
    Exit('jpg');

  if (Buffer[0] = $42) and (Buffer[1] = $4D) then
    Exit('bmp');

  if (ReadBytes >= 6) and (Buffer[0] = $47) and (Buffer[1] = $49) and (Buffer[2] = $46) and (Buffer[3] = $38) then
    Exit('gif');

  if (ReadBytes >= 4) and (Buffer[0] = $00) and (Buffer[1] = $00) and (Buffer[2] = $01) and (Buffer[3] = $00) then
    Exit('ico');

  // 2. Scan Buffer jika terdapat metadata / OLE header di depannya
  for I := 0 to ReadBytes - 8 do
  begin
    if (Buffer[I] = $89) and (Buffer[I+1] = $50) and (Buffer[I+2] = $4E) and (Buffer[I+3] = $47) then
    begin
      AOffset := I;
      Exit('png');
    end;
    if (Buffer[I] = $FF) and (Buffer[I+1] = $D8) and (Buffer[I+2] = $FF) then
    begin
      AOffset := I;
      Exit('jpg');
    end;
    if (Buffer[I] = $47) and (Buffer[I+1] = $49) and (Buffer[I+2] = $46) and (Buffer[I+3] = $38) then
    begin
      AOffset := I;
      Exit('gif');
    end;
  end;
end;

function TFormRecordView.TryLoadImageFromStream(AStream: TStream; APicture: TPicture; out AFormatName: string): Boolean;
var
  Ext: string;
  Offset: Integer;
  SubStream: TMemoryStream;
  Jpg: TJPEGImage;
  Png: TPortableNetworkGraphic;
  Bmp: TBitmap;
  Gif: TGIFImage;
  Ico: TIcon;
begin
  Result := False;
  AFormatName := '';
  if not Assigned(AStream) or (AStream.Size = 0) or not Assigned(APicture) then Exit;

  Ext := DetectImageExtension(AStream, Offset);
  AFormatName := UpperCase(Ext);

  SubStream := TMemoryStream.Create;
  try
    AStream.Position := Offset;
    SubStream.CopyFrom(AStream, AStream.Size - Offset);
    SubStream.Position := 0;

    if Ext = 'jpg' then
    begin
      Jpg := TJPEGImage.Create;
      try
        Jpg.LoadFromStream(SubStream);
        APicture.Assign(Jpg);
        Result := (APicture.Graphic <> nil) and not APicture.Graphic.Empty;
      except
        Result := False;
      end;
      Jpg.Free;
    end
    else if Ext = 'png' then
    begin
      Png := TPortableNetworkGraphic.Create;
      try
        Png.LoadFromStream(SubStream);
        APicture.Assign(Png);
        Result := (APicture.Graphic <> nil) and not APicture.Graphic.Empty;
      except
        Result := False;
      end;
      Png.Free;
    end
    else if Ext = 'bmp' then
    begin
      Bmp := TBitmap.Create;
      try
        Bmp.LoadFromStream(SubStream);
        APicture.Assign(Bmp);
        Result := (APicture.Graphic <> nil) and not APicture.Graphic.Empty;
      except
        Result := False;
      end;
      Bmp.Free;
    end
    else if Ext = 'gif' then
    begin
      Gif := TGIFImage.Create;
      try
        Gif.LoadFromStream(SubStream);
        APicture.Assign(Gif);
        Result := (APicture.Graphic <> nil) and not APicture.Graphic.Empty;
      except
        Result := False;
      end;
      Gif.Free;
    end
    else if Ext = 'ico' then
    begin
      Ico := TIcon.Create;
      try
        Ico.LoadFromStream(SubStream);
        APicture.Assign(Ico);
        Result := (APicture.Graphic <> nil) and not APicture.Graphic.Empty;
      except
        Result := False;
      end;
      Ico.Free;
    end;

    // Fallback Generic Decoder
    if not Result then
    begin
      try
        SubStream.Position := 0;
        APicture.LoadFromStream(SubStream);
        Result := (APicture.Graphic <> nil) and not APicture.Graphic.Empty;
        if Result and (AFormatName = '') then
          AFormatName := 'IMAGE';
      except
        Result := False;
      end;
    end;
  finally
    SubStream.Free;
  end;
end;

function TFormRecordView.GenerateHexDump(AStream: TStream; AMaxBytes: Integer): string;
var
  Buffer: array[0..15] of Byte;
  ReadCount, TotalRead, I: Integer;
  HexPart, AsciiPart, LineStr: string;
  SB: TStringList;
begin
  SB := TStringList.Create;
  try
    AStream.Position := 0;
    TotalRead := 0;

    while (AStream.Position < AStream.Size) and (TotalRead < AMaxBytes) do
    begin
      ReadCount := AStream.Read(Buffer, SizeOf(Buffer));
      if ReadCount <= 0 then Break;

      HexPart := '';
      AsciiPart := '';

      for I := 0 to ReadCount - 1 do
      begin
        HexPart := HexPart + IntToHex(Buffer[I], 2) + ' ';
        if Buffer[I] in [32..126] then
          AsciiPart := AsciiPart + Chr(Buffer[I])
        else
          AsciiPart := AsciiPart + '.';
      end;

      while Length(HexPart) < 48 do
        HexPart := HexPart + ' ';

      LineStr := Format('%s  |%s|', [HexPart, AsciiPart]);
      SB.Add(LineStr);
      Inc(TotalRead, ReadCount);
    end;

    if AStream.Size > AMaxBytes then
      SB.Add(Format('... (dan %d bytes berikutnya)', [AStream.Size - AMaxBytes]));

    Result := SB.Text;
  finally
    SB.Free;
  end;
end;

procedure TFormRecordView.EnsureEditOrInsertState;
begin
  if not Assigned(FDataSet) or not FDataSet.Active then Exit;

  if FDataSet.IsEmpty or (FDataSet.RecordCount = 0) then
    FDataSet.Append
  else if not (FDataSet.State in [dsEdit, dsInsert]) then
    FDataSet.Edit;

  FIsModified := True;
end;

procedure TFormRecordView.UpdateNavigationUI;
var
  TotalRec: Integer;
  CurRec: Integer;
begin
  if Assigned(FDataSet) and FDataSet.Active then
  begin
    TotalRec := FDataSet.RecordCount;
    CurRec := FDataSet.RecNo;

    btnFirst.Enabled := (CurRec > 1);
    btnPrior.Enabled := (CurRec > 1);
    btnNext.Enabled := (CurRec < TotalRec) and (CurRec > 0);
    btnLast.Enabled := (CurRec < TotalRec) and (CurRec > 0);

    if TotalRec = 0 then
    begin
      if FDataSet.State = dsInsert then
        lblRecInfo.Caption := 'Menambah Baris Baru'
      else
        lblRecInfo.Caption := '0 dari 0 (Tabel Kosong)';
    end
    else
      lblRecInfo.Caption := Format('Baris %d dari %d', [CurRec, TotalRec]);

    btnAddRecord.Enabled := not (FDataSet.State in [dsEdit, dsInsert]);
    btnDeleteRecord.Enabled := (TotalRec > 0) and not (FDataSet.State in [dsEdit, dsInsert]);
    btnPost.Enabled := FIsModified or (FDataSet.State in [dsEdit, dsInsert]);
    btnCancelEdit.Enabled := btnPost.Enabled;
  end
  else
  begin
    btnFirst.Enabled := False;
    btnPrior.Enabled := False;
    btnNext.Enabled := False;
    btnLast.Enabled := False;
    btnAddRecord.Enabled := False;
    btnDeleteRecord.Enabled := False;
    lblRecInfo.Caption := 'Tidak ada dataset';
    btnPost.Enabled := False;
    btnCancelEdit.Enabled := False;
  end;
end;

procedure TFormRecordView.RefreshRecordData;
var
  I, RowIdx: Integer;
  Fld: TField;
  ValStr: string;
begin
  if not Assigned(FDataSet) or not FDataSet.Active or (FDataSet.FieldCount = 0) then
  begin
    gridFields.RowCount := 1;
    synValue.Clear;
    imgPreview.Picture.Clear;
    lblActiveFieldName.Caption := 'Field: -';
    lblFieldSize.Caption := 'Ukuran: 0 B';
    UpdateNavigationUI;
    Exit;
  end;

  gridFields.RowCount := FDataSet.FieldCount + 1;

  for I := 0 to FDataSet.FieldCount - 1 do
  begin
    RowIdx := I + 1;
    Fld := FDataSet.Fields[I];

    gridFields.Cells[0, RowIdx] := Fld.FieldName;
    gridFields.Cells[1, RowIdx] := FieldTypeNames[Fld.DataType];

    if FDataSet.IsEmpty and not (FDataSet.State in [dsEdit, dsInsert]) then
    begin
      gridFields.Cells[2, RowIdx] := 'YA';
      gridFields.Cells[3, RowIdx] := '<KOSONG>';
    end
    else if Fld.IsNull then
    begin
      gridFields.Cells[2, RowIdx] := 'YA';
      gridFields.Cells[3, RowIdx] := '<NULL>';
    end
    else
    begin
      gridFields.Cells[2, RowIdx] := 'TIDAK';

      if (Fld is TBlobField) and (Fld.DataType in [ftBlob, ftGraphic, ftTypedBinary, ftOraBlob]) then
        gridFields.Cells[3, RowIdx] := Format('[BLOB: %d Bytes]', [TBlobField(Fld).BlobSize])
      else
      begin
        ValStr := Fld.AsString;
        ValStr := StringReplace(ValStr, #13#10, ' ', [rfReplaceAll]);
        ValStr := StringReplace(ValStr, #10, ' ', [rfReplaceAll]);
        gridFields.Cells[3, RowIdx] := ValStr;
      end;
    end;
  end;

  if FCurrentFieldIndex >= FDataSet.FieldCount then
    FCurrentFieldIndex := 0;

  gridFields.Row := FCurrentFieldIndex + 1;
  LoadFieldDetail(FCurrentFieldIndex);
  UpdateNavigationUI;
end;

procedure TFormRecordView.LoadFieldDetail(const AFieldIdx: Integer);
var
  Fld: TField;
  RawVal, FormatName: string;
  MemStream: TMemoryStream;
  IsImageLoaded: Boolean;
begin
  if not Assigned(FDataSet) or not FDataSet.Active or (AFieldIdx < 0) or (AFieldIdx >= FDataSet.FieldCount) then
  begin
    synValue.Clear;
    imgPreview.Picture.Clear;
    lblActiveFieldName.Caption := 'Field: -';
    lblFieldSize.Caption := 'Ukuran: 0 B';
    Exit;
  end;

  FCurrentFieldIndex := AFieldIdx;
  Fld := FDataSet.Fields[AFieldIdx];

  lblActiveFieldName.Caption := Format('Field: %s [%s]', [Fld.FieldName, FieldTypeNames[Fld.DataType]]);

  if IsBlobOrGraphicField(Fld) and (Fld.DataType in [ftBlob, ftGraphic, ftTypedBinary, ftOraBlob]) then
  begin
    btnLoadPicture.Visible := True;
    btnSavePicture.Visible := True;
    btnApplyFieldDetail.Visible := False;

    MemStream := TMemoryStream.Create;
    try
      if ExtractBlobToStream(Fld, MemStream) and (MemStream.Size > 0) then
      begin
        synValue.ReadOnly := True;
        synValue.Lines.Text := GenerateHexDump(MemStream);

        IsImageLoaded := TryLoadImageFromStream(MemStream, imgPreview.Picture, FormatName);

        if IsImageLoaded then
        begin
          lblFieldSize.Caption := Format('Format: %s | %dx%d px | %d KB', [
            FormatName,
            imgPreview.Picture.Width,
            imgPreview.Picture.Height,
            MemStream.Size div 1024
          ]);
        end
        else
        begin
          imgPreview.Picture.Clear;
          lblFieldSize.Caption := Format('Ukuran Biner: %d Bytes', [MemStream.Size]);
        end;
      end
      else
      begin
        synValue.ReadOnly := False;
        synValue.Lines.Text := '';
        imgPreview.Picture.Clear;
        lblFieldSize.Caption := 'Ukuran: NULL';
      end;
    finally
      MemStream.Free;
    end;
  end
  else
  begin
    btnLoadPicture.Visible := False;
    btnSavePicture.Visible := False;
    btnApplyFieldDetail.Visible := True;
    imgPreview.Picture.Clear;

    synValue.ReadOnly := False;
    if Fld.IsNull or (FDataSet.IsEmpty and not (FDataSet.State in [dsEdit, dsInsert])) then
    begin
      synValue.Lines.Text := '';
      lblFieldSize.Caption := 'Nilai: NULL';
    end
    else
    begin
      RawVal := Fld.AsString;
      synValue.Lines.Text := RawVal;
      lblFieldSize.Caption := Format('Panjang: %d Karakter', [Length(RawVal)]);
    end;
  end;
end;

procedure TFormRecordView.btnLoadPictureClick(Sender: TObject);
var
  Fld: TField;
  BlobStream: TStream;
  FileStream: TFileStream;
begin
  if not Assigned(FDataSet) or not FDataSet.Active or (FCurrentFieldIndex < 0) or (FCurrentFieldIndex >= FDataSet.FieldCount) then Exit;

  Fld := FDataSet.Fields[FCurrentFieldIndex];
  if not IsBlobOrGraphicField(Fld) then
  begin
    MessageDlg('Peringatan', 'Field ini bukan bertipe BLOB/Binary.', mtWarning, [mbOK], 0);
    Exit;
  end;

  openPicDialog.Title := 'Pilih Berkas Gambar untuk Dimuat';
  openPicDialog.Filter := 'Berkas Gambar (*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.ico)|*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.ico|Semua Berkas (*.*)|*.*';

  if openPicDialog.Execute then
  begin
    try
      EnsureEditOrInsertState;

      // Muat berkas biner murni secara presisi
      if Fld is TBlobField then
        TBlobField(Fld).LoadFromFile(openPicDialog.FileName)
      else
      begin
        BlobStream := FDataSet.CreateBlobStream(Fld, bmWrite);
        try
          FileStream := TFileStream.Create(openPicDialog.FileName, fmOpenRead or fmShareDenyNone);
          try
            BlobStream.CopyFrom(FileStream, FileStream.Size);
          finally
            FileStream.Free;
          end;
        finally
          BlobStream.Free;
        end;
      end;

      FIsModified := True;
      gridFields.Cells[2, FCurrentFieldIndex + 1] := 'TIDAK';

      LoadFieldDetail(FCurrentFieldIndex);
      UpdateNavigationUI;
      MessageDlg('Sukses', 'Gambar berhasil dimuat ke buffer. Klik "💾 Simpan" untuk menerapkan.', mtInformation, [mbOK], 0);
    except
      on E: Exception do
        MessageDlg('Kesalahan', 'Gagal memuat berkas gambar: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TFormRecordView.btnSavePictureClick(Sender: TObject);
var
  Fld: TField;
  MemStream: TMemoryStream;
  ImgExt: string;
  Offset: Integer;
begin
  if not Assigned(FDataSet) or not FDataSet.Active or (FCurrentFieldIndex < 0) or (FCurrentFieldIndex >= FDataSet.FieldCount) then Exit;

  Fld := FDataSet.Fields[FCurrentFieldIndex];
  if not IsBlobOrGraphicField(Fld) or Fld.IsNull then
  begin
    MessageDlg('Informasi', 'Field BLOB ini kosong atau bernilai NULL.', mtInformation, [mbOK], 0);
    Exit;
  end;

  MemStream := TMemoryStream.Create;
  try
    if ExtractBlobToStream(Fld, MemStream) and (MemStream.Size > 0) then
    begin
      ImgExt := DetectImageExtension(MemStream, Offset);
      if ImgExt = '' then ImgExt := 'bin';

      savePicDialog.Title := 'Simpan Gambar ke Berkas';
      savePicDialog.DefaultExt := '.' + ImgExt;
      savePicDialog.Filter := 'Format Terdeteksi (*.' + ImgExt + ')|*.' + ImgExt + '|Semua Berkas (*.*)|*.*';
      savePicDialog.FileName := Format('%s_%s.%s', [Fld.FieldName, FormatDateTime('yyyymmdd_hhnnss', Now), ImgExt]);

      if savePicDialog.Execute then
      begin
        MemStream.Position := Offset;
        MemStream.SaveToFile(savePicDialog.FileName);
        MessageDlg('Sukses', 'Gambar berhasil disimpan ke ' + savePicDialog.FileName, mtInformation, [mbOK], 0);
      end;
    end;
  finally
    MemStream.Free;
  end;
end;

procedure TFormRecordView.ApplyCurrentDetailValue;
var
  Fld: TField;
  NewVal: string;
begin
  if not Assigned(FDataSet) or not FDataSet.Active or (FCurrentFieldIndex < 0) or (FCurrentFieldIndex >= FDataSet.FieldCount) then Exit;

  Fld := FDataSet.Fields[FCurrentFieldIndex];
  if IsBlobOrGraphicField(Fld) then Exit; // Tolak menimpa BLOB dari teks

  NewVal := synValue.Lines.Text;

  try
    EnsureEditOrInsertState;
    Fld.AsString := NewVal;

    gridFields.Cells[2, FCurrentFieldIndex + 1] := 'TIDAK';
    gridFields.Cells[3, FCurrentFieldIndex + 1] := StringReplace(NewVal, LineEnding, ' ', [rfReplaceAll]);
    lblFieldSize.Caption := Format('Panjang: %d Karakter', [Length(NewVal)]);
    UpdateNavigationUI;
  except
    on E: Exception do
      MessageDlg('Peringatan Nilai', 'Gagal menetapkan nilai pada field: ' + E.Message, mtWarning, [mbOK], 0);
  end;
end;

procedure TFormRecordView.gridFieldsSelectCell(Sender: TObject; aCol, aRow: Integer; var CanSelect: Boolean);
begin
  if (aRow >= 1) and (aRow <= FDataSet.FieldCount) then
    LoadFieldDetail(aRow - 1);
end;

procedure TFormRecordView.gridFieldsEditingDone(Sender: TObject);
var
  RowIdx, FieldIdx: Integer;
  Fld: TField;
  ValStr: string;
begin
  RowIdx := gridFields.Row;
  if RowIdx < 1 then Exit;
  FieldIdx := RowIdx - 1;

  if Assigned(FDataSet) and (FieldIdx >= 0) and (FieldIdx < FDataSet.FieldCount) then
  begin
    Fld := FDataSet.Fields[FieldIdx];

    // Proteksi: Jangan biarkan edit in-place pada grid merusak field BLOB
    if IsBlobOrGraphicField(Fld) then Exit;

    ValStr := gridFields.Cells[3, RowIdx];

    try
      EnsureEditOrInsertState;

      if UpperCase(Trim(ValStr)) = '<NULL>' then
      begin
        Fld.Clear;
        gridFields.Cells[2, RowIdx] := 'YA';
      end
      else
      begin
        Fld.AsString := ValStr;
        gridFields.Cells[2, RowIdx] := 'TIDAK';
      end;

      LoadFieldDetail(FieldIdx);
      UpdateNavigationUI;
    except
      on E: Exception do
        MessageDlg('Kesalahan Input', E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TFormRecordView.btnApplyFieldDetailClick(Sender: TObject);
begin
  ApplyCurrentDetailValue;
end;

procedure TFormRecordView.btnSetNullClick(Sender: TObject);
var
  Fld: TField;
begin
  if not Assigned(FDataSet) or not FDataSet.Active or (FCurrentFieldIndex < 0) or (FCurrentFieldIndex >= FDataSet.FieldCount) then Exit;

  Fld := FDataSet.Fields[FCurrentFieldIndex];
  try
    EnsureEditOrInsertState;

    Fld.Clear;

    gridFields.Cells[2, FCurrentFieldIndex + 1] := 'YA';
    gridFields.Cells[3, FCurrentFieldIndex + 1] := '<NULL>';
    synValue.Clear;
    imgPreview.Picture.Clear;
    lblFieldSize.Caption := 'Nilai: NULL';
    UpdateNavigationUI;
  except
    on E: Exception do
      MessageDlg('Peringatan', 'Field tidak dapat diset NULL: ' + E.Message, mtWarning, [mbOK], 0);
  end;
end;

procedure TFormRecordView.btnAddRecordClick(Sender: TObject);
begin
  if not Assigned(FDataSet) or not FDataSet.Active then Exit;

  try
    FDataSet.Append;
    FIsModified := True;
    RefreshRecordData;
  except
    on E: Exception do
      MessageDlg('Gagal Menambah Baris', E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TFormRecordView.btnDeleteRecordClick(Sender: TObject);
begin
  if not Assigned(FDataSet) or not FDataSet.Active or FDataSet.IsEmpty then Exit;

  if MessageDlg('Konfirmasi', 'Hapus baris data aktif saat ini?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    try
      FDataSet.Delete;
      FIsModified := False;
      RefreshRecordData;
    except
      on E: Exception do
        MessageDlg('Gagal Menghapus Baris', E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TFormRecordView.btnFirstClick(Sender: TObject);
begin
  if FIsModified then btnPostClick(Sender);
  FDataSet.First;
  RefreshRecordData;
end;

procedure TFormRecordView.btnPriorClick(Sender: TObject);
begin
  if FIsModified then btnPostClick(Sender);
  FDataSet.Prior;
  RefreshRecordData;
end;

procedure TFormRecordView.btnNextClick(Sender: TObject);
begin
  if FIsModified then btnPostClick(Sender);
  FDataSet.Next;
  RefreshRecordData;
end;

procedure TFormRecordView.btnLastClick(Sender: TObject);
begin
  if FIsModified then btnPostClick(Sender);
  FDataSet.Last;
  RefreshRecordData;
end;

procedure TFormRecordView.btnRefreshClick(Sender: TObject);
begin
  if FIsModified and (MessageDlg('Konfirmasi', 'Terdapat perubahan yang belum disimpan. Batalkan dan muat ulang?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then
    Exit;

  if FDataSet.State in [dsEdit, dsInsert] then
    FDataSet.Cancel;

  FIsModified := False;
  RefreshRecordData;
end;

procedure TFormRecordView.btnPostClick(Sender: TObject);
begin
  try
    if FDataSet.State in [dsEdit, dsInsert] then
      FDataSet.Post;
    FIsModified := False;
    RefreshRecordData;
    MessageDlg('Sukses', 'Data berhasil disimpan.', mtInformation, [mbOK], 0);
  except
    on E: Exception do
      MessageDlg('Gagal Menyimpan Rekord', E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TFormRecordView.btnCancelEditClick(Sender: TObject);
begin
  if FDataSet.State in [dsEdit, dsInsert] then
    FDataSet.Cancel;
  FIsModified := False;
  RefreshRecordData;
end;

procedure TFormRecordView.btnCopyRecordClick(Sender: TObject);
var
  I: Integer;
  SL: TStringList;
begin
  if not Assigned(FDataSet) or not FDataSet.Active or FDataSet.IsEmpty then Exit;

  SL := TStringList.Create;
  try
    for I := 0 to FDataSet.FieldCount - 1 do
    begin
      if FDataSet.Fields[I].IsNull then
        SL.Add(Format('%s: <NULL>', [FDataSet.Fields[I].FieldName]))
      else if FDataSet.Fields[I] is TBlobField then
        SL.Add(Format('%s: [BLOB %d Bytes]', [FDataSet.Fields[I].FieldName, TBlobField(FDataSet.Fields[I]).BlobSize]))
      else
        SL.Add(Format('%s: %s', [FDataSet.Fields[I].FieldName, FDataSet.Fields[I].AsString]));
    end;
    Clipboard.AsText := SL.Text;
    MessageDlg('Form View', 'Data baris berhasil disalin ke Clipboard.', mtInformation, [mbOK], 0);
  finally
    SL.Free;
  end;
end;

end.
