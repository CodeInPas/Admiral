unit uExportService;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, SyncObjs, fgl,
  uAppTypes, uModelConnection, uExportWorkerThread;

type
  { Daftar Thread Ekspor Aktif }
  TExportWorkerList = specialize TFPGObjectList<TExportWorkerThread>;

  { TExportService }
  TExportService = class
  private
    FLock: TCriticalSection;
    FActiveWorkers: TExportWorkerList;
    procedure HandleWorkerTerminated(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;

    function StartExportAsync(
      AProfile: TConnectionProfile;
      const ASQL: string;
      const AOptions: TExportOptions;
      const ADatabaseTarget: string = '';
      AOnProgress: TExportProgressEvent = nil;
      AOnSuccess: TExportSuccessEvent = nil;
      AOnError: TExportErrorEvent = nil
    ): TExportWorkerThread;

    procedure CancelExport(AWorker: TExportWorkerThread);
    procedure CancelAllExports;

    function GetDialogFilterAllFormats: string;
    function GetFilterForFormat(const AFormat: TExportFormat): string;
    function GetDefaultExtension(const AFormat: TExportFormat): string;
    function GuessFormatFromFileName(const AFileName: string): TExportFormat;
    function BuildDefaultOptions(const AFileName: string; const AFormat: TExportFormat; const ATableName: string = ''): TExportOptions;

    property ActiveWorkers: TExportWorkerList read FActiveWorkers;
  end;

function ExportService: TExportService;

implementation

var
  GExportService: TExportService = nil;

function ExportService: TExportService;
begin
  if not Assigned(GExportService) then
    GExportService := TExportService.Create;
  Result := GExportService;
end;

{ TExportService }

constructor TExportService.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FActiveWorkers := TExportWorkerList.Create(False);
end;

destructor TExportService.Destroy;
begin
  CancelAllExports;
  FreeAndNil(FActiveWorkers);
  FreeAndNil(FLock);
  //inherited Destroy;
end;

procedure TExportService.HandleWorkerTerminated(Sender: TObject);
var
  Worker: TExportWorkerThread;
  Idx: Integer;
begin
  if not Assigned(FActiveWorkers) or not Assigned(FLock) then Exit;

  FLock.Enter;
  try
    if Sender is TExportWorkerThread then
    begin
      Worker := TExportWorkerThread(Sender);
      Idx := FActiveWorkers.IndexOf(Worker);
      if Idx >= 0 then
        FActiveWorkers.Delete(Idx);
    end;
  finally
    FLock.Leave;
  end;
end;

function TExportService.StartExportAsync(
  AProfile: TConnectionProfile;
  const ASQL: string;
  const AOptions: TExportOptions;
  const ADatabaseTarget: string;
  AOnProgress: TExportProgressEvent;
  AOnSuccess: TExportSuccessEvent;
  AOnError: TExportErrorEvent
): TExportWorkerThread;
var
  Worker: TExportWorkerThread;
begin
  Worker := TExportWorkerThread.Create(AProfile, ASQL, AOptions, ADatabaseTarget);
  Worker.OnProgress := AOnProgress;
  Worker.OnSuccess := AOnSuccess;
  Worker.OnError := AOnError;
  Worker.OnTerminate := @HandleWorkerTerminated;

  FLock.Enter;
  try
    FActiveWorkers.Add(Worker);
  finally
    FLock.Leave;
  end;

  Worker.Start;
  Result := Worker;
end;

procedure TExportService.CancelExport(AWorker: TExportWorkerThread);
var
  Idx: Integer;
begin
  if not Assigned(AWorker) then Exit;

  FLock.Enter;
  try
    Idx := FActiveWorkers.IndexOf(AWorker);
    if Idx >= 0 then
      FActiveWorkers.Delete(Idx);
  finally
    FLock.Leave;
  end;

  AWorker.OnTerminate := nil;
  AWorker.CancelExport;
  AWorker.WaitFor;
  AWorker.Free;
end;

procedure TExportService.CancelAllExports;
var
  I: Integer;
  Worker: TExportWorkerThread;
  TempList: TList;
begin
  if not Assigned(FActiveWorkers) then Exit;

  TempList := TList.Create;
  try
    FLock.Enter;
    try
      for I := 0 to FActiveWorkers.Count - 1 do
        TempList.Add(FActiveWorkers[I]);
      FActiveWorkers.Clear;
    finally
      FLock.Leave;
    end;

    for I := 0 to TempList.Count - 1 do
    begin
      Worker := TExportWorkerThread(TempList[I]);
      if Assigned(Worker) then
      begin
        Worker.OnTerminate := nil;
        Worker.CancelExport;
        Worker.WaitFor;
        Worker.Free;
      end;
    end;
  finally
    TempList.Free;
  end;
end;

function TExportService.GetDialogFilterAllFormats: string;
begin
  Result :=
    'Comma Separated Values (*.csv)|*.csv|' +
    'JSON Document (*.json)|*.json|' +
    'SQL Insert Dump (*.sql)|*.sql|' +
    'HTML Document (*.html;*.htm)|*.html;*.htm|' +
    'Markdown Table (*.md)|*.md|' +
    'XML Document (*.xml)|*.xml|' +
    'All Files (*.*)|*.*';
end;

function TExportService.GetFilterForFormat(const AFormat: TExportFormat): string;
begin
  case AFormat of
    efCSV:      Result := 'Comma Separated Values (*.csv)|*.csv';
    efJSON:     Result := 'JSON Document (*.json)|*.json';
    efSQL:      Result := 'SQL Insert Dump (*.sql)|*.sql';
    efHTML:     Result := 'HTML Document (*.html;*.htm)|*.html;*.htm';
    efMarkdown: Result := 'Markdown Table (*.md)|*.md';
    efXML:      Result := 'XML Document (*.xml)|*.xml';
    else        Result := 'All Files (*.*)|*.*';
  end;
end;

function TExportService.GetDefaultExtension(const AFormat: TExportFormat): string;
begin
  case AFormat of
    efCSV:      Result := '.csv';
    efJSON:     Result := '.json';
    efSQL:      Result := '.sql';
    efHTML:     Result := '.html';
    efMarkdown: Result := '.md';
    efXML:      Result := '.xml';
    else        Result := '.txt';
  end;
end;

function TExportService.GuessFormatFromFileName(const AFileName: string): TExportFormat;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  if (Ext = '.csv') or (Ext = '.tsv') then
    Result := efCSV
  else if Ext = '.json' then
    Result := efJSON
  else if Ext = '.sql' then
    Result := efSQL
  else if (Ext = '.html') or (Ext = '.htm') then
    Result := efHTML
  else if (Ext = '.md') or (Ext = '.markdown') then
    Result := efMarkdown
  else if Ext = '.xml' then
    Result := efXML
  else
    Result := efCSV;
end;

function TExportService.BuildDefaultOptions(const AFileName: string; const AFormat: TExportFormat; const ATableName: string): TExportOptions;
begin
  Result := DefaultExportOptions(AFileName, AFormat);
  if ATableName <> '' then
    Result.TableName := ATableName;
end;

finalization
  if Assigned(GExportService) then
    FreeAndNil(GExportService);

end.
