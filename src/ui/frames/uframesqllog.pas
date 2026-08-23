unit uFrameSQLLog;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Buttons, Clipbrd,
  SynEdit, SynHighlighterSQL,
  uSQLLoggerService;

type
  { TFrameSQLLog }
  TFrameSQLLog = class(TFrame)
    pnlToolbar: TPanel;
    lblFilter: TLabel;
    edtFilter: TEdit;
    btnClearFilter: TSpeedButton;
    btnClearLog: TSpeedButton;
    btnCopyAll: TSpeedButton;
    btnSaveLog: TSpeedButton;
    chkAutoScroll: TCheckBox;

    synLog: TSynEdit;
    synSQLSyn: TSynSQLSyn;
    saveDialog: TSaveDialog;

    procedure edtFilterChange(Sender: TObject);
    procedure btnClearFilterClick(Sender: TObject);
    procedure btnClearLogClick(Sender: TObject);
    procedure btnCopyAllClick(Sender: TObject);
    procedure btnSaveLogClick(Sender: TObject);
  private
    FMasterList: TStringList;
    procedure HandleNewLogEntry(const ALogLine: string);
    procedure ApplyFilter;
    procedure ScrollToBottom;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AppendLog(const ALine: string);
  end;

implementation

{$R *.lfm}

{ TFrameSQLLog }

constructor TFrameSQLLog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FMasterList := TStringList.Create;
  synLog.Highlighter := synSQLSyn;

  // Hubungkan dengan service logger global
  SQLLogger.OnLog := @HandleNewLogEntry;
end;

destructor TFrameSQLLog.Destroy;
begin
  if Assigned(SQLLogger) then
    SQLLogger.OnLog := nil;
  FMasterList.Free;
  inherited Destroy;
end;

procedure TFrameSQLLog.ScrollToBottom;
begin
  if chkAutoScroll.Checked and (synLog.Lines.Count > 0) then
  begin
    synLog.CaretY := synLog.Lines.Count;
    synLog.EnsureCursorPosVisible;
  end;
end;

procedure TFrameSQLLog.HandleNewLogEntry(const ALogLine: string);
begin
  AppendLog(ALogLine);
end;

procedure TFrameSQLLog.AppendLog(const ALine: string);
var
  FilterTxt: string;
begin
  FMasterList.Add(ALine);

  FilterTxt := Trim(edtFilter.Text);
  if (FilterTxt = '') or (Pos(LowerCase(FilterTxt), LowerCase(ALine)) > 0) then
  begin
    synLog.Lines.Add(ALine);
    ScrollToBottom;
  end;
end;

procedure TFrameSQLLog.ApplyFilter;
var
  FilterTxt: string;
  I: Integer;
begin
  FilterTxt := LowerCase(Trim(edtFilter.Text));
  synLog.Lines.BeginUpdate;
  try
    synLog.Clear;
    if FilterTxt = '' then
    begin
      synLog.Lines.Assign(FMasterList);
    end
    else
    begin
      for I := 0 to FMasterList.Count - 1 do
      begin
        if Pos(FilterTxt, LowerCase(FMasterList[I])) > 0 then
          synLog.Lines.Add(FMasterList[I]);
      end;
    end;
  finally
    synLog.Lines.EndUpdate;
    ScrollToBottom;
  end;
end;

procedure TFrameSQLLog.edtFilterChange(Sender: TObject);
begin
  ApplyFilter;
end;

procedure TFrameSQLLog.btnClearFilterClick(Sender: TObject);
begin
  edtFilter.Clear;
end;

procedure TFrameSQLLog.btnClearLogClick(Sender: TObject);
begin
  FMasterList.Clear;
  synLog.Clear;
  SQLLogger.Clear;
end;

procedure TFrameSQLLog.btnCopyAllClick(Sender: TObject);
begin
  if synLog.Lines.Count > 0 then
  begin
    Clipboard.AsText := synLog.Lines.Text;
    MessageDlg('Log Tersalin', 'Seluruh isi log SQL berhasil disalin ke Clipboard.', mtInformation, [mbOK], 0);
  end;
end;

procedure TFrameSQLLog.btnSaveLogClick(Sender: TObject);
begin
  saveDialog.DefaultExt := '.sql';
  saveDialog.Filter := 'SQL Log Files (*.sql;*.log)|*.sql;*.log|All Files (*.*)|*.*';
  saveDialog.FileName := Format('database_log_%s.sql', [FormatDateTime('YYYYMMDD_HHNNSS', Now)]);

  if saveDialog.Execute then
  begin
    FMasterList.SaveToFile(saveDialog.FileName);
    MessageDlg('Log Tersimpan', Format('Log aktivitas SQL berhasil diekspor ke:%s%s', [LineEnding, saveDialog.FileName]), mtInformation, [mbOK], 0);
  end;
end;

end.
