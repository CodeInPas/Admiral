unit uDBUserManagerService;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  ZConnection, ZDataset,
  uAppTypes, uDBTypes, uModelConnection, uDBDriverBase, uDBConnectionFactory;

type
  { TDBUserInfo }
  TDBUserInfo = class
  public
    Username: string;
    Host: string;
    IsSuperUser: Boolean;
    CanLogin: Boolean;
    ExpireDate: string;
    RawDetails: string;
  end;

  { TDBUserManagerService }
  TDBUserManagerService = class
  private
    class function CreateTempConnection(AProfile: TConnectionProfile): TZConnection;
  public
    class function FetchUsers(AProfile: TConnectionProfile; AList: TList; out AError: string): Boolean;
    class function CreateUser(AProfile: TConnectionProfile; const AUser, AHost, APassword: string; const AIsSuper: Boolean; out AError: string): Boolean;
    class function DropUser(AProfile: TConnectionProfile; const AUser, AHost: string; out AError: string): Boolean;
    class function ChangePassword(AProfile: TConnectionProfile; const AUser, AHost, ANewPassword: string; out AError: string): Boolean;
    class function FetchUserGrants(AProfile: TConnectionProfile; const AUser, AHost: string; AGrantsList: TStrings; out AError: string): Boolean;
    class function ApplyPrivileges(AProfile: TConnectionProfile; const AUser, AHost, ADBTarget: string; const APrivileges: TStrings; const AIsGrant: Boolean; const AWithGrantOption: Boolean; out AError: string): Boolean;
  end;

implementation

{ TDBUserManagerService }

class function TDBUserManagerService.CreateTempConnection(AProfile: TConnectionProfile): TZConnection;
begin
  Result := TZConnection.Create(nil);
  case AProfile.DriverType of
    dtMySQL: Result.Protocol := 'mysql';
    dtMariaDB: Result.Protocol := 'mariadb';
    dtPostgreSQL: Result.Protocol := 'postgresql';
    dtFirebird: Result.Protocol := 'firebird';
    dtSQLite: Result.Protocol := 'sqlite';
  end;

  Result.HostName := AProfile.Host;
  Result.Port := AProfile.Port;
  Result.Database := AProfile.DatabaseName;
  Result.User := AProfile.Username;
  Result.Password := AProfile.Password;
  Result.AutoCommit := True;

  if AProfile.Charset <> '' then
    Result.Properties.Values['codepage'] := AProfile.Charset;
end;

class function TDBUserManagerService.FetchUsers(AProfile: TConnectionProfile; AList: TList; out AError: string): Boolean;
var
  Conn: TZConnection;
  Qry: TZQuery;
  Item: TDBUserInfo;
begin
  Result := False;
  AError := '';

  if AProfile.DriverType = dtSQLite then
  begin
    AError := 'SQLite beroperasi secara embedded dan tidak memiliki sistem autentikasi user native.';
    Exit;
  end;

  Conn := CreateTempConnection(AProfile);
  Qry := TZQuery.Create(nil);
  try
    try
      Conn.Connect;
      Qry.Connection := Conn;
      Qry.ParamCheck := False;

      case AProfile.DriverType of
        dtMySQL, dtMariaDB:
        begin
          Qry.SQL.Text := 'SELECT User, Host, IFNULL(Super_priv, ''N'') AS IsSuper FROM mysql.user ORDER BY User, Host;';
          Qry.Open;
          while not Qry.EOF do
          begin
            Item := TDBUserInfo.Create;
            Item.Username := Qry.FieldByName('User').AsString;
            Item.Host := Qry.FieldByName('Host').AsString;
            Item.IsSuperUser := (UpperCase(Qry.FieldByName('IsSuper').AsString) = 'Y');
            Item.CanLogin := True;
            AList.Add(Item);
            Qry.Next;
          end;
        end;

        dtPostgreSQL:
        begin
          Qry.SQL.Text :=
            'SELECT rolname, rolsuper, rolcanlogin, rolvaliduntil ' +
            'FROM pg_roles ' +
            'WHERE rolname NOT LIKE ''pg_%'' ' +
            'ORDER BY rolname;';
          Qry.Open;
          while not Qry.EOF do
          begin
            Item := TDBUserInfo.Create;
            Item.Username := Qry.FieldByName('rolname').AsString;
            Item.Host := 'localhost';
            Item.IsSuperUser := Qry.FieldByName('rolsuper').AsBoolean;
            Item.CanLogin := Qry.FieldByName('rolcanlogin').AsBoolean;
            Item.ExpireDate := Qry.FieldByName('rolvaliduntil').AsString;
            AList.Add(Item);
            Qry.Next;
          end;
        end;

        dtFirebird:
        begin
          Qry.SQL.Text :=
            'SELECT DISTINCT TRIM(RDB$USER) AS USR ' +
            'FROM RDB$USER_PRIVILEGES ' +
            'WHERE RDB$USER_TYPE = 8 ' +
            'ORDER BY 1;';
          Qry.Open;
          while not Qry.EOF do
          begin
            Item := TDBUserInfo.Create;
            Item.Username := Qry.FieldByName('USR').AsString;
            Item.Host := 'localhost';
            Item.IsSuperUser := (UpperCase(Item.Username) = 'SYSDBA');
            Item.CanLogin := True;
            AList.Add(Item);
            Qry.Next;
          end;
        end;
      end;

      Result := True;
    except
      on E: Exception do
        AError := E.Message;
    end;
  finally
    Qry.Free;
    Conn.Free;
  end;
end;

class function TDBUserManagerService.CreateUser(AProfile: TConnectionProfile; const AUser, AHost, APassword: string; const AIsSuper: Boolean; out AError: string): Boolean;
var
  Conn: TZConnection;
  SQLList: TStringList;
  I: Integer;
begin
  Result := False;
  AError := '';
  Conn := CreateTempConnection(AProfile);
  SQLList := TStringList.Create;
  try
    case AProfile.DriverType of
      dtMySQL, dtMariaDB:
      begin
        SQLList.Add(Format('CREATE USER ''%s''@''%s'' IDENTIFIED BY ''%s'';', [AUser, AHost, APassword]));
        if AIsSuper then
          SQLList.Add(Format('GRANT ALL PRIVILEGES ON *.* TO ''%s''@''%s'' WITH GRANT OPTION;', [AUser, AHost]));
        SQLList.Add('FLUSH PRIVILEGES;');
      end;

      dtPostgreSQL:
      begin
        if AIsSuper then
          SQLList.Add(Format('CREATE ROLE "%s" WITH LOGIN SUPERUSER PASSWORD ''%s'';', [AUser, APassword]))
        else
          SQLList.Add(Format('CREATE ROLE "%s" WITH LOGIN PASSWORD ''%s'';', [AUser, APassword]));
      end;

      dtFirebird:
      begin
        SQLList.Add(Format('CREATE USER %s PASSWORD ''%s'';', [AUser, APassword]));
      end;
    end;

    try
      Conn.Connect;
      for I := 0 to SQLList.Count - 1 do
        Conn.ExecuteDirect(SQLList[I]);
      Result := True;
    except
      on E: Exception do
        AError := E.Message;
    end;
  finally
    SQLList.Free;
    Conn.Free;
  end;
end;

class function TDBUserManagerService.DropUser(AProfile: TConnectionProfile; const AUser, AHost: string; out AError: string): Boolean;
var
  Conn: TZConnection;
  SQLText: string;
begin
  Result := False;
  AError := '';
  Conn := CreateTempConnection(AProfile);
  try
    case AProfile.DriverType of
      dtMySQL, dtMariaDB:
        SQLText := Format('DROP USER ''%s''@''%s'';', [AUser, AHost]);
      dtPostgreSQL:
        SQLText := Format('DROP ROLE "%s";', [AUser]);
      dtFirebird:
        SQLText := Format('DROP USER %s;', [AUser]);
      else
        SQLText := '';
    end;

    try
      Conn.Connect;
      Conn.ExecuteDirect(SQLText);
      Result := True;
    except
      on E: Exception do
        AError := E.Message;
    end;
  finally
    Conn.Free;
  end;
end;

class function TDBUserManagerService.ChangePassword(AProfile: TConnectionProfile; const AUser, AHost, ANewPassword: string; out AError: string): Boolean;
var
  Conn: TZConnection;
  SQLList: TStringList;
  I: Integer;
begin
  Result := False;
  AError := '';
  Conn := CreateTempConnection(AProfile);
  SQLList := TStringList.Create;
  try
    case AProfile.DriverType of
      dtMySQL, dtMariaDB:
      begin
        SQLList.Add(Format('ALTER USER ''%s''@''%s'' IDENTIFIED BY ''%s'';', [AUser, AHost, ANewPassword]));
        SQLList.Add('FLUSH PRIVILEGES;');
      end;
      dtPostgreSQL:
        SQLList.Add(Format('ALTER ROLE "%s" WITH PASSWORD ''%s'';', [AUser, ANewPassword]));
      dtFirebird:
        SQLList.Add(Format('ALTER USER %s PASSWORD ''%s'';', [AUser, ANewPassword]));
    end;

    try
      Conn.Connect;
      for I := 0 to SQLList.Count - 1 do
        Conn.ExecuteDirect(SQLList[I]);
      Result := True;
    except
      on E: Exception do
        AError := E.Message;
    end;
  finally
    SQLList.Free;
    Conn.Free;
  end;
end;

class function TDBUserManagerService.FetchUserGrants(AProfile: TConnectionProfile; const AUser, AHost: string; AGrantsList: TStrings; out AError: string): Boolean;
var
  Conn: TZConnection;
  Qry: TZQuery;
begin
  Result := False;
  AError := '';
  AGrantsList.Clear;

  Conn := CreateTempConnection(AProfile);
  Qry := TZQuery.Create(nil);
  try
    try
      Conn.Connect;
      Qry.Connection := Conn;
      Qry.ParamCheck := False;

      case AProfile.DriverType of
        dtMySQL, dtMariaDB:
        begin
          Qry.SQL.Text := Format('SHOW GRANTS FOR ''%s''@''%s'';', [AUser, AHost]);
          Qry.Open;
          while not Qry.EOF do
          begin
            AGrantsList.Add(Qry.Fields[0].AsString);
            Qry.Next;
          end;
        end;

        dtPostgreSQL:
        begin
          Qry.SQL.Text := Format(
            'SELECT table_schema || ''.'' || table_name AS target_obj, privilege_type ' +
            'FROM information_schema.role_table_grants ' +
            'WHERE grantee = ''%s'' ORDER BY 1, 2;', [AUser]);
          Qry.Open;
          while not Qry.EOF do
          begin
            AGrantsList.Add(Format('GRANT %s ON %s TO "%s";', [
              Qry.FieldByName('privilege_type').AsString,
              Qry.FieldByName('target_obj').AsString,
              AUser
            ]));
            Qry.Next;
          end;
        end;

        dtFirebird:
        begin
          Qry.SQL.Text := Format(
            'SELECT TRIM(RDB$RELATION_NAME) AS TBL, TRIM(RDB$PRIVILEGE) AS PRV ' +
            'FROM RDB$USER_PRIVILEGES ' +
            'WHERE TRIM(RDB$USER) = ''%s'';', [AUser]);
          Qry.Open;
          while not Qry.EOF do
          begin
            AGrantsList.Add(Format('GRANT %s ON %s TO %s;', [
              Qry.FieldByName('PRV').AsString,
              Qry.FieldByName('TBL').AsString,
              AUser
            ]));
            Qry.Next;
          end;
        end;
      end;

      Result := True;
    except
      on E: Exception do
        AError := E.Message;
    end;
  finally
    Qry.Free;
    Conn.Free;
  end;
end;

class function TDBUserManagerService.ApplyPrivileges(AProfile: TConnectionProfile; const AUser, AHost, ADBTarget: string; const APrivileges: TStrings; const AIsGrant: Boolean; const AWithGrantOption: Boolean; out AError: string): Boolean;
var
  Conn: TZConnection;
  PrivsJoined, TargetObj, SQLCmd: string;
  I: Integer;
begin
  Result := False;
  AError := '';

  if APrivileges.Count = 0 then
  begin
    AError := 'Pilih minimal satu hak akses (privilege).';
    Exit;
  end;

  PrivsJoined := '';
  for I := 0 to APrivileges.Count - 1 do
  begin
    if I > 0 then PrivsJoined := PrivsJoined + ', ';
    PrivsJoined := PrivsJoined + APrivileges[I];
  end;

  Conn := CreateTempConnection(AProfile);
  try
    case AProfile.DriverType of
      dtMySQL, dtMariaDB:
      begin
        if ADBTarget = '' then TargetObj := '*.*'
        else TargetObj := ADBTarget + '.*';

        if AIsGrant then
        begin
          SQLCmd := Format('GRANT %s ON %s TO ''%s''@''%s''', [PrivsJoined, TargetObj, AUser, AHost]);
          if AWithGrantOption then
            SQLCmd := SQLCmd + ' WITH GRANT OPTION; '
          else
            SQLCmd := SQLCmd + '; ';
        end
        else
          SQLCmd := Format('REVOKE %s ON %s FROM ''%s''@''%s'';', [PrivsJoined, TargetObj, AUser, AHost]);

        SQLCmd := SQLCmd + 'FLUSH PRIVILEGES;';
      end;

      dtPostgreSQL:
      begin
        if ADBTarget = '' then TargetObj := 'ALL TABLES IN SCHEMA public'
        else TargetObj := 'ALL TABLES IN SCHEMA ' + ADBTarget;

        if AIsGrant then
        begin
          SQLCmd := Format('GRANT %s ON %s TO "%s"', [PrivsJoined, TargetObj, AUser]);
          if AWithGrantOption then
            SQLCmd := SQLCmd + ' WITH GRANT OPTION;'
          else
            SQLCmd := SQLCmd + ';';
        end
        else
          SQLCmd := Format('REVOKE %s ON %s FROM "%s";', [PrivsJoined, TargetObj, AUser]);
      end;

      dtFirebird:
      begin
        TargetObj := ADBTarget;
        if TargetObj = '' then TargetObj := 'RDB$DATABASE';

        if AIsGrant then
          SQLCmd := Format('GRANT %s ON %s TO %s;', [PrivsJoined, TargetObj, AUser])
        else
          SQLCmd := Format('REVOKE %s ON %s FROM %s;', [PrivsJoined, TargetObj, AUser]);
      end;
    end;

    try
      Conn.Connect;
      Conn.ExecuteDirect(SQLCmd);
      Result := True;
    except
      on E: Exception do
        AError := E.Message;
    end;
  finally
    Conn.Free;
  end;
end;

end.
