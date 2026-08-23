unit uDBConnectionFactory;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  uAppTypes, uDBTypes, uDBDriverBase, uModelConnection, uSSHTunnelService,
  uDriverSQLite, uDriverMySQL, uDriverMariaDB, uDriverFirebird, uDriverPostgreSQL;

type
  { EDBDriverFactoryException }
  EDBDriverFactoryException = class(Exception);

  { TDBConnectionFactory }
  TDBConnectionFactory = class
  public
    // Pembuatan Instance Driver berdasarkan Profil Koneksi
    class function CreateDriver(AProfile: TConnectionProfile): TDBDriverBase;
    class function CreateDriverByType(const ADriverType: TDBDriverType; AProfile: TConnectionProfile): TDBDriverBase;

    // Helper Utilitas Koneksi & SSH
    class function TestConnection(AProfile: TConnectionProfile; out AErrorMessage: string): Boolean;
    class function GetDefaultPort(const ADriverType: TDBDriverType): Integer;
    class function GetDriverDisplayName(const ADriverType: TDBDriverType): string;
    class function GetDriverProtocol(const ADriverType: TDBDriverType): string;
    class function SupportsFeature(const ADriverType: TDBDriverType; const ACapability: TDBCapability): Boolean;
    class function GetEffectiveHost(AProfile: TConnectionProfile): string;
    class function GetEffectivePort(AProfile: TConnectionProfile): Integer;
  end;

implementation

{ TDBConnectionFactory }

class function TDBConnectionFactory.GetEffectiveHost(AProfile: TConnectionProfile): string;
begin
  if not Assigned(AProfile) then Exit('127.0.0.1');

  // Jika SSH Tunnel aktif, target host dialihkan ke localhost
  if AProfile.UseSSH and (AProfile.ActiveLocalPort > 0) and (AProfile.DriverType <> dtSQLite) then
    Result := '127.0.0.1'
  else
    Result := AProfile.Host;
end;

class function TDBConnectionFactory.GetEffectivePort(AProfile: TConnectionProfile): Integer;
begin
  if not Assigned(AProfile) then Exit(0);

  // Jika SSH Tunnel aktif, port dialihkan ke local forward port
  if AProfile.UseSSH and (AProfile.ActiveLocalPort > 0) and (AProfile.DriverType <> dtSQLite) then
    Result := AProfile.ActiveLocalPort
  else
    Result := AProfile.Port;
end;

class function TDBConnectionFactory.CreateDriver(AProfile: TConnectionProfile): TDBDriverBase;
begin
  if not Assigned(AProfile) then
    raise EDBDriverFactoryException.Create('Connection profile cannot be nil.');

  Result := CreateDriverByType(AProfile.DriverType, AProfile);
end;

class function TDBConnectionFactory.CreateDriverByType(const ADriverType: TDBDriverType; AProfile: TConnectionProfile): TDBDriverBase;
begin
  case ADriverType of
    dtSQLite:
      Result := TDriverSQLite.Create(AProfile);
    dtMySQL:
      Result := TDriverMySQL.Create(AProfile);
    dtMariaDB:
      Result := TDriverMariaDB.Create(AProfile);
    dtFirebird:
      Result := TDriverFirebird.Create(AProfile);
    dtPostgreSQL:
      Result := TDriverPostgreSQL.Create(AProfile);
    else
      raise EDBDriverFactoryException.CreateFmt('Unsupported database driver type: %d', [Ord(ADriverType)]);
  end;
end;

class function TDBConnectionFactory.TestConnection(AProfile: TConnectionProfile; out AErrorMessage: string): Boolean;
var
  Driver: TDBDriverBase;
  Tunnel: TSSHTunnel;
  TempProfile: TConnectionProfile;
  SSHErr: string;
begin
  Result := False;
  AErrorMessage := '';

  if not Assigned(AProfile) then
  begin
    AErrorMessage := 'Invalid profile configuration (nil).';
    Exit;
  end;

  Tunnel := nil;
  TempProfile := TConnectionProfile.Create;
  try
    TempProfile.Assign(AProfile);

    // 1. Inisiasi SSH Tunnel sementara jika opsi SSH aktif dan port forward belum berjalan
    if TempProfile.UseSSH and (TempProfile.ActiveLocalPort = 0) and (TempProfile.DriverType <> dtSQLite) then
    begin
      Tunnel := TSSHTunnel.Create;
      if not Tunnel.StartTunnel(TempProfile, SSHErr) then
      begin
        AErrorMessage := 'SSH Tunnel Connection Failed: ' + SSHErr;
        Exit;
      end;
    end;

    // 2. Uji koneksi ke database target via driver
    try
      Driver := CreateDriver(TempProfile);
      try
        Result := Driver.TestConnection;
        if not Result then
          AErrorMessage := 'Failed to establish connection to database server.';
      finally
        Driver.Free;
      end;
    except
      on E: Exception do
      begin
        Result := False;
        AErrorMessage := E.Message;
      end;
    end;

  finally
    // 3. Bersihkan tunnel uji coba sementara jika dibuat
    if Assigned(Tunnel) then
    begin
      Tunnel.StopTunnel;
      Tunnel.Free;
    end;
    TempProfile.Free;
  end;
end;

class function TDBConnectionFactory.GetDefaultPort(const ADriverType: TDBDriverType): Integer;
begin
  case ADriverType of
    dtMySQL, dtMariaDB:
      Result := 3306;
    dtPostgreSQL:
      Result := 5432;
    dtFirebird:
      Result := 3050;
    dtSQLite:
      Result := 0;
    else
      Result := 0;
  end;
end;

class function TDBConnectionFactory.GetDriverDisplayName(const ADriverType: TDBDriverType): string;
begin
  case ADriverType of
    dtSQLite:     Result := 'SQLite 3';
    dtMySQL:      Result := 'MySQL';
    dtMariaDB:    Result := 'MariaDB';
    dtFirebird:   Result := 'Firebird';
    dtPostgreSQL: Result := 'PostgreSQL';
    else          Result := 'Unknown Driver';
  end;
end;

class function TDBConnectionFactory.GetDriverProtocol(const ADriverType: TDBDriverType): string;
begin
  case ADriverType of
    dtSQLite:     Result := 'sqlite';
    dtMySQL:      Result := 'mysql';
    dtMariaDB:    Result := 'mariadb';
    dtFirebird:   Result := 'firebird';
    dtPostgreSQL: Result := 'postgresql';
    else          Result := '';
  end;
end;

class function TDBConnectionFactory.SupportsFeature(const ADriverType: TDBDriverType; const ACapability: TDBCapability): Boolean;
var
  DummyProfile: TConnectionProfile;
  Driver: TDBDriverBase;
begin
  DummyProfile := TConnectionProfile.Create;
  try
    DummyProfile.DriverType := ADriverType;
    Driver := CreateDriver(DummyProfile);
    try
      Result := ACapability in Driver.GetCapabilities;
    finally
      Driver.Free;
    end;
  finally
    DummyProfile.Free;
  end;
end;

end.
