unit uDriverMariaDB;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  ZConnection, ZDataset,
  uAppTypes, uDBTypes, uDBDriverBase, uDriverMySQL,
  uModelConnection, uModelSchemaObject;

type
  { TDriverMariaDB }
  TDriverMariaDB = class(TDriverMySQL)
  protected
    procedure ConfigureConnection; override;
  public
    function GetDriverType: TDBDriverType; override;
    function GetCapabilities: TDBCapabilities; override;
    function GetServerInfo: TDBServerInfo; override;

    // Ekstraksi Metadata Khusus MariaDB (Sequences 10.3+)
    procedure ExtractSequences(const ADBName, ASchema: string; AList: TSchemaObjectList); override;
  end;

implementation

{ TDriverMariaDB }

procedure TDriverMariaDB.ConfigureConnection;
begin
  inherited ConfigureConnection;
  if not Assigned(FProfile) then Exit;

  FConnection.Protocol := 'mariadb';

  if FProfile.Port = 0 then
    FConnection.Port := 3306;

  if FProfile.Charset <> '' then
    FConnection.Properties.Values['codepage'] := FProfile.Charset
  else
    FConnection.Properties.Values['codepage'] := 'utf8mb4';
end;

function TDriverMariaDB.GetDriverType: TDBDriverType;
begin
  Result := dtMariaDB;
end;

function TDriverMariaDB.GetCapabilities: TDBCapabilities;
begin
  // MariaDB mendukung seluruh kapabilitas dasar MySQL ditambah Sequence (MariaDB >= 10.3)
  Result := inherited GetCapabilities + [dbcSequences];
end;

function TDriverMariaDB.GetServerInfo: TDBServerInfo;
var
  Qry: TZQuery;
  VerStr: string;
  Parts: TStringArray;
begin
  Result := inherited GetServerInfo;
  Result.ProductName := 'MariaDB';

  if IsConnected then
  begin
    Qry := TZQuery.Create(nil);
    try
      Qry.Connection := FConnection;
      Qry.SQL.Text := 'SELECT VERSION() AS ver, DATABASE() AS cur_db, USER() AS cur_usr, @@character_set_database AS cur_charset;';
      Qry.Open;
      if not Qry.IsEmpty then
      begin
        VerStr := Qry.FieldByName('ver').AsString;
        Result.ServerVersion := VerStr;
        Result.CurrentDatabase := Qry.FieldByName('cur_db').AsString;
        Result.CurrentUser := Qry.FieldByName('cur_usr').AsString;
        Result.DefaultCharset := Qry.FieldByName('cur_charset').AsString;

        // Ekstraksi versi numerik spesifik MariaDB (format umum: 10.x.x-MariaDB...)
        VerStr := StringReplace(VerStr, '-MariaDB', '', [rfIgnoreCase]);
        Parts := VerStr.Split(['.', '-', '+']);
        if Length(Parts) > 0 then Result.VersionMajor := StrToIntDef(Parts[0], 10);
        if Length(Parts) > 1 then Result.VersionMinor := StrToIntDef(Parts[1], 5);
        if Length(Parts) > 2 then Result.VersionRelease := StrToIntDef(Parts[2], 0);
      end;
      Qry.Close;
    finally
      Qry.Free;
    end;
  end;

  FServerInfo := Result;
end;

procedure TDriverMariaDB.ExtractSequences(const ADBName, ASchema: string; AList: TSchemaObjectList);
var
  Qry: TZQuery;
  Item: TSchemaObject;
  TargetDB: string;
begin
  AList.Clear;
  Connect;
  TargetDB := ResolveDatabase(ADBName);

  // Sequences didukung pada MariaDB 10.3 ke atas
  if (FServerInfo.VersionMajor > 10) or ((FServerInfo.VersionMajor = 10) and (FServerInfo.VersionMinor >= 3)) then
  begin
    Qry := TZQuery.Create(nil);
    try
      Qry.Connection := FConnection;
      Qry.SQL.Text :=
        'SELECT TABLE_NAME, TABLE_COMMENT ' +
        'FROM information_schema.TABLES ' +
        'WHERE TABLE_SCHEMA = :db AND TABLE_TYPE = ''SEQUENCE'' ' +
        'ORDER BY TABLE_NAME;';
      Qry.ParamByName('db').AsString := TargetDB;
      Qry.Open;

      while not Qry.EOF do
      begin
        Item := TSchemaObject.Create;
        Item.Name := Qry.FieldByName('TABLE_NAME').AsString;
        Item.DatabaseName := TargetDB;
        Item.ObjectType := sotSequence;
        Item.Comment := Qry.FieldByName('TABLE_COMMENT').AsString;
        AList.Add(Item);
        Qry.Next;
      end;
    finally
      Qry.Free;
    end;
  end;
end;

end.

