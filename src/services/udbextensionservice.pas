unit uDBExtensionService;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Contnrs,
  ZConnection, ZDataset, DB,
  uAppTypes, uDBTypes, uModelConnection;

type
  { TExtensionInfo }
  TExtensionInfo = class
  public
    Name: string;
    Version: string;
    Installed: Boolean;
    Description: string;
    LibraryFile: string;
    Status: string;
  end;

  { TExtensionInfoList }
  TExtensionInfoList = class(TObjectList)
  private
    function GetItem(AIndex: Integer): TExtensionInfo;
  public
    property Items[AIndex: Integer]: TExtensionInfo read GetItem; default;
  end;

  { TDBExtensionService }
  TDBExtensionService = class
  private
    class function CreateTempConnection(AProfile: TConnectionProfile; const ADBName: string): TZConnection;
  public
    class function FetchExtensions(AProfile: TConnectionProfile; const ADBName: string;
      AList: TExtensionInfoList; out AErrorMsg: string): Boolean;
    class function LoadOrInstallExtension(AProfile: TConnectionProfile; const ADBName: string;
      const AExtName, ALibPath: string; out AErrorMsg: string): Boolean;
    class function UnloadOrDropExtension(AProfile: TConnectionProfile; const ADBName: string;
      const AExtName: string; out AErrorMsg: string): Boolean;
  end;

implementation

{ TExtensionInfoList }

function TExtensionInfoList.GetItem(AIndex: Integer): TExtensionInfo;
begin
  Result := TExtensionInfo(inherited Items[AIndex]);
end;

{ TDBExtensionService }

class function TDBExtensionService.CreateTempConnection(AProfile: TConnectionProfile; const ADBName: string): TZConnection;
begin
  Result := TZConnection.Create(nil);
  case AProfile.DriverType of
    dtMySQL: Result.Protocol := 'mysql';
    dtMariaDB: Result.Protocol := 'mariadb';
    dtPostgreSQL: Result.Protocol := 'postgresql';
    dtSQLite: Result.Protocol := 'sqlite';
    dtFirebird: Result.Protocol := 'firebird';
  end;
  Result.HostName := AProfile.Host;
  Result.Port := AProfile.Port;
  if ADBName <> '' then
    Result.Database := ADBName
  else
    Result.Database := AProfile.DatabaseName;
  Result.User := AProfile.Username;
  Result.Password := AProfile.Password;
  Result.AutoCommit := True;
end;

class function TDBExtensionService.FetchExtensions(AProfile: TConnectionProfile; const ADBName: string;
  AList: TExtensionInfoList; out AErrorMsg: string): Boolean;
var
  Conn: TZConnection;
  Qry: TZQuery;
  Item: TExtensionInfo;
  SQL: string;
begin
  Result := False;
  AErrorMsg := '';
  AList.Clear;

  Conn := CreateTempConnection(AProfile, ADBName);
  Qry := TZQuery.Create(nil);
  try
    try
      Conn.Connect;
      Qry.Connection := Conn;

      case AProfile.DriverType of
        dtPostgreSQL:
        begin
          SQL :=
            'SELECT a.name, a.default_version, e.extversion AS installed_version, ' +
            '       a.comment, (e.extname IS NOT NULL) AS is_installed ' +
            'FROM pg_available_extensions a ' +
            'LEFT JOIN pg_extension e ON a.name = e.extname ' +
            'ORDER BY is_installed DESC, a.name ASC;';
          Qry.SQL.Text := SQL;
          Qry.Open;

          while not Qry.EOF do
          begin
            Item := TExtensionInfo.Create;
            Item.Name := Qry.FieldByName('name').AsString;
            Item.Version := Qry.FieldByName('default_version').AsString;
            Item.Installed := Qry.FieldByName('is_installed').AsBoolean;
            Item.Description := Qry.FieldByName('comment').AsString;
            if Item.Installed then
            begin
              Item.Status := 'Aktif (' + Qry.FieldByName('installed_version').AsString + ')';
            end
            else
              Item.Status := 'Tersedia';
            AList.Add(Item);
            Qry.Next;
          end;
        end;

        dtMySQL, dtMariaDB:
        begin
          SQL :=
            'SELECT PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_STATUS, PLUGIN_TYPE, ' +
            '       PLUGIN_LIBRARY, PLUGIN_DESCRIPTION ' +
            'FROM information_schema.PLUGINS ' +
            'ORDER BY PLUGIN_STATUS DESC, PLUGIN_NAME ASC;';
          Qry.SQL.Text := SQL;
          Qry.Open;

          while not Qry.EOF do
          begin
            Item := TExtensionInfo.Create;
            Item.Name := Qry.FieldByName('PLUGIN_NAME').AsString;
            Item.Version := Qry.FieldByName('PLUGIN_VERSION').AsString;
            Item.Status := Qry.FieldByName('PLUGIN_STATUS').AsString;
            Item.Installed := SameText(Item.Status, 'ACTIVE');
            Item.LibraryFile := Qry.FieldByName('PLUGIN_LIBRARY').AsString;
            Item.Description := Qry.FieldByName('PLUGIN_TYPE').AsString;
            AList.Add(Item);
            Qry.Next;
          end;
        end;

        dtSQLite:
        begin
          // SQLite bersifat dinamis per-koneksi
          Item := TExtensionInfo.Create;
          Item.Name := 'SQLite Dynamic Extension Loader';
          Item.Version := 'Runtime Module';
          Item.Installed := True;
          Item.Status := 'Siap Load (*.dll / *.so)';
          Item.Description := 'Memuat berkas library ekstensi pihak ketiga (Spatialite, Vector, dll.)';
          AList.Add(Item);
        end;
      end;

      Result := True;
    except
      on E: Exception do
        AErrorMsg := E.Message;
    end;
  finally
    Qry.Free;
    Conn.Free;
  end;
end;

class function TDBExtensionService.LoadOrInstallExtension(AProfile: TConnectionProfile; const ADBName: string;
  const AExtName, ALibPath: string; out AErrorMsg: string): Boolean;
var
  Conn: TZConnection;
  SQL: string;
begin
  Result := False;
  AErrorMsg := '';

  Conn := CreateTempConnection(AProfile, ADBName);
  try
    try
      Conn.Connect;
      case AProfile.DriverType of
        dtPostgreSQL:
          SQL := Format('CREATE EXTENSION IF NOT EXISTS "%s";', [AExtName]);

        dtMySQL, dtMariaDB:
        begin
          if ALibPath <> '' then
            SQL := Format('INSTALL PLUGIN %s SONAME ''%s'';', [AExtName, ALibPath])
          else if AProfile.DriverType = dtMariaDB then
            SQL := Format('INSTALL SONAME ''%s'';', [AExtName])
          else
            SQL := Format('INSTALL COMPONENT ''file://%s'';', [AExtName]);
        end;

        dtSQLite:
        begin
          // Mengaktifkan pemuatan ekstensi di SQLite
          SQL := Format('SELECT load_extension(''%s'');', [StringReplace(ALibPath, '\', '/', [rfReplaceAll])]);
        end;
        else
          raise Exception.Create('Mesin DBMS ini tidak mendukung pemuatan ekstensi dinamis.');
      end;

      Conn.ExecuteDirect(SQL);
      Result := True;
    except
      on E: Exception do
        AErrorMsg := E.Message;
    end;
  finally
    Conn.Free;
  end;
end;

class function TDBExtensionService.UnloadOrDropExtension(AProfile: TConnectionProfile; const ADBName: string;
  const AExtName: string; out AErrorMsg: string): Boolean;
var
  Conn: TZConnection;
  SQL: string;
begin
  Result := False;
  AErrorMsg := '';

  Conn := CreateTempConnection(AProfile, ADBName);
  try
    try
      Conn.Connect;
      case AProfile.DriverType of
        dtPostgreSQL:
          SQL := Format('DROP EXTENSION IF EXISTS "%s" CASCADE;', [AExtName]);

        dtMySQL, dtMariaDB:
          SQL := Format('UNINSTALL PLUGIN %s;', [AExtName]);

        dtSQLite:
          raise Exception.Create('Ekstensi SQLite terikat pada memori sesi dan otomatis dilepas saat koneksi ditutup.');
        else
          raise Exception.Create('Operasi pencabutan ekstensi tidak didukung pada DBMS ini.');
      end;

      Conn.ExecuteDirect(SQL);
      Result := True;
    except
      on E: Exception do
        AErrorMsg := E.Message;
    end;
  finally
    Conn.Free;
  end;
end;

end.
