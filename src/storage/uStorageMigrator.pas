unit uStorageMigrator;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, ZConnection, ZDataset, ZSqlProcessor,
  uAppConst, uStorageMigrations;

type
  { TStorageMigrator }
  TStorageMigrator = class
  public
    class function GetSchemaVersion(AConnection: TZConnection): Integer;
    class procedure SetSchemaVersion(AConnection: TZConnection; const AVersion: Integer);
    class function RunMigrations(AConnection: TZConnection): Boolean;
  end;

implementation

{ TStorageMigrator }

class function TStorageMigrator.GetSchemaVersion(AConnection: TZConnection): Integer;
var
  Qry: TZQuery;
begin
  Result := 0;
  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := AConnection;
    Qry.SQL.Text := 'PRAGMA user_version;';
    Qry.Open;
    if not Qry.IsEmpty then
      Result := Qry.Fields[0].AsInteger;
    Qry.Close;
  finally
    Qry.Free;
  end;
end;

class procedure TStorageMigrator.SetSchemaVersion(AConnection: TZConnection; const AVersion: Integer);
begin
  AConnection.ExecuteDirect(Format('PRAGMA user_version = %d;', [AVersion]));
end;

class function TStorageMigrator.RunMigrations(AConnection: TZConnection): Boolean;
var
  CurrentVer: Integer;
  Migrations: TMigrationStepArray;
  I: Integer;
  Processor: TZSQLProcessor;
begin
  Result := True;
  CurrentVer := GetSchemaVersion(AConnection);
  Migrations := GetAvailableMigrations;

  if CurrentVer >= CURRENT_STORAGE_SCHEMA_VERSION then
    Exit;

  Processor := TZSQLProcessor.Create(nil);
  try
    Processor.Connection := AConnection;
    for I := 0 to High(Migrations) do
    begin
      if Migrations[I].Version > CurrentVer then
      begin
        AConnection.StartTransaction;
        try
          Processor.Script.Text := Migrations[I].SQLScript;
          Processor.Execute;
          SetSchemaVersion(AConnection, Migrations[I].Version);
          AConnection.Commit;
        except
          on E: Exception do
          begin
            if AConnection.InTransaction then
              AConnection.Rollback;
            Result := False;
            raise Exception.CreateFmt('Migration failed at v%d: %s', [Migrations[I].Version, E.Message]);
          end;
        end;
      end;
    end;
  finally
    Processor.Free;
  end;
end;

end.

