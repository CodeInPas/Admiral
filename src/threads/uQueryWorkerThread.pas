unit uQueryWorkerThread;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, DateUtils,
  ZConnection, ZDataset,
  uAppTypes, uDBTypes, uModelConnection, uDBDriverBase, uDBConnectionFactory;

type
  { Event Definitions }
  TQueryWorkerSuccessEvent = procedure(Sender: TObject; const AResult: TDBQueryResult; AQuery: TZQuery) of object;
  TQueryWorkerErrorEvent = procedure(Sender: TObject; const AResult: TDBQueryResult) of object;
  TQueryWorkerProgressEvent = procedure(Sender: TObject; const AMessage: string) of object;

  { TQueryWorkerThread }
  TQueryWorkerThread = class(TThread)
  private
    FProfile: TConnectionProfile;
    FSQL: string;
    FDatabaseTarget: string;
    FDriver: TDBDriverBase;
    FQuery: TZQuery;
    FResult: TDBQueryResult;
    FProgressMessage: string;

    FOnSuccess: TQueryWorkerSuccessEvent;
    FOnError: TQueryWorkerErrorEvent;
    FOnProgress: TQueryWorkerProgressEvent;

    procedure DoSyncSuccess;
    procedure DoSyncError;
    procedure DoSyncProgress;
    procedure ReportProgress(const AMessage: string);
  protected
    procedure Execute; override;
  public
    constructor Create(AProfile: TConnectionProfile; const ASQL: string; const ADatabaseTarget: string = '');
    destructor Destroy; override;

    procedure CancelExecution;

    property Profile: TConnectionProfile read FProfile;
    property SQL: string read FSQL;
    property DatabaseTarget: string read FDatabaseTarget write FDatabaseTarget;
    property QueryResult: TDBQueryResult read FResult;
    property QueryComponent: TZQuery read FQuery;

    property OnSuccess: TQueryWorkerSuccessEvent read FOnSuccess write FOnSuccess;
    property OnError: TQueryWorkerErrorEvent read FOnError write FOnError;
    property OnProgress: TQueryWorkerProgressEvent read FOnProgress write FOnProgress;
  end;

implementation

{ TQueryWorkerThread }

constructor TQueryWorkerThread.Create(AProfile: TConnectionProfile; const ASQL: string; const ADatabaseTarget: string);
begin
  inherited Create(True); // Dimulai dalam keadaan suspended
  FreeOnTerminate := False;

  FProfile := TConnectionProfile.Create;
  if Assigned(AProfile) then
    FProfile.Assign(AProfile);

  FSQL := ASQL;
  FDatabaseTarget := ADatabaseTarget;
  if (FDatabaseTarget <> '') and (FProfile.DriverType in [dtMySQL, dtMariaDB, dtPostgreSQL]) then
    FProfile.DatabaseName := FDatabaseTarget;

  FDriver := nil;
  FQuery := nil;
  FillChar(FResult, SizeOf(TDBQueryResult), 0);
  FResult.StatementType := DetectStatementType(FSQL);
end;

destructor TQueryWorkerThread.Destroy;
begin
  if Assigned(FQuery) then
    FreeAndNil(FQuery);

  if Assigned(FDriver) then
    FreeAndNil(FDriver);

  if Assigned(FProfile) then
    FreeAndNil(FProfile);

  //inherited Destroy;
end;

procedure TQueryWorkerThread.ReportProgress(const AMessage: string);
begin
  FProgressMessage := AMessage;
  Synchronize(@DoSyncProgress);
end;

procedure TQueryWorkerThread.DoSyncProgress;
begin
  if Assigned(FOnProgress) and not Terminated then
    FOnProgress(Self, FProgressMessage);
end;

procedure TQueryWorkerThread.DoSyncSuccess;
begin
  if Assigned(FOnSuccess) and not Terminated then
    FOnSuccess(Self, FResult, FQuery);
end;

procedure TQueryWorkerThread.DoSyncError;
begin
  if Assigned(FOnError) and not Terminated then
    FOnError(Self, FResult);
end;

procedure TQueryWorkerThread.CancelExecution;
begin
  Terminate;
  try
    if Assigned(FDriver) and FDriver.IsConnected then
    begin
      if Assigned(FQuery) and FQuery.Active then
        FQuery.Close;
      FDriver.Disconnect;
    end;
  except
    // Mengabaikan kegagalan disconnect saat pembatalan paksa
  end;
end;

procedure TQueryWorkerThread.Execute;
var
  StartTime: TDateTime;
begin
  StartTime := Now;
  try
    ReportProgress('Menghubungkan ke database...');
    FDriver := TDBConnectionFactory.CreateDriver(FProfile);
    FDriver.Connect;

    if Terminated then Exit;

    FQuery := TZQuery.Create(nil);
    FQuery.Connection := FDriver.Connection;

    ReportProgress('Mengeksekusi kueri...');
    if FDriver.ExecuteQuery(FSQL, FResult, FQuery) then
    begin
      if not Terminated then
      begin
        ReportProgress('Eksekusi selesai.');
        Synchronize(@DoSyncSuccess);
      end;
    end
    else
    begin
      if not Terminated then
        Synchronize(@DoSyncError);
    end;
  except
    on E: Exception do
    begin
      FResult.IsSuccess := False;
      FResult.ErrorMessage := E.Message;
      FResult.ExecutionTimeMS := MilliSecondsBetween(Now, StartTime);
      if not Terminated then
        Synchronize(@DoSyncError);
    end;
  end;
end;

end.

