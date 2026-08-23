unit uDBProcessManagerService;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  ZConnection, ZDataset,
  uAppTypes, uDBTypes, uModelConnection;

type
  { TDBProcessInfo }
  TDBProcessInfo = class
  public
    PID: Int64;
    User: string;
    Host: string;
    DatabaseName: string;
    Command: string;
    TimeSec: Integer;
    State: string;
    QuerySQL: string;
  end;

  { TDBProcessManagerService }
  TDBProcessManagerService = class
  private
    class function CreateTempConnection(AProfile: TConnectionProfile): TZConnection;
  public
    class function FetchProcesses(AProfile: TConnectionProfile; AList: TList; out AError: string): Boolean;
    class function TerminateProcess(AProfile: TConnectionProfile; const APID: Int64; const AOnlyCancelQuery: Boolean; out AError: string): Boolean;
  end;

implementation

{ TDBProcessManagerService }

class function TDBProcessManagerService.CreateTempConnection(AProfile: TConnectionProfile): TZConnection;
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

class function TDBProcessManagerService.FetchProcesses(AProfile: TConnectionProfile; AList: TList; out AError: string): Boolean;
var
  Conn: TZConnection;
  Qry: TZQuery;
  Item: TDBProcessInfo;
begin
  Result := False;
  AError := '';

  if AProfile.DriverType = dtSQLite then
  begin
    AError := 'SQLite bekerja dalam mode single-process / file-based lokal sehingga tidak memiliki process list server.';
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
          Qry.SQL.Text := 'SHOW FULL PROCESSLIST;';
          Qry.Open;
          while not Qry.EOF do
          begin
            Item := TDBProcessInfo.Create;
            Item.PID := Qry.FieldByName('Id').AsLargeInt;
            Item.User := Qry.FieldByName('User').AsString;
            Item.Host := Qry.FieldByName('Host').AsString;
            Item.DatabaseName := Qry.FieldByName('db').AsString;
            Item.Command := Qry.FieldByName('Command').AsString;
            Item.TimeSec := Qry.FieldByName('Time').AsInteger;
            Item.State := Qry.FieldByName('State').AsString;
            Item.QuerySQL := Qry.FieldByName('Info').AsString;
            AList.Add(Item);
            Qry.Next;
          end;
        end;

        dtPostgreSQL:
        begin
          Qry.SQL.Text :=
            'SELECT pid, usename, COALESCE(client_addr::text, ''local'') || '':'' || COALESCE(client_port::text, '''') AS host, ' +
            '       datname, state, ' +
            '       COALESCE(EXTRACT(EPOCH FROM (clock_timestamp() - query_start))::integer, 0) AS duration, ' +
            '       query ' +
            'FROM pg_stat_activity ' +
            'WHERE pid <> pg_backend_pid() ' +
            'ORDER BY duration DESC;';
          Qry.Open;
          while not Qry.EOF do
          begin
            Item := TDBProcessInfo.Create;
            Item.PID := Qry.FieldByName('pid').AsLargeInt;
            Item.User := Qry.FieldByName('usename').AsString;
            Item.Host := Qry.FieldByName('host').AsString;
            Item.DatabaseName := Qry.FieldByName('datname').AsString;
            Item.Command := 'QUERY';
            Item.TimeSec := Qry.FieldByName('duration').AsInteger;
            Item.State := Qry.FieldByName('state').AsString;
            Item.QuerySQL := Qry.FieldByName('query').AsString;
            AList.Add(Item);
            Qry.Next;
          end;
        end;

        dtFirebird:
        begin
          Qry.SQL.Text :=
            'SELECT a.MON$ATTACHMENT_ID AS PID, a.MON$USER AS USR, a.MON$REMOTE_ADDRESS AS HOST, ' +
            '       s.MON$SQL_TEXT AS SQL_TXT ' +
            'FROM MON$ATTACHMENTS a ' +
            'LEFT JOIN MON$STATEMENTS s ON a.MON$ATTACHMENT_ID = s.MON$ATTACHMENT_ID ' +
            'WHERE a.MON$ATTACHMENT_ID <> CURRENT_CONNECTION;';
          Qry.Open;
          while not Qry.EOF do
          begin
            Item := TDBProcessInfo.Create;
            Item.PID := Qry.FieldByName('PID').AsLargeInt;
            Item.User := Trim(Qry.FieldByName('USR').AsString);
            Item.Host := Trim(Qry.FieldByName('HOST').AsString);
            Item.DatabaseName := AProfile.DatabaseName;
            Item.Command := 'ATTACHMENT';
            Item.TimeSec := 0;
            Item.State := 'ACTIVE';
            Item.QuerySQL := Qry.FieldByName('SQL_TXT').AsString;
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

class function TDBProcessManagerService.TerminateProcess(AProfile: TConnectionProfile; const APID: Int64; const AOnlyCancelQuery: Boolean; out AError: string): Boolean;
var
  Conn: TZConnection;
  SQLCmd: string;
begin
  Result := False;
  AError := '';

  Conn := CreateTempConnection(AProfile);
  try
    case AProfile.DriverType of
      dtMySQL, dtMariaDB:
      begin
        if AOnlyCancelQuery then
          SQLCmd := Format('KILL QUERY %d;', [APID])
        else
          SQLCmd := Format('KILL CONNECTION %d;', [APID]);
      end;

      dtPostgreSQL:
      begin
        if AOnlyCancelQuery then
          SQLCmd := Format('SELECT pg_cancel_backend(%d);', [APID])
        else
          SQLCmd := Format('SELECT pg_terminate_backend(%d);', [APID]);
      end;

      dtFirebird:
      begin
        if AOnlyCancelQuery then
          SQLCmd := Format('DELETE FROM MON$STATEMENTS WHERE MON$ATTACHMENT_ID = %d;', [APID])
        else
          SQLCmd := Format('DELETE FROM MON$ATTACHMENTS WHERE MON$ATTACHMENT_ID = %d;', [APID]);
      end;
      else
        SQLCmd := '';
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
