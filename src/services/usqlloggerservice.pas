unit uSQLLoggerService;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils, SyncObjs;

type
  TOnSQLLogEvent = procedure(const ALogLine: string) of object;

  { TSQLLoggerService }
  TSQLLoggerService = class
  private
    FLock: TCriticalSection;
    FMasterLog: TStringList;
    FOnLog: TOnSQLLogEvent;
    FCurLogMsg: string;

    procedure DoSyncLog;
    procedure InternalLog(const ALine: string);
  public
    constructor Create;
    destructor Destroy; override;

    procedure LogSQL(const ASQL: string; const AElapsedMS: Int64 = -1; const ARowsAffected: Int64 = -1);
    procedure LogComment(const AComment: string);
    procedure LogError(const AErrorMsg: string; const AFailedSQL: string = '');
    procedure Clear;

    property MasterLog: TStringList read FMasterLog;
    property OnLog: TOnSQLLogEvent read FOnLog write FOnLog;
  end;

function SQLLogger: TSQLLoggerService;

implementation

var
  GSQLLogger: TSQLLoggerService = nil;

function SQLLogger: TSQLLoggerService;
begin
  if not Assigned(GSQLLogger) then
    GSQLLogger := TSQLLoggerService.Create;
  Result := GSQLLogger;
end;

{ TSQLLoggerService }

constructor TSQLLoggerService.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FMasterLog := TStringList.Create;
  FCurLogMsg := '';
end;

destructor TSQLLoggerService.Destroy;
begin
  FMasterLog.Free;
  FLock.Free;
  inherited Destroy;
end;

procedure TSQLLoggerService.Clear;
begin
  FLock.Enter;
  try
    FMasterLog.Clear;
  finally
    FLock.Leave;
  end;
end;

procedure TSQLLoggerService.DoSyncLog;
begin
  if Assigned(FOnLog) then
    FOnLog(FCurLogMsg);
end;

procedure TSQLLoggerService.InternalLog(const ALine: string);
begin
  FLock.Enter;
  try
    FMasterLog.Add(ALine);
    FCurLogMsg := ALine;
    if Assigned(FOnLog) then
    begin
      if GetCurrentThreadId = MainThreadID then
        FOnLog(ALine)
      else
        TThread.Synchronize(nil, @DoSyncLog);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TSQLLoggerService.LogSQL(const ASQL: string; const AElapsedMS: Int64; const ARowsAffected: Int64);
var
  FullEntry, TrimmedSQL: string;
begin
  TrimmedSQL := Trim(ASQL);
  if TrimmedSQL = '' then Exit;

  if not EndsStr(';', TrimmedSQL) then
    TrimmedSQL := TrimmedSQL + ';';

  FullEntry := TrimmedSQL;
  if (AElapsedMS >= 0) or (ARowsAffected >= 0) then
  begin
    FullEntry := FullEntry + ' /* ';
    if ARowsAffected >= 0 then
      FullEntry := FullEntry + Format('%d baris terpengaruh, ', [ARowsAffected]);
    if AElapsedMS >= 0 then
      FullEntry := FullEntry + Format('waktu eksekusi: %d ms', [AElapsedMS]);
    FullEntry := FullEntry + ' */';
  end;

  InternalLog(FullEntry);
end;

procedure TSQLLoggerService.LogComment(const AComment: string);
begin
  InternalLog(Format('/* %s */', [Trim(AComment)]));
end;

procedure TSQLLoggerService.LogError(const AErrorMsg: string; const AFailedSQL: string);
var
  FullEntry: string;
begin
  if AFailedSQL <> '' then
    FullEntry := Format('/* ERROR: %s */%s-- Kueri gagal: %s', [AErrorMsg, LineEnding, AFailedSQL])
  else
    FullEntry := Format('/* ERROR: %s */', [AErrorMsg]);

  InternalLog(FullEntry);
end;

finalization
  if Assigned(GSQLLogger) then
    FreeAndNil(GSQLLogger);

end.
