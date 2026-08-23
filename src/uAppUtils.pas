unit uAppUtils;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, uAppConst, uAppTypes;

// Konversi Enum Driver DBMS
function DriverTypeToString(const ADriverType: TDBDriverType): string;
function StringToDriverType(const AValue: string): TDBDriverType;

// Konversi Enum Environment Tag
function EnvTagToString(const AEnvTag: TEnvironmentTag): string;
function StringToEnvTag(const AValue: string): TEnvironmentTag;

// Konversi Enum Mode SSL
function SSLModeToString(const ASSLMode: TSSLMode): string;
function StringToSSLMode(const AValue: string): TSSLMode;

// Konversi Enum Autentikasi SSH
function SSHAuthTypeToString(const AAuthType: TSSHAuthType): string;
function StringToSSHAuthType(const AValue: string): TSSHAuthType;

// Utilitas Jaringan & Default DBMS
function GetDefaultPort(const ADriverType: TDBDriverType): Integer;
function GetDefaultEnvColor(const AEnvTag: TEnvironmentTag): string;

// Utilitas Path & Direktori Internal
function GetAppDataPath: string;
function GetInternalDatabasePath: string;
function EnsureDirectoryExists(const ADirPath: string): Boolean;

// Utilitas Keamanan Kredensial Ringan (Obfuscation / Encoding Base64 + XOR)
function SimpleEncrypt(const APlainText: string): string;
function SimpleDecrypt(const ACipherText: string): string;

// Utilitas Format & Pemrosesan Query
function FormatExecutionTime(const AMilliSeconds: Int64): string;
function FormatByteSize(const ABytes: Int64): string;
function IsDestructiveSQL(const ASQLText: string): Boolean;

implementation

const
  ENCRYPTION_KEY: Byte = $A5;

function DriverTypeToString(const ADriverType: TDBDriverType): string;
begin
  case ADriverType of
    dtSQLite:     Result := DRIVER_SQLITE;
    dtMySQL:      Result := DRIVER_MYSQL;
    dtMariaDB:    Result := DRIVER_MARIADB;
    dtFirebird:   Result := DRIVER_FIREBIRD;
    dtPostgreSQL: Result := DRIVER_POSTGRESQL;
  else
    Result := DRIVER_SQLITE;
  end;
end;

function StringToDriverType(const AValue: string): TDBDriverType;
var
  S: string;
begin
  S := UpperCase(Trim(AValue));
  if S = DRIVER_MYSQL then Result := dtMySQL
  else if S = DRIVER_MARIADB then Result := dtMariaDB
  else if S = DRIVER_FIREBIRD then Result := dtFirebird
  else if S = DRIVER_POSTGRESQL then Result := dtPostgreSQL
  else Result := dtSQLite;
end;

function EnvTagToString(const AEnvTag: TEnvironmentTag): string;
begin
  case AEnvTag of
    envDevelopment: Result := ENV_DEVELOPMENT;
    envTesting:     Result := ENV_TESTING;
    envStaging:     Result := ENV_STAGING;
    envProduction:  Result := ENV_PRODUCTION;
  else
    Result := ENV_DEVELOPMENT;
  end;
end;

function StringToEnvTag(const AValue: string): TEnvironmentTag;
var
  S: string;
begin
  S := UpperCase(Trim(AValue));
  if S = ENV_TESTING then Result := envTesting
  else if S = ENV_STAGING then Result := envStaging
  else if S = ENV_PRODUCTION then Result := envProduction
  else Result := envDevelopment;
end;

function SSLModeToString(const ASSLMode: TSSLMode): string;
begin
  case ASSLMode of
    sslDisable:    Result := SSL_MODE_DISABLE;
    sslRequire:    Result := SSL_MODE_REQUIRE;
    sslVerifyCA:   Result := SSL_MODE_VERIFY_CA;
    sslVerifyFull: Result := SSL_MODE_VERIFY_FULL;
  else
    Result := SSL_MODE_DISABLE;
  end;
end;

function StringToSSLMode(const AValue: string): TSSLMode;
var
  S: string;
begin
  S := UpperCase(Trim(AValue));
  if S = SSL_MODE_REQUIRE then Result := sslRequire
  else if S = SSL_MODE_VERIFY_CA then Result := sslVerifyCA
  else if S = SSL_MODE_VERIFY_FULL then Result := sslVerifyFull
  else Result := sslDisable;
end;

function SSHAuthTypeToString(const AAuthType: TSSHAuthType): string;
begin
  case AAuthType of
    sshPassword: Result := SSH_AUTH_PASSWORD;
    sshKeyFile:  Result := SSH_AUTH_KEY_FILE;
  else
    Result := SSH_AUTH_PASSWORD;
  end;
end;

function StringToSSHAuthType(const AValue: string): TSSHAuthType;
var
  S: string;
begin
  S := UpperCase(Trim(AValue));
  if S = SSH_AUTH_KEY_FILE then Result := sshKeyFile
  else Result := sshPassword;
end;

function GetDefaultPort(const ADriverType: TDBDriverType): Integer;
begin
  case ADriverType of
    dtMySQL, dtMariaDB: Result := DEFAULT_PORT_MYSQL;
    dtPostgreSQL:       Result := DEFAULT_PORT_POSTGRESQL;
    dtFirebird:         Result := DEFAULT_PORT_FIREBIRD;
  else
    Result := 0;
  end;
end;

function GetDefaultEnvColor(const AEnvTag: TEnvironmentTag): string;
begin
  case AEnvTag of
    envDevelopment: Result := COLOR_ENV_DEV;
    envTesting:     Result := COLOR_ENV_TEST;
    envStaging:     Result := COLOR_ENV_STAGE;
    envProduction:  Result := COLOR_ENV_PROD;
  else
    Result := COLOR_ENV_DEV;
  end;
end;

function GetAppDataPath: string;
begin
  {$IFDEF UNIX}
  Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) + '.config/' + APP_NAME + '/';
  {$ELSE}
  Result := IncludeTrailingPathDelimiter(GetAppConfigDir(False));
  {$ENDIF}
  EnsureDirectoryExists(Result);
end;

function GetInternalDatabasePath: string;
begin
  Result := GetAppDataPath + APP_INTERNAL_DB_NAME;
end;

function EnsureDirectoryExists(const ADirPath: string): Boolean;
begin
  if not DirectoryExists(ADirPath) then
    Result := ForceDirectories(ADirPath)
  else
    Result := True;
end;

function SimpleEncrypt(const APlainText: string): string;
var
  I: Integer;
  HexBuf: string;
  XorVal: Byte;
begin
  if APlainText = '' then Exit('');
  HexBuf := '';
  for I := 1 to Length(APlainText) do
  begin
    XorVal := Byte(APlainText[I]) xor ENCRYPTION_KEY;
    HexBuf := HexBuf + IntToHex(XorVal, 2);
  end;
  Result := HexBuf;
end;

function SimpleDecrypt(const ACipherText: string): string;
var
  I: Integer;
  ByteVal: Byte;
  PlainBuf: string;
begin
  if (ACipherText = '') or (Length(ACipherText) mod 2 <> 0) then Exit('');
  PlainBuf := '';
  I := 1;
  while I < Length(ACipherText) do
  begin
    ByteVal := StrToIntDef('$' + Copy(ACipherText, I, 2), 0);
    ByteVal := ByteVal xor ENCRYPTION_KEY;
    PlainBuf := PlainBuf + Chr(ByteVal);
    Inc(I, 2);
  end;
  Result := PlainBuf;
end;

function FormatExecutionTime(const AMilliSeconds: Int64): string;
begin
  if AMilliSeconds < 1000 then
    Result := Format('%d ms', [AMilliSeconds])
  else if AMilliSeconds < 60000 then
    Result := Format('%.2f s', [AMilliSeconds / 1000.0])
  else
    Result := Format('%.2f min', [AMilliSeconds / 60000.0]);
end;

function FormatByteSize(const ABytes: Int64): string;
const
  KB = 1024;
  MB = KB * 1024;
  GB = MB * 1024;
begin
  if ABytes < KB then
    Result := Format('%d B', [ABytes])
  else if ABytes < MB then
    Result := Format('%.2f KB', [ABytes / KB])
  else if ABytes < GB then
    Result := Format('%.2f MB', [ABytes / MB])
  else
    Result := Format('%.2f GB', [ABytes / GB]);
end;

function IsDestructiveSQL(const ASQLText: string): Boolean;
var
  CleanSQL: string;
begin
  CleanSQL := UpperCase(Trim(ASQLText));
  Result := (Pos('DROP ', CleanSQL) = 1) or
            (Pos('TRUNCATE ', CleanSQL) = 1) or
            (Pos('DELETE FROM', CleanSQL) > 0) or
            (Pos('ALTER TABLE', CleanSQL) = 1);
end;

end.

