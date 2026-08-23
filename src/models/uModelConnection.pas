unit uModelConnection;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fgl,
  uAppConst, uAppTypes, uDBTypes;

type
  { TConnectionGroup }
  TConnectionGroup = class
  private
    FID: Int64;
    FName: string;
    FParentID: Int64;
    FColorHex: string;
    FSortOrder: Integer;
    FCreatedAt: TDateTime;
  public
    constructor Create;
    procedure Assign(ASource: TConnectionGroup);
    function Clone: TConnectionGroup;

    property ID: Int64 read FID write FID;
    property Name: string read FName write FName;
    property ParentID: Int64 read FParentID write FParentID;
    property ColorHex: string read FColorHex write FColorHex;
    property SortOrder: Integer read FSortOrder write FSortOrder;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
  end;

  { TConnectionGroupList }
  TConnectionGroupList = specialize TFPGObjectList<TConnectionGroup>;

  { TConnectionProfile }
  TConnectionProfile = class
  private
    FID: Int64;
    FGroupID: Int64;
    FName: string;
    FDriverType: TDBDriverType;
    FHost: string;
    FPort: Integer;
    FDatabaseName: string;
    FCharset: string;
    FUsername: string;
    FPasswordEnc: string;
    FSavePassword: Boolean;
    FTimeoutSec: Integer;
    FSSLMode: TSSLMode;
    FSSHEnabled: Boolean;
    FSSHHost: string;
    FSSHPort: Integer;
    FSSHUser: string;
    FSSHAuthType: TSSHAuthType;
    FSSHKeyPath: string;
    FSSHPassEnc: string;
    FActiveLocalPort: Integer; // Port lokal saat SSH Tunnel aktif
    FEnvTag: TEnvironmentTag;
    FColorHex: string;
    FGroupFolder: string;
    FIsFavorite: Boolean;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    constructor Create;
    procedure Assign(ASource: TConnectionProfile);
    function Clone: TConnectionProfile;

    // Helper display
    function GetDisplayName: string;
    function GetTargetHostDisplay: string;
    function IsFileBasedDriver: Boolean;

    // Identitas & Pengelompokan
    property ID: Int64 read FID write FID;
    property GroupID: Int64 read FGroupID write FGroupID;
    property Name: string read FName write FName;
    property ConnectionName: string read FName write FName;
    property GroupFolder: string read FGroupFolder write FGroupFolder;

    // Parameter Database Server
    property DriverType: TDBDriverType read FDriverType write FDriverType;
    property Host: string read FHost write FHost;
    property Port: Integer read FPort write FPort;
    property DatabaseName: string read FDatabaseName write FDatabaseName;
    property Charset: string read FCharset write FCharset;
    property Username: string read FUsername write FUsername;
    property Password: string read FPasswordEnc write FPasswordEnc;
    property PasswordEnc: string read FPasswordEnc write FPasswordEnc;
    property SavePassword: Boolean read FSavePassword write FSavePassword;
    property TimeoutSec: Integer read FTimeoutSec write FTimeoutSec;
    property SSLMode: TSSLMode read FSSLMode write FSSLMode;

    // Parameter SSH Tunneling
    property SSHEnabled: Boolean read FSSHEnabled write FSSHEnabled;
    property SSHHost: string read FSSHHost write FSSHHost;
    property SSHPort: Integer read FSSHPort write FSSHPort;
    property SSHUser: string read FSSHUser write FSSHUser;
    property SSHAuthType: TSSHAuthType read FSSHAuthType write FSSHAuthType;
    property SSHKeyPath: string read FSSHKeyPath write FSSHKeyPath;
    property SSHPassEnc: string read FSSHPassEnc write FSSHPassEnc;
    property ActiveLocalPort: Integer read FActiveLocalPort write FActiveLocalPort;

    // Alias Properti SSH (Kompatibilitas Lintas Modul)
    property UseSSH: Boolean read FSSHEnabled write FSSHEnabled;
    property SSHUsername: string read FSSHUser write FSSHUser;
    property SSHKeyFile: string read FSSHKeyPath write FSSHKeyPath;
    property SSHPassword: string read FSSHPassEnc write FSSHPassEnc;
    property SSHPassphrase: string read FSSHPassEnc write FSSHPassEnc;

    // UI & Metadata
    property EnvTag: TEnvironmentTag read FEnvTag write FEnvTag;
    property ColorHex: string read FColorHex write FColorHex;
    property ColorTag: string read FColorHex write FColorHex;
    property IsFavorite: Boolean read FIsFavorite write FIsFavorite;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  { TConnectionProfileList }
  TConnectionProfileList = specialize TFPGObjectList<TConnectionProfile>;

implementation

{ TConnectionGroup }

constructor TConnectionGroup.Create;
begin
  inherited Create;
  FID := 0;
  FName := 'New Group';
  FParentID := 0;
  FColorHex := '';
  FSortOrder := 0;
  FCreatedAt := Now;
end;

procedure TConnectionGroup.Assign(ASource: TConnectionGroup);
begin
  if not Assigned(ASource) then Exit;
  FID := ASource.FID;
  FName := ASource.FName;
  FParentID := ASource.FParentID;
  FColorHex := ASource.FColorHex;
  FSortOrder := ASource.FSortOrder;
  FCreatedAt := ASource.FCreatedAt;
end;

function TConnectionGroup.Clone: TConnectionGroup;
begin
  Result := TConnectionGroup.Create;
  Result.Assign(Self);
end;

{ TConnectionProfile }

constructor TConnectionProfile.Create;
begin
  inherited Create;
  FID := 0;
  FGroupID := 0;
  FName := 'New Connection';
  FDriverType := dtSQLite;
  FHost := '127.0.0.1';
  FPort := 0;
  FDatabaseName := '';
  FCharset := 'UTF8';
  FUsername := '';
  FPasswordEnc := '';
  FSavePassword := True;
  FTimeoutSec := DEFAULT_CONNECTION_TIMEOUT;
  FSSLMode := sslDisable;
  FSSHEnabled := False;
  FSSHHost := '';
  FSSHPort := DEFAULT_PORT_SSH;
  FSSHUser := '';
  FSSHAuthType := Low(TSSHAuthType);
  FSSHKeyPath := '';
  FSSHPassEnc := '';
  FActiveLocalPort := 0;
  FEnvTag := envDevelopment;
  FColorHex := COLOR_ENV_DEV;
  FGroupFolder := '';
  FIsFavorite := False;
  FCreatedAt := Now;
  FUpdatedAt := Now;
end;

procedure TConnectionProfile.Assign(ASource: TConnectionProfile);
begin
  if not Assigned(ASource) then Exit;

  FID := ASource.FID;
  FGroupID := ASource.FGroupID;
  FName := ASource.FName;
  FDriverType := ASource.FDriverType;
  FHost := ASource.FHost;
  FPort := ASource.FPort;
  FDatabaseName := ASource.FDatabaseName;
  FCharset := ASource.FCharset;
  FUsername := ASource.FUsername;
  FPasswordEnc := ASource.FPasswordEnc;
  FSavePassword := ASource.FSavePassword;
  FTimeoutSec := ASource.FTimeoutSec;
  FSSLMode := ASource.FSSLMode;
  FSSHEnabled := ASource.FSSHEnabled;
  FSSHHost := ASource.FSSHHost;
  FSSHPort := ASource.FSSHPort;
  FSSHUser := ASource.FSSHUser;
  FSSHAuthType := ASource.FSSHAuthType;
  FSSHKeyPath := ASource.FSSHKeyPath;
  FSSHPassEnc := ASource.FSSHPassEnc;
  FActiveLocalPort := ASource.FActiveLocalPort;
  FEnvTag := ASource.FEnvTag;
  FColorHex := ASource.FColorHex;
  FGroupFolder := ASource.FGroupFolder;
  FIsFavorite := ASource.FIsFavorite;
  FCreatedAt := ASource.FCreatedAt;
  FUpdatedAt := ASource.FUpdatedAt;
end;

function TConnectionProfile.Clone: TConnectionProfile;
begin
  Result := TConnectionProfile.Create;
  Result.Assign(Self);
end;

function TConnectionProfile.IsFileBasedDriver: Boolean;
begin
  Result := (FDriverType = dtSQLite);
end;

function TConnectionProfile.GetTargetHostDisplay: string;
begin
  if IsFileBasedDriver then
    Result := ExtractFileName(FDatabaseName)
  else if FPort > 0 then
    Result := Format('%s:%d', [FHost, FPort])
  else
    Result := FHost;
end;

function TConnectionProfile.GetDisplayName: string;
var
  DriverStr: string;
begin
  case FDriverType of
    dtSQLite:     DriverStr := 'SQLite';
    dtMySQL:      DriverStr := 'MySQL';
    dtMariaDB:    DriverStr := 'MariaDB';
    dtFirebird:   DriverStr := 'Firebird';
    dtPostgreSQL: DriverStr := 'PostgreSQL';
    else          DriverStr := 'Database';
  end;

  if FName <> '' then
    Result := Format('%s (%s)', [FName, DriverStr])
  else
    Result := Format('%s - %s', [DriverStr, GetTargetHostDisplay]);
end;

end.
