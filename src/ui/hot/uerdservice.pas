unit uERDService;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Graphics,
  uAppTypes, uDBTypes, uModelConnection, uDBDriverBase, uDBConnectionFactory,
  uModelSchemaObject, uERDModel;

type
  { TERDService }
  TERDService = class
  public
    class function BuildGraph(AProfile: TConnectionProfile; const ASchema: string; ACanvas: Graphics.TCanvas; out AGraph: TERDGraph; out AError: string): Boolean;
  end;

implementation

class function TERDService.BuildGraph(AProfile: TConnectionProfile; const ASchema: string; ACanvas: Graphics.TCanvas; out AGraph: TERDGraph; out AError: string): Boolean;
var
  Driver: TDBDriverBase;
  TableList: TSchemaObjectList;
  ColList: TSchemaColumnList;
  FKList: TSchemaForeignKeyList;
  I, J, K: Integer;
  TblObj: TSchemaObject;
  ColObj: TSchemaColumn;
  FKObj: TSchemaForeignKey;
  Node: TERDTableNode;
  TargetSchema: string;
begin
  Result := False;
  AError := '';
  AGraph := TERDGraph.Create;

  Driver := nil;
  TableList := TSchemaObjectList.Create;
  ColList := TSchemaColumnList.Create;
  FKList := TSchemaForeignKeyList.Create;
  try
    try
      Driver := TDBConnectionFactory.CreateDriver(AProfile);
      Driver.Connect;

      TargetSchema := ASchema;
      if TargetSchema = '' then
      begin
        case AProfile.DriverType of
          dtPostgreSQL: TargetSchema := 'public';
          dtSQLite: TargetSchema := 'main';
          else TargetSchema := AProfile.DatabaseName;
        end;
      end;

      // 1. Ambil seluruh tabel
      Driver.ExtractTables(AProfile.DatabaseName, TargetSchema, TableList);

      for I := 0 to TableList.Count - 1 do
      begin
        TblObj := TableList[I];
        Node := AGraph.AddNode(TblObj.Name, TargetSchema);

        // 2. Ambil kolom tiap tabel
        ColList.Clear;
        Driver.ExtractColumns(AProfile.DatabaseName, TargetSchema, TblObj.Name, ColList);
        for J := 0 to ColList.Count - 1 do
        begin
          ColObj := ColList[J];
          Node.AddColumn(ColObj.Name, ColObj.DataType, ColObj.IsPrimaryKey, False);
        end;

        // 3. Ambil Foreign Key relasi
        FKList.Clear;
        Driver.ExtractForeignKeys(AProfile.DatabaseName, TargetSchema, TblObj.Name, FKList);
        for J := 0 to FKList.Count - 1 do
        begin
          FKObj := FKList[J];
          for K := 0 to FKObj.ColumnNames.Count - 1 do
          begin
            AGraph.AddRelation(
              FKObj.Name,
              TblObj.Name,
              FKObj.ColumnNames[K],
              FKObj.RefTableName,
              FKObj.RefColumnNames[K]
            );
          end;
        end;
      end;

      AGraph.ResolveRelationNodes;
      AGraph.AutoLayout(1100, ACanvas);
      Result := True;
    except
      on E: Exception do
        AError := E.Message;
    end;
  finally
    TableList.Free;
    ColList.Free;
    FKList.Free;
    if Assigned(Driver) then
      Driver.Free;
  end;
end;

end.
