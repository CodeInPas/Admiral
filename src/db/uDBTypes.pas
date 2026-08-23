unit uDBTypes;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, uAppTypes;

type
  { TStatementType }
  TStatementType = (
    stSelect,
    stInsert,
    stUpdate,
    stDelete,
    stDDL,
    stTransaction,
    stOther
  );

  { TDBCapability }
  TDBCapability = (
    dbcSchemas,
    dbcStoredProcedures,
    dbcFunctions,
    dbcTriggers,
    dbcSequences,
    dbcForeignKeys,
    dbcExplainPlan,
    dbcMultipleDatabases,
    dbcSSLConnection,
    dbcCancelQuery
  );

  TDBCapabilities = set of TDBCapability;

  { TDBServerInfo }
  TDBServerInfo = record
    ProductName: string;
    ServerVersion: string;
    VersionMajor: Integer;
    VersionMinor: Integer;
    VersionRelease: Integer;
    CurrentDatabase: string;
    CurrentUser: string;
    HostAddress: string;
    Port: Integer;
    DefaultCharset: string;
    IsConnected: Boolean;
  end;

  { TDBQueryResult }
  TDBQueryResult = record
    StatementType: TStatementType;
    IsSuccess: Boolean;
    RowsAffected: Int64;
    ExecutionTimeMS: Int64;
    ErrorMessage: string;
    WarningMessage: string;
    HasResultSet: Boolean;
  end;

  { TDBExecutionPlanNode }
  TDBExecutionPlanNode = record
    ID: Integer;
    ParentID: Integer;
    Operation: string;
    TargetObject: string;
    Cost: Double;
    EstimatedRows: Int64;
    ActualRows: Int64;
    Details: string;
  end;

  TDBExecutionPlanArray = array of TDBExecutionPlanNode;

  { Callback & Event Types }
  TDBStateChangeEvent = procedure(const AConnected: Boolean; const AStatusMessage: string) of object;
  TDBQueryProgressEvent = procedure(const ARowsFetched: Int64; const AExecutionTimeMS: Int64) of object;

// Deteksi Statement Type dari teks query dasar
function DetectStatementType(const ASQL: string): TStatementType;

implementation

function DetectStatementType(const ASQL: string): TStatementType;
var
  CleanSQL: string;
begin
  CleanSQL := UpperCase(Trim(ASQL));

  if (Pos('SELECT', CleanSQL) = 1) or (Pos('WITH', CleanSQL) = 1) or
     (Pos('SHOW', CleanSQL) = 1) or (Pos('DESCRIBE', CleanSQL) = 1) or
     (Pos('EXPLAIN', CleanSQL) = 1) or (Pos('PRAGMA', CleanSQL) = 1) then
    Result := stSelect
  else if Pos('INSERT', CleanSQL) = 1 then
    Result := stInsert
  else if Pos('UPDATE', CleanSQL) = 1 then
    Result := stUpdate
  else if Pos('DELETE', CleanSQL) = 1 then
    Result := stDelete
  else if (Pos('CREATE', CleanSQL) = 1) or (Pos('ALTER', CleanSQL) = 1) or
          (Pos('DROP', CleanSQL) = 1) or (Pos('TRUNCATE', CleanSQL) = 1) or
          (Pos('RENAME', CleanSQL) = 1) then
    Result := stDDL
  else if (Pos('BEGIN', CleanSQL) = 1) or (Pos('START TRANSACTION', CleanSQL) = 1) or
          (Pos('COMMIT', CleanSQL) = 1) or (Pos('ROLLBACK', CleanSQL) = 1) then
    Result := stTransaction
  else
    Result := stOther;
end;

end.

