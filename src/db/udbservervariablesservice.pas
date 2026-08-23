unit uDBServerVariablesService;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  ZConnection, ZDataset,
  uAppTypes, uDBTypes, uModelConnection;

type
  { TDBServerVariable }
  TDBServerVariable = class
  public
    Name: string;
    Value: string;
    UnitType: string;
    Category: string;
    Description: string;
  end;

  { TDBServerVariablesService }
  TDBServerVariablesService = class
  private
    class function CreateTempConnection(AProfile: TConnectionProfile): TZConnection;
  public
    class function FetchVariables(AProfile: TConnectionProfile; const AIsStatusOnly: Boolean; AList: TList; out AError: string): Boolean;
  end;

implementation

{ TDBServerVariablesService }

class function TDBServerVariablesService.CreateTempConnection(AProfile: TConnectionProfile): TZConnection;
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

class function TDBServerVariablesService.FetchVariables(AProfile: TConnectionProfile; const AIsStatusOnly: Boolean; AList: TList; out AError: string): Boolean;
var
  Conn: TZConnection;
  Qry: TZQuery;
  Item: TDBServerVariable;
  PragmaList: array[0..11] of string = (
    'encoding', 'journal_mode', 'page_size', 'cache_size',
    'synchronous', 'foreign_keys', 'wal_autocheckpoint',
    'user_version', 'auto_vacuum', 'locking_mode', 'busy_timeout', 'schema_version'
  );
  I: Integer;
begin
  Result := False;
  AError := '';

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
          if AIsStatusOnly then
            Qry.SQL.Text := 'SHOW GLOBAL STATUS;'
          else
            Qry.SQL.Text := 'SHOW GLOBAL VARIABLES;';

          Qry.Open;
          while not Qry.EOF do
          begin
            Item := TDBServerVariable.Create;
            Item.Name := Qry.Fields[0].AsString;
            Item.Value := Qry.Fields[1].AsString;
            Item.UnitType := '';
            Item.Category := 'General';
            Item.Description := '';
            AList.Add(Item);
            Qry.Next;
          end;
        end;

        dtPostgreSQL:
        begin
          Qry.SQL.Text :=
            'SELECT name, setting, COALESCE(unit, '''') AS unit_str, ' +
            '       category, COALESCE(short_desc, '''') AS desc_str ' +
            'FROM pg_settings ' +
            'ORDER BY category, name;';
          Qry.Open;
          while not Qry.EOF do
          begin
            Item := TDBServerVariable.Create;
            Item.Name := Qry.FieldByName('name').AsString;
            Item.Value := Qry.FieldByName('setting').AsString;
            Item.UnitType := Qry.FieldByName('unit_str').AsString;
            Item.Category := Qry.FieldByName('category').AsString;
            Item.Description := Qry.FieldByName('desc_str').AsString;
            AList.Add(Item);
            Qry.Next;
          end;
        end;

        dtSQLite:
        begin
          // Compile options
          Qry.SQL.Text := 'PRAGMA compile_options;';
          try
            Qry.Open;
            while not Qry.EOF do
            begin
              Item := TDBServerVariable.Create;
              Item.Name := 'compile_option: ' + Qry.Fields[0].AsString;
              Item.Value := 'ENABLED';
              Item.Category := 'Build & Compiler';
              AList.Add(Item);
              Qry.Next;
            end;
            Qry.Close;
          except
          end;

          // Pragma Runtime Configurations
          for I := Low(PragmaList) to High(PragmaList) do
          begin
            try
              Qry.SQL.Text := Format('PRAGMA %s;', [PragmaList[I]]);
              Qry.Open;
              if not Qry.IsEmpty then
              begin
                Item := TDBServerVariable.Create;
                Item.Name := PragmaList[I];
                Item.Value := Qry.Fields[0].AsString;
                Item.Category := 'Runtime Pragma';
                AList.Add(Item);
              end;
              Qry.Close;
            except
            end;
          end;
        end;

        dtFirebird:
        begin
          Qry.SQL.Text :=
            'SELECT MON$DATABASE_NAME AS DB, MON$PAGE_SIZE AS PG_SIZE, ' +
            '       MON$ODS_MAJOR || ''.'' || MON$ODS_MINOR AS ODS_VER, ' +
            '       MON$PAGE_BUFFERS AS BUFFERS, MON$SQL_DIALECT AS DIALECT ' +
            'FROM MON$DATABASE;';
          Qry.Open;
          if not Qry.IsEmpty then
          begin
            Item := TDBServerVariable.Create;
            Item.Name := 'Database Name';
            Item.Value := Trim(Qry.FieldByName('DB').AsString);
            Item.Category := 'Database Info';
            AList.Add(Item);

            Item := TDBServerVariable.Create;
            Item.Name := 'Page Size';
            Item.Value := Qry.FieldByName('PG_SIZE').AsString;
            Item.UnitType := 'Bytes';
            Item.Category := 'Storage';
            AList.Add(Item);

            Item := TDBServerVariable.Create;
            Item.Name := 'ODS Version';
            Item.Value := Qry.FieldByName('ODS_VER').AsString;
            Item.Category := 'Engine';
            AList.Add(Item);

            Item := TDBServerVariable.Create;
            Item.Name := 'Page Buffers';
            Item.Value := Qry.FieldByName('BUFFERS').AsString;
            Item.Category := 'Memory';
            AList.Add(Item);

            Item := TDBServerVariable.Create;
            Item.Name := 'SQL Dialect';
            Item.Value := Qry.FieldByName('DIALECT').AsString;
            Item.Category := 'Engine';
            AList.Add(Item);
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

end.
