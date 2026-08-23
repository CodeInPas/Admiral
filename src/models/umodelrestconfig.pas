unit uModelRESTConfig;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Contnrs,
  uAppTypes, uDBTypes, uModelConnection;

type
  { Operasi CRUD yang diizinkan per endpoint }
  TRestOperation = (roList, roDetail, roCreate, roUpdate, roDelete);
  TRestOperations = set of TRestOperation;

  { Konfigurasi Tabel Terpilih }
  TRestTableConfig = class
  private
    FTableName: string;
    FIsView: Boolean;
    FCustomRoute: string;
    FPrimaryKey: string;
    FAllowedOperations: TRestOperations;
    FSelectedColumns: TStringList;
    FExcludedColumns: TStringList;
    FSearchableColumns: TStringList;
  public
    constructor Create;
    destructor Destroy; override;

    property TableName: string read FTableName write FTableName;
    property IsView: Boolean read FIsView write FIsView;
    property CustomRoute: string read FCustomRoute write FCustomRoute;
    property PrimaryKey: string read FPrimaryKey write FPrimaryKey;
    property AllowedOperations: TRestOperations read FAllowedOperations write FAllowedOperations;
    property SelectedColumns: TStringList read FSelectedColumns;
    property ExcludedColumns: TStringList read FExcludedColumns;
    property SearchableColumns: TStringList read FSearchableColumns;
  end;

  { Konfigurasi Proyek Backend }
  TRestProjectConfig = class
  private
    FProfile: TConnectionProfile;
    FDatabaseName: string;
    FTargetFramework: string;
    FBaseRoute: string;
    FServerPort: Integer;
    FEnableAuth: Boolean;
    FApiKey: string;
    FOutputDirectory: string;
    FTables: TFPObjectList;
    function GetTableCount: Integer;
    function GetTable(AIndex: Integer): TRestTableConfig;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;
    function AddTable(const ATableName: string; const AIsView: Boolean): TRestTableConfig;

    property Profile: TConnectionProfile read FProfile write FProfile;
    property DatabaseName: string read FDatabaseName write FDatabaseName;
    property TargetFramework: string read FTargetFramework write FTargetFramework;
    property BaseRoute: string read FBaseRoute write FBaseRoute;
    property ServerPort: Integer read FServerPort write FServerPort;
    property EnableAuth: Boolean read FEnableAuth write FEnableAuth;
    property ApiKey: string read FApiKey write FApiKey;
    property OutputDirectory: string read FOutputDirectory write FOutputDirectory;
    property TableCount: Integer read GetTableCount;
    property Tables[AIndex: Integer]: TRestTableConfig read GetTable;
  end;

implementation

{ TRestTableConfig }

constructor TRestTableConfig.Create;
begin
  inherited Create;
  FTableName := '';
  FIsView := False;
  FCustomRoute := '';
  FPrimaryKey := 'id';
  FAllowedOperations := [roList, roDetail, roCreate, roUpdate, roDelete];
  FSelectedColumns := TStringList.Create;
  FExcludedColumns := TStringList.Create;
  FSearchableColumns := TStringList.Create;
end;

destructor TRestTableConfig.Destroy;
begin
  FSelectedColumns.Free;
  FExcludedColumns.Free;
  FSearchableColumns.Free;
  inherited Destroy;
end;

{ TRestProjectConfig }

constructor TRestProjectConfig.Create;
begin
  inherited Create;
  FProfile := nil;
  FDatabaseName := '';
  FTargetFramework := 'node_express';
  FBaseRoute := '/api/v1';
  FServerPort := 3000;
  FEnableAuth := False;
  FApiKey := 'siadmin-secret-api-key-2026';
  FOutputDirectory := '';
  FTables := TFPObjectList.Create(True);
end;

destructor TRestProjectConfig.Destroy;
begin
  FTables.Free;
  inherited Destroy;
end;

procedure TRestProjectConfig.Clear;
begin
  FTables.Clear;
end;

function TRestProjectConfig.GetTableCount: Integer;
begin
  Result := FTables.Count;
end;

function TRestProjectConfig.GetTable(AIndex: Integer): TRestTableConfig;
begin
  Result := TRestTableConfig(FTables[AIndex]);
end;

function TRestProjectConfig.AddTable(const ATableName: string; const AIsView: Boolean): TRestTableConfig;
begin
  Result := TRestTableConfig.Create;
  Result.TableName := ATableName;
  Result.IsView := AIsView;
  Result.CustomRoute := LowerCase(StringReplace(ATableName, '_', '-', [rfReplaceAll]));
  if AIsView then
    Result.AllowedOperations := [roList, roDetail];
  FTables.Add(Result);
end;

end.
