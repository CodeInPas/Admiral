unit uFrameValueInspector;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  ComCtrls, StdCtrls, Buttons, Clipbrd, DB, SynEdit, SynHighlighterXML,
  fpjson, jsonparser,
  uAppConst, uAppTypes, uDBTypes;

type
  { TFrameValueInspector }
  TFrameValueInspector = class(TFrame)
    btnWrap: TSpeedButton;
    synText: TMemo;
    pnlHeader: TPanel;
    lblTitle: TLabel;
    lblSize: TLabel;
    btnCopy: TSpeedButton;
    btnSaveFile: TSpeedButton;
    btnClose: TSpeedButton;

    pgcInspector: TPageControl;
    tabText: TTabSheet;
    tabJSON: TTabSheet;
    tabXML: TTabSheet;
    tabHex: TTabSheet;
    tabImage: TTabSheet;

    synJSON: TSynEdit;
    synXML: TSynEdit;
    synHex: TSynEdit;
    synXMLSyn: TSynXMLSyn;

    sbImage: TScrollBox;
    imgPreview: TImage;
    pnlImageControls: TPanel;
    lblImageInfo: TLabel;
    btnImageFit: TSpeedButton;
    btnImageOriginal: TSpeedButton;

    saveDialog: TSaveDialog;

    procedure btnCloseClick(Sender: TObject);
    procedure btnCopyClick(Sender: TObject);
    procedure btnSaveFileClick(Sender: TObject);
    procedure btnImageFitClick(Sender: TObject);
    procedure btnImageOriginalClick(Sender: TObject);
  private
    FCurrentField: TField;
    FRawData: string;
    FOnCloseRequest: TNotifyEvent;

    procedure RenderAsText(const AStr: string);
    procedure RenderAsJSON(const AStr: string; out ASuccess: Boolean);
    procedure RenderAsXML(const AStr: string; out ASuccess: Boolean);
    procedure RenderAsHex(const ABytes: TBytes);
    procedure RenderAsImage(const AStream: TStream; out ASuccess: Boolean);
    function GenerateHexDump(const AData: PByte; const ALength: Integer): string;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure InspectField(AField: TField);
    procedure Clear;

    property OnCloseRequest: TNotifyEvent read FOnCloseRequest write FOnCloseRequest;
  end;

implementation

{$R *.lfm}

{ TFrameValueInspector }

constructor TFrameValueInspector.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCurrentField := nil;
  FRawData := '';

  synXML.Highlighter := synXMLSyn;
  Clear;
end;

destructor TFrameValueInspector.Destroy;
begin
  inherited Destroy;
end;

procedure TFrameValueInspector.Clear;
begin
  FCurrentField := nil;
  FRawData := '';
  lblTitle.Caption := 'No cells selected.';
  lblSize.Caption := 'Size: 0 B';
  lblImageInfo.Caption := '-';

  synText.Clear;
  synJSON.Clear;
  synXML.Clear;
  synHex.Clear;
  imgPreview.Picture.Clear;

  tabJSON.TabVisible := True;
  tabXML.TabVisible := True;
  tabImage.TabVisible := True;
  pgcInspector.ActivePage := tabText;
end;

function TFrameValueInspector.GenerateHexDump(const AData: PByte; const ALength: Integer): string;
var
  I, J, LineLen: Integer;
  HexPart, AsciiPart, Line: string;
  B: Byte;
  SL: TStringList;
begin
  if (AData = nil) or (ALength <= 0) then Exit('');

  SL := TStringList.Create;
  try
    I := 0;
    while I < ALength do
    begin
      LineLen := ALength - I;
      if LineLen > 16 then LineLen := 16;

      HexPart := '';
      AsciiPart := '';

      for J := 0 to 15 do
      begin
        if J < LineLen then
        begin
          B := (AData + I + J)^;
          HexPart := HexPart + IntToHex(B, 2) + ' ';
          if (B >= 32) and (B <= 126) then
            AsciiPart := AsciiPart + Chr(B)
          else
            AsciiPart := AsciiPart + '.';
        end
        else
        begin
          HexPart := HexPart + '   ';
        end;

        if J = 7 then HexPart := HexPart + ' ';
      end;

      Line := Format('%.8X  %s |%s|', [I, HexPart, AsciiPart]);
      SL.Add(Line);
      Inc(I, 16);
    end;
    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

procedure TFrameValueInspector.RenderAsText(const AStr: string);
begin
  synText.Lines.Text := AStr;
end;

procedure TFrameValueInspector.RenderAsJSON(const AStr: string; out ASuccess: Boolean);
var
  Parser: TJSONParser;
  JSONData: TJSONData;
begin
  ASuccess := False;
  if (Trim(AStr) = '') or not (Trim(AStr)[1] in ['{', '[']) then
  begin
    synJSON.Lines.Text := '-- Value is not a valid JSON format.';
    Exit;
  end;

  try
    Parser := TJSONParser.Create(AStr);
    try
      JSONData := Parser.Parse;
      try
        if Assigned(JSONData) then
        begin
          synJSON.Lines.Text := JSONData.FormatJSON([foSingleLineArray, foDoNotQuoteMembers], 2);
          ASuccess := True;
        end;
      finally
        if Assigned(JSONData) then
          JSONData.Free;
      end;
    finally
      Parser.Free;
    end;
  except
    synJSON.Lines.Text := AStr;
    ASuccess := False;
  end;
end;

procedure TFrameValueInspector.RenderAsXML(const AStr: string; out ASuccess: Boolean);
var
  CleanText: string;
begin
  ASuccess := False;
  CleanText := Trim(AStr);
  if (CleanText = '') or not CleanText.StartsWith('<') then
  begin
    synXML.Lines.Text := '<!-- Value is not a valid XML format. -->';
    Exit;
  end;

  synXML.Lines.Text := CleanText;
  ASuccess := True;
end;

procedure TFrameValueInspector.RenderAsHex(const ABytes: TBytes);
begin
  if Length(ABytes) > 0 then
    synHex.Lines.Text := GenerateHexDump(@ABytes[0], Length(ABytes))
  else
    synHex.Clear;
end;

procedure TFrameValueInspector.RenderAsImage(const AStream: TStream; out ASuccess: Boolean);
var
  Header: array[0..7] of Byte;
  ReadBytes: Integer;
  IsGraphic: Boolean;
begin
  ASuccess := False;
  imgPreview.Picture.Clear;
  if (AStream = nil) or (AStream.Size < 4) then Exit;

  AStream.Position := 0;
  ReadBytes := AStream.Read(Header, SizeOf(Header));
  AStream.Position := 0;

  IsGraphic := False;
  if (ReadBytes >= 3) and (Header[0] = $FF) and (Header[1] = $D8) and (Header[2] = $FF) then
  begin
    lblImageInfo.Caption := 'Tipe: JPEG Image';
    IsGraphic := True;
  end
  else if (ReadBytes >= 4) and (Header[0] = $89) and (Header[1] = $50) and (Header[2] = $4E) and (Header[3] = $47) then
  begin
    lblImageInfo.Caption := 'Type: PNG Image';
    IsGraphic := True;
  end
  else if (ReadBytes >= 2) and (Header[0] = $42) and (Header[1] = $4D) then
  begin
    lblImageInfo.Caption := 'Type: Windows BMP';
    IsGraphic := True;
  end
  else if (ReadBytes >= 3) and (Header[0] = $47) and (Header[1] = $49) and (Header[2] = $46) then
  begin
    lblImageInfo.Caption := 'Type: GIF Image';
    IsGraphic := True;
  end;

  if IsGraphic then
  begin
    try
      imgPreview.Picture.LoadFromStream(AStream);
      lblImageInfo.Caption := Format('%s (%d x %d px)', [
        lblImageInfo.Caption,
        imgPreview.Picture.Width,
        imgPreview.Picture.Height
      ]);
      ASuccess := True;
    except
      ASuccess := False;
    end;
  end;
end;

procedure TFrameValueInspector.InspectField(AField: TField);
var
  Stream: TMemoryStream;
  Bytes: TBytes;
  ByteLen: Integer;
  IsJSON, IsXML, IsImg: Boolean;
begin
  Clear;
  FCurrentField := AField;
  if not Assigned(FCurrentField) then Exit;

  lblTitle.Caption := Format('Column: %s [%s]', [
    FCurrentField.FieldName,
    FieldTypeNames[FCurrentField.DataType]
  ]);

  if FCurrentField.IsNull then
  begin
    lblSize.Caption := 'Nilai: NULL';
    RenderAsText('<NULL>');
    Exit;
  end;

  FRawData := FCurrentField.AsString;
  ByteLen := Length(FRawData);

  if ByteLen < 1024 then
    lblSize.Caption := Format('Size: %d B', [ByteLen])
  else if ByteLen < 1024 * 1024 then
    lblSize.Caption := Format('Size: %.2f KB', [ByteLen / 1024])
  else
    lblSize.Caption := Format('Size: %.2f MB', [ByteLen / (1024 * 1024)]);

  // Render format teks
  RenderAsText(FRawData);

  // Render Hex
  SetLength(Bytes, ByteLen);
  if ByteLen > 0 then
  begin
    Move(FRawData[1], Bytes[0], ByteLen);
    RenderAsHex(Bytes);
  end;

  // Deteksi & Render JSON
  RenderAsJSON(FRawData, IsJSON);
  tabJSON.TabVisible := IsJSON;

  // Deteksi & Render XML
  RenderAsXML(FRawData, IsXML);
  tabXML.TabVisible := IsXML;

  // Deteksi & Render Image
  Stream := TMemoryStream.Create;
  try
    if FCurrentField.IsBlob then
      TBlobField(FCurrentField).SaveToStream(Stream)
    else if ByteLen > 0 then
      Stream.WriteBuffer(Bytes[0], ByteLen);

    Stream.Position := 0;
    RenderAsImage(Stream, IsImg);
    tabImage.TabVisible := IsImg;
  finally
    Stream.Free;
  end;

  // Navigasi tab otomatis berdasarkan konten yang terdeteksi
  if IsImg then pgcInspector.ActivePage := tabImage
  else if IsJSON then pgcInspector.ActivePage := tabJSON
  else if IsXML then pgcInspector.ActivePage := tabXML
  else pgcInspector.ActivePage := tabText;
end;

procedure TFrameValueInspector.btnCloseClick(Sender: TObject);
begin
  if Assigned(FOnCloseRequest) then
    FOnCloseRequest(Self);
end;

procedure TFrameValueInspector.btnCopyClick(Sender: TObject);
begin
  if pgcInspector.ActivePage = tabJSON then Clipboard.AsText := synJSON.Lines.Text
  else if pgcInspector.ActivePage = tabXML then Clipboard.AsText := synXML.Lines.Text
  else if pgcInspector.ActivePage = tabHex then Clipboard.AsText := synHex.Lines.Text
  else Clipboard.AsText := synText.Lines.Text;
end;

procedure TFrameValueInspector.btnSaveFileClick(Sender: TObject);
var
  Ext: string;
begin
  if FRawData = '' then Exit;

  if pgcInspector.ActivePage = tabJSON then Ext := '.json'
  else if pgcInspector.ActivePage = tabXML then Ext := '.xml'
  else if pgcInspector.ActivePage = tabImage then Ext := '.png'
  else if pgcInspector.ActivePage = tabHex then Ext := '.hex.txt'
  else Ext := '.txt';

  saveDialog.DefaultExt := Ext;
  saveDialog.Filter := 'All Files (*.*)|*.*';
  saveDialog.FileName := Format('blob_export_%s%s', [FormatDateTime('yyyymmdd_hhnnss', Now), Ext]);

  if saveDialog.Execute then
  begin
    if (pgcInspector.ActivePage = tabImage) and Assigned(imgPreview.Picture.Graphic) then
      imgPreview.Picture.SaveToFile(saveDialog.FileName)
    else if pgcInspector.ActivePage = tabJSON then
      synJSON.Lines.SaveToFile(saveDialog.FileName)
    else if pgcInspector.ActivePage = tabXML then
      synXML.Lines.SaveToFile(saveDialog.FileName)
    else if pgcInspector.ActivePage = tabHex then
      synHex.Lines.SaveToFile(saveDialog.FileName)
    else
      synText.Lines.SaveToFile(saveDialog.FileName);
  end;
end;

procedure TFrameValueInspector.btnImageFitClick(Sender: TObject);
begin
  imgPreview.Stretch := True;
  imgPreview.Proportional := True;
  imgPreview.Align := alClient;
end;

procedure TFrameValueInspector.btnImageOriginalClick(Sender: TObject);
begin
  imgPreview.Stretch := False;
  imgPreview.Proportional := False;
  imgPreview.Align := alNone;
  imgPreview.AutoSize := True;
end;

end.
