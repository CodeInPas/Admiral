unit uSchemaDiffEngine;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils, Math,
  uAppTypes, uDBTypes, uModelConnection, uDBDriverBase, uDBConnectionFactory,
  uModelSchemaObject;

type
  { Tipe Objek Skema }
  TDiffObjectType = (dotTable, dotColumn, dotIndex, dotForeignKey);

  { Tipe Aksi Perbedaan }
  TDiffAction = (daNone, daCreate, daDrop, daAlter);

  { Representasi Item Perbedaan }
  TSchemaDiffItem = class
  public
    ObjType: TDiffObjectType;
    Action: TDiffAction;
    ParentTableName: string;
    ObjectName: string;
    Details: string;
    SyncSQL: string;
    IsSelected: Boolean;
    constructor Create;
  end;

  { TSchemaDiffEngine }
  TSchemaDiffEngine = class
  private
    class function QuoteId(const AName: string; const ADriver: TDBDriverType): string;
    class function NormalizeType(const AType: string): string;
  public
    class function CompareSchemas(
      ASourceProfile, ATargetProfile: TConnectionProfile;
      ADiffList: TList; // List of TSchemaDiffItem
      out AError: string
    ): Boolean;
    class function GenerateSyncScript(
      ADiffList: TList;
      const ADriverType: TDBDriverType
    ): string;
  end;

implementation

{ TSchemaDiffItem }

constructor TSchemaDiffItem.Create;
begin
  inherited Create;
  ObjType := dotTable;
  Action := daNone;
  ParentTableName := '';
  ObjectName := '';
  Details := '';
  SyncSQL := '';
  IsSelected := True;
end;

{ TSchemaDiffEngine }

class function TSchemaDiffEngine.QuoteId(const AName: string; const ADriver: TDBDriverType): string;
begin
  case ADriver of
    dtMySQL, dtMariaDB: Result := '`' + AName + '`';
    else Result := '"' + AName + '"';
  end;
end;

class function TSchemaDiffEngine.NormalizeType(const AType: string): string;
var
  S: string;
begin
  S := UpperCase(Trim(AType));
  S := StringReplace(S, 'INT4', 'INTEGER', [rfReplaceAll]);
  S := StringReplace(S, 'INT8', 'BIGINT', [rfReplaceAll]);
  S := StringReplace(S, 'INT2', 'SMALLINT', [rfReplaceAll]);
  S := StringReplace(S, 'CHARACTER VARYING', 'VARCHAR', [rfReplaceAll]);
  Result := S;
end;

class function TSchemaDiffEngine.CompareSchemas(
  ASourceProfile, ATargetProfile: TConnectionProfile;
  ADiffList: TList;
  out AError: string
): Boolean;
var
  SrcDriver, TgtDriver: TDBDriverBase;
  SrcTables, TgtTables: TSchemaObjectList;
  SrcCols, TgtCols: TSchemaColumnList;
  SrcFKs, TgtFKs: TSchemaForeignKeyList;
  I, J, K: Integer;
  TblName, SQLCreate, ColDef: string;
  SrcCol, TgtCol: TSchemaColumn;
  SrcFK, TgtFK: TSchemaForeignKey;
  DiffItem: TSchemaDiffItem;
  TgtHasTable, ColFound, FKFound: Boolean;
begin
  Result := False;
  AError := '';
  ADiffList.Clear;

  SrcDriver := TDBConnectionFactory.CreateDriver(ASourceProfile);
  TgtDriver := TDBConnectionFactory.CreateDriver(ATargetProfile);

  SrcTables := TSchemaObjectList.Create;
  TgtTables := TSchemaObjectList.Create;
  SrcCols := TSchemaColumnList.Create;
  TgtCols := TSchemaColumnList.Create;
  SrcFKs := TSchemaForeignKeyList.Create;
  TgtFKs := TSchemaForeignKeyList.Create;

  try
    try
      SrcDriver.ExtractTables('', '', SrcTables);
      TgtDriver.ExtractTables('', '', TgtTables);

      // 1. Periksa Tabel di Sumber yang Tidak Ada di Target (CREATE TABLE)
      for I := 0 to SrcTables.Count - 1 do
      begin
        TblName := SrcTables[I].Name;
        TgtHasTable := False;
        for J := 0 to TgtTables.Count - 1 do
        begin
          if SameText(TgtTables[J].Name, TblName) then
          begin
            TgtHasTable := True;
            Break;
          end;
        end;

        if not TgtHasTable then
        begin
          SrcCols.Clear;
          SrcDriver.ExtractColumns('', '', TblName, SrcCols);

          SQLCreate := Format('CREATE TABLE %s (', [QuoteId(TblName, ATargetProfile.DriverType)]);
          for J := 0 to SrcCols.Count - 1 do
          begin
            if J > 0 then SQLCreate := SQLCreate + ', ';
            SQLCreate := SQLCreate + QuoteId(SrcCols[J].Name, ATargetProfile.DriverType) + ' ' + SrcCols[J].DataType;
            if not SrcCols[J].IsNullable then
              SQLCreate := SQLCreate + ' NOT NULL';
            if SrcCols[J].IsPrimaryKey then
              SQLCreate := SQLCreate + ' PRIMARY KEY';
          end;
          SQLCreate := SQLCreate + ');';

          DiffItem := TSchemaDiffItem.Create;
          DiffItem.ObjType := dotTable;
          DiffItem.Action := daCreate;
          DiffItem.ParentTableName := TblName;
          DiffItem.ObjectName := TblName;
          DiffItem.Details := 'Tabel baru ditemukan di database sumber';
          DiffItem.SyncSQL := SQLCreate;
          ADiffList.Add(DiffItem);
        end
        else
        begin
          // 2. Bandingkan Kolom pada Tabel yang Ada di Kedua Database
          SrcCols.Clear;
          TgtCols.Clear;
          SrcDriver.ExtractColumns('', '', TblName, SrcCols);
          TgtDriver.ExtractColumns('', '', TblName, TgtCols);

          // a. Kolom yang ada di Sumber tapi belum ada di Target (ADD COLUMN)
          for J := 0 to SrcCols.Count - 1 do
          begin
            SrcCol := SrcCols[J];
            ColFound := False;
            for K := 0 to TgtCols.Count - 1 do
            begin
              if SameText(TgtCols[K].Name, SrcCol.Name) then
              begin
                ColFound := True;
                Break;
              end;
            end;

            if not ColFound then
            begin
              ColDef := QuoteId(SrcCol.Name, ATargetProfile.DriverType) + ' ' + SrcCol.DataType;
              if not SrcCol.IsNullable then ColDef := ColDef + ' NOT NULL';

              DiffItem := TSchemaDiffItem.Create;
              DiffItem.ObjType := dotColumn;
              DiffItem.Action := daCreate;
              DiffItem.ParentTableName := TblName;
              DiffItem.ObjectName := SrcCol.Name;
              DiffItem.Details := Format('Tambah kolom baru (%s)', [SrcCol.DataType]);
              DiffItem.SyncSQL := Format('ALTER TABLE %s ADD COLUMN %s;', [QuoteId(TblName, ATargetProfile.DriverType), ColDef]);
              ADiffList.Add(DiffItem);
            end;
          end;

          // b. Kolom yang ada di kedua DB tapi berbeda Tipe atau Nullability (MODIFY / ALTER COLUMN)
          for J := 0 to SrcCols.Count - 1 do
          begin
            SrcCol := SrcCols[J];
            for K := 0 to TgtCols.Count - 1 do
            begin
              TgtCol := TgtCols[K];
              if SameText(SrcCol.Name, TgtCol.Name) then
              begin
                if (NormalizeType(SrcCol.DataType) <> NormalizeType(TgtCol.DataType)) or (SrcCol.IsNullable <> TgtCol.IsNullable) then
                begin
                  DiffItem := TSchemaDiffItem.Create;
                  DiffItem.ObjType := dotColumn;
                  DiffItem.Action := daAlter;
                  DiffItem.ParentTableName := TblName;
                  DiffItem.ObjectName := SrcCol.Name;
                  DiffItem.Details := Format('Ubah tipe dari [%s] ke [%s]', [TgtCol.DataType, SrcCol.DataType]);

                  case ATargetProfile.DriverType of
                    dtPostgreSQL:
                      DiffItem.SyncSQL := Format('ALTER TABLE %s ALTER COLUMN %s TYPE %s;', [
                        QuoteId(TblName, ATargetProfile.DriverType),
                        QuoteId(SrcCol.Name, ATargetProfile.DriverType),
                        SrcCol.DataType
                      ]);
                    dtMySQL, dtMariaDB:
                      DiffItem.SyncSQL := Format('ALTER TABLE %s MODIFY COLUMN %s %s;', [
                        QuoteId(TblName, ATargetProfile.DriverType),
                        QuoteId(SrcCol.Name, ATargetProfile.DriverType),
                        SrcCol.DataType
                      ]);
                    else
                      DiffItem.SyncSQL := Format('-- SQLite/Firebird memerlukan penanganan alter tabel khusus untuk %s.%s;', [TblName, SrcCol.Name]);
                  end;

                  ADiffList.Add(DiffItem);
                end;
                Break;
              end;
            end;
          end;

          // c. Kolom yang ada di Target tapi tidak ada di Sumber (DROP COLUMN)
          for J := 0 to TgtCols.Count - 1 do
          begin
            TgtCol := TgtCols[J];
            ColFound := False;
            for K := 0 to SrcCols.Count - 1 do
            begin
              if SameText(SrcCols[K].Name, TgtCol.Name) then
              begin
                ColFound := True;
                Break;
              end;
            end;

            if not ColFound then
            begin
              DiffItem := TSchemaDiffItem.Create;
              DiffItem.ObjType := dotColumn;
              DiffItem.Action := daDrop;
              DiffItem.ParentTableName := TblName;
              DiffItem.ObjectName := TgtCol.Name;
              DiffItem.Details := 'Kolom target tidak lagi ada di sumber (usang)';
              DiffItem.SyncSQL := Format('ALTER TABLE %s DROP COLUMN %s;', [
                QuoteId(TblName, ATargetProfile.DriverType),
                QuoteId(TgtCol.Name, ATargetProfile.DriverType)
              ]);
              ADiffList.Add(DiffItem);
            end;
          end;

          // 3. Periksa Foreign Key Relasi
          SrcFKs.Clear;
          TgtFKs.Clear;
          try
            SrcDriver.ExtractForeignKeys('', '', TblName, SrcFKs);
            TgtDriver.ExtractForeignKeys('', '', TblName, TgtFKs);

            for J := 0 to SrcFKs.Count - 1 do
            begin
              SrcFK := SrcFKs[J];
              FKFound := False;
              for K := 0 to TgtFKs.Count - 1 do
              begin
                if SameText(TgtFKs[K].Name, SrcFK.Name) then
                begin
                  FKFound := True;
                  Break;
                end;
              end;

              if not FKFound and (SrcFK.ColumnNames.Count > 0) and (SrcFK.RefColumnNames.Count > 0) and (SrcFK.RefTableName <> '') then
              begin
                DiffItem := TSchemaDiffItem.Create;
                DiffItem.ObjType := dotForeignKey;
                DiffItem.Action := daCreate;
                DiffItem.ParentTableName := TblName;
                DiffItem.ObjectName := SrcFK.Name;
                DiffItem.Details := Format('Tambah FK -> %s(%s)', [SrcFK.RefTableName, SrcFK.RefColumnNames.CommaText]);
                DiffItem.SyncSQL := Format('ALTER TABLE %s ADD CONSTRAINT %s FOREIGN KEY (%s) REFERENCES %s (%s);', [
                  QuoteId(TblName, ATargetProfile.DriverType),
                  QuoteId(SrcFK.Name, ATargetProfile.DriverType),
                  QuoteId(SrcFK.ColumnNames[0], ATargetProfile.DriverType),
                  QuoteId(SrcFK.RefTableName, ATargetProfile.DriverType),
                  QuoteId(SrcFK.RefColumnNames[0], ATargetProfile.DriverType)
                ]);
                ADiffList.Add(DiffItem);
              end;
            end;
          except
          end;
        end;
      end;

      // 4. Periksa Tabel yang Ada di Target tapi Tidak Ada di Sumber (DROP TABLE)
      for I := 0 to TgtTables.Count - 1 do
      begin
        TblName := TgtTables[I].Name;
        TgtHasTable := False;
        for J := 0 to SrcTables.Count - 1 do
        begin
          if SameText(SrcTables[J].Name, TblName) then
          begin
            TgtHasTable := True;
            Break;
          end;
        end;

        if not TgtHasTable then
        begin
          DiffItem := TSchemaDiffItem.Create;
          DiffItem.ObjType := dotTable;
          DiffItem.Action := daDrop;
          DiffItem.ParentTableName := TblName;
          DiffItem.ObjectName := TblName;
          DiffItem.Details := 'Tabel pada target tidak ada di database sumber';
          DiffItem.SyncSQL := Format('DROP TABLE %s;', [QuoteId(TblName, ATargetProfile.DriverType)]);
          ADiffList.Add(DiffItem);
        end;
      end;

      Result := True;
    except
      on E: Exception do
        AError := E.Message;
    end;
  finally
    SrcFKs.Free;
    TgtFKs.Free;
    SrcCols.Free;
    TgtCols.Free;
    SrcTables.Free;
    TgtTables.Free;
    SrcDriver.Free;
    TgtDriver.Free;
  end;
end;

class function TSchemaDiffEngine.GenerateSyncScript(
  ADiffList: TList;
  const ADriverType: TDBDriverType
): string;
var
  SL: TStringList;
  I: Integer;
  Item: TSchemaDiffItem;
begin
  SL := TStringList.Create;
  try
    SL.Add('-- ========================================================');
    SL.Add('-- Skrip Migrasi Sinkronisasi Skema Database');
    SL.Add('-- Waktu Dibuat: ' + FormatDateTime('YYYY-MM-DD HH:NN:SS', Now));
    SL.Add('-- ========================================================');
    SL.Add('');

    for I := 0 to ADiffList.Count - 1 do
    begin
      Item := TSchemaDiffItem(ADiffList[I]);
      if Item.IsSelected and (Trim(Item.SyncSQL) <> '') then
      begin
        SL.Add(Format('-- [%s] %s (%s)', [
          Item.ParentTableName,
          Item.ObjectName,
          Item.Details
        ]));
        SL.Add(Item.SyncSQL);
        SL.Add('');
      end;
    end;

    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

end.
