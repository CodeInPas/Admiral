unit uModelTableBuilder;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  uAppTypes, uDBTypes;

type
  { Representasi Kolom }
  TBuilderColumn = class
  public
    Name: string;
    DataType: string;
    Length: Integer;
    Precision: Integer;
    Scale: Integer;
    IsNullable: Boolean;
    IsPrimaryKey: Boolean;
    IsAutoIncrement: Boolean;
    IsUnique: Boolean;
    IsUnsigned: Boolean;
    DefaultValue: string;
    Comment: string;
    constructor Create;
  end;

  { Representasi Indeks }
  TBuilderIndex = class
  public
    Name: string;
    IndexType: string; // INDEX, UNIQUE, FULLTEXT
    Columns: TStringList;
    constructor Create;
    destructor Destroy; override;
  end;

  { Representasi Foreign Key }
  TBuilderForeignKey = class
  public
    Name: string;
    Columns: TStringList;
    RefTable: string;
    RefColumns: TStringList;
    OnUpdate: string; // CASCADE, RESTRICT, SET NULL, NO ACTION
    OnDelete: string;
    constructor Create;
    destructor Destroy; override;
  end;

  { TTableBuilderModel }
  TTableBuilderModel = class
  private
    FTablesName: string;
    FSchemaName: string;
    FTableComment: string;
    FEngine: string;
    FCharset: string;
    FColumns: TList;     // List of TBuilderColumn
    FIndexes: TList;     // List of TBuilderIndex
    FForeignKeys: TList; // List of TBuilderForeignKey

    function QuoteId(const AName: string; const ADriver: TDBDriverType): string;
    function FormatColumnType(ACol: TBuilderColumn; const ADriver: TDBDriverType): string;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;
    function AddColumn(const AName, ADataType: string; const ALen: Integer = 0; const APk: Boolean = False): TBuilderColumn;
    function AddIndex(const AName, AType: string): TBuilderIndex;
    function AddForeignKey(const AName, ARefTable: string): TBuilderForeignKey;

    function GenerateDDL(const ADriverType: TDBDriverType): string;

    property TableName: string read FTablesName write FTablesName;
    property SchemaName: string read FSchemaName write FSchemaName;
    property TableComment: string read FTableComment write FTableComment;
    property Engine: string read FEngine write FEngine;
    property Charset: string read FCharset write FCharset;
    property Columns: TList read FColumns;
    property Indexes: TList read FIndexes;
    property ForeignKeys: TList read FForeignKeys;
  end;

implementation

{ TBuilderColumn }

constructor TBuilderColumn.Create;
begin
  inherited Create;
  Length := 0;
  Precision := 0;
  Scale := 0;
  IsNullable := True;
  IsPrimaryKey := False;
  IsAutoIncrement := False;
  IsUnique := False;
  IsUnsigned := False;
  DefaultValue := '';
  Comment := '';
end;

{ TBuilderIndex }

constructor TBuilderIndex.Create;
begin
  inherited Create;
  IndexType := 'INDEX';
  Columns := TStringList.Create;
end;

destructor TBuilderIndex.Destroy;
begin
  Columns.Free;
  //inherited Destroy;
end;

{ TBuilderForeignKey }

constructor TBuilderForeignKey.Create;
begin
  inherited Create;
  Columns := TStringList.Create;
  RefColumns := TStringList.Create;
  OnUpdate := 'NO ACTION';
  OnDelete := 'NO ACTION';
end;

destructor TBuilderForeignKey.Destroy;
begin
  Columns.Free;
  RefColumns.Free;
  //inherited Destroy;
end;

{ TTableBuilderModel }

constructor TTableBuilderModel.Create;
begin
  inherited Create;
  FTablesName := 'tabel_baru';
  FSchemaName := '';
  FTableComment := '';
  FEngine := 'InnoDB';
  FCharset := 'utf8mb4';
  FColumns := TList.Create;
  FIndexes := TList.Create;
  FForeignKeys := TList.Create;
end;

destructor TTableBuilderModel.Destroy;
begin
  Clear;
  FColumns.Free;
  FIndexes.Free;
  FForeignKeys.Free;
  //inherited Destroy;
end;

procedure TTableBuilderModel.Clear;
var
  I: Integer;
begin
  for I := 0 to FColumns.Count - 1 do
    TBuilderColumn(FColumns[I]).Free;
  FColumns.Clear;

  for I := 0 to FIndexes.Count - 1 do
    TBuilderIndex(FIndexes[I]).Free;
  FIndexes.Clear;

  for I := 0 to FForeignKeys.Count - 1 do
    TBuilderForeignKey(FForeignKeys[I]).Free;
  FForeignKeys.Clear;
end;

function TTableBuilderModel.AddColumn(const AName, ADataType: string; const ALen: Integer; const APk: Boolean): TBuilderColumn;
begin
  Result := TBuilderColumn.Create;
  Result.Name := AName;
  Result.DataType := ADataType;
  Result.Length := ALen;
  Result.IsPrimaryKey := APk;
  if APk then Result.IsNullable := False;
  FColumns.Add(Result);
end;

function TTableBuilderModel.AddIndex(const AName, AType: string): TBuilderIndex;
begin
  Result := TBuilderIndex.Create;
  Result.Name := AName;
  Result.IndexType := AType;
  FIndexes.Add(Result);
end;

function TTableBuilderModel.AddForeignKey(const AName, ARefTable: string): TBuilderForeignKey;
begin
  Result := TBuilderForeignKey.Create;
  Result.Name := AName;
  Result.RefTable := ARefTable;
  FForeignKeys.Add(Result);
end;

function TTableBuilderModel.QuoteId(const AName: string; const ADriver: TDBDriverType): string;
begin
  case ADriver of
    dtMySQL, dtMariaDB: Result := '`' + AName + '`';
    else Result := '"' + AName + '"';
  end;
end;

function TTableBuilderModel.FormatColumnType(ACol: TBuilderColumn; const ADriver: TDBDriverType): string;
var
  UData: string;
begin
  UData := UpperCase(Trim(ACol.DataType));

  // Penanganan Khusus SQLite
  if ADriver = dtSQLite then
  begin
    if ACol.IsPrimaryKey and ACol.IsAutoIncrement then
      Exit('INTEGER PRIMARY KEY AUTOINCREMENT');
    if Pos('INT', UData) > 0 then Exit('INTEGER');
    if (Pos('CHAR', UData) > 0) or (Pos('TEXT', UData) > 0) then Exit('TEXT');
    if (Pos('REAL', UData) > 0) or (Pos('FLOAT', UData) > 0) or (Pos('DECIMAL', UData) > 0) then Exit('REAL');
    if Pos('BLOB', UData) > 0 then Exit('BLOB');
    Exit('TEXT');
  end;

  // Penanganan Khusus PostgreSQL
  if ADriver = dtPostgreSQL then
  begin
    if ACol.IsAutoIncrement then
    begin
      if (UData = 'BIGINT') or (UData = 'INT8') then Exit('BIGSERIAL')
      else Exit('SERIAL');
    end;
  end;

  // Penanganan Ukuran & Presisi
  if (ACol.Length > 0) and (Pos('CHAR', UData) > 0) then
    Result := Format('%s(%d)', [UData, ACol.Length])
  else if (ACol.Precision > 0) and ((UData = 'DECIMAL') or (UData = 'NUMERIC')) then
  begin
    if ACol.Scale > 0 then
      Result := Format('%s(%d,%d)', [UData, ACol.Precision, ACol.Scale])
    else
      Result := Format('%s(%d)', [UData, ACol.Precision]);
  end
  else
    Result := UData;

  // Unsigned Flag (MySQL)
  if ACol.IsUnsigned and (ADriver in [dtMySQL, dtMariaDB]) then
    Result := Result + ' UNSIGNED';
end;

function TTableBuilderModel.GenerateDDL(const ADriverType: TDBDriverType): string;
var
  Lines: TStringList;
  I, J: Integer;
  Col: TBuilderColumn;
  Idx: TBuilderIndex;
  FK: TBuilderForeignKey;
  ColLine, PKList, FullTableName, ExtraIdxSQL: string;
  HasInlineAutoPK: Boolean;
begin
  if Trim(FTablesName) = '' then
    Exit('-- Silakan tentukan nama tabel.');

  if FColumns.Count = 0 then
    Exit('-- Tambahkan minimal satu kolom pada tabel.');

  Lines := TStringList.Create;
  try
    if (FSchemaName <> '') and (ADriverType <> dtSQLite) then
      FullTableName := QuoteId(FSchemaName, ADriverType) + '.' + QuoteId(FTablesName, ADriverType)
    else
      FullTableName := QuoteId(FTablesName, ADriverType);

    Lines.Add(Format('CREATE TABLE %s (', [FullTableName]));

    PKList := '';
    HasInlineAutoPK := False;
    ExtraIdxSQL := '';

    // 1. Kolom
    for I := 0 to FColumns.Count - 1 do
    begin
      Col := TBuilderColumn(FColumns[I]);
      ColLine := '  ' + QuoteId(Col.Name, ADriverType) + ' ' + FormatColumnType(Col, ADriverType);

      if (ADriverType = dtSQLite) and Col.IsPrimaryKey and Col.IsAutoIncrement then
      begin
        HasInlineAutoPK := True;
      end
      else
      begin
        if not Col.IsNullable then
          ColLine := ColLine + ' NOT NULL'
        else if (ADriverType in [dtMySQL, dtMariaDB]) then
          ColLine := ColLine + ' NULL';

        if Trim(Col.DefaultValue) <> '' then
        begin
          if UpperCase(Col.DefaultValue) = 'NULL' then
            ColLine := ColLine + ' DEFAULT NULL'
          else if (Pos('INT', UpperCase(Col.DataType)) > 0) or (Pos('NUMERIC', UpperCase(Col.DataType)) > 0) then
            ColLine := ColLine + ' DEFAULT ' + Col.DefaultValue
          else
            ColLine := ColLine + ' DEFAULT ''' + StringReplace(Col.DefaultValue, '''', '''''', [rfReplaceAll]) + '''';
        end;

        if Col.IsAutoIncrement and (ADriverType in [dtMySQL, dtMariaDB]) then
          ColLine := ColLine + ' AUTO_INCREMENT';

        if Col.IsUnique then
          ColLine := ColLine + ' UNIQUE';

        if Col.IsPrimaryKey then
        begin
          if PKList <> '' then PKList := PKList + ', ';
          PKList := PKList + QuoteId(Col.Name, ADriverType);
        end;
      end;

      if (I < FColumns.Count - 1) or (PKList <> '') or (FForeignKeys.Count > 0) then
        ColLine := ColLine + ',';

      Lines.Add(ColLine);
    end;

    // 2. Primary Key
    if (PKList <> '') and not HasInlineAutoPK then
    begin
      if FForeignKeys.Count > 0 then
        Lines.Add(Format('  PRIMARY KEY (%s),', [PKList]))
      else
        Lines.Add(Format('  PRIMARY KEY (%s)', [PKList]));
    end;

    // 3. Foreign Keys
    for I := 0 to FForeignKeys.Count - 1 do
    begin
      FK := TBuilderForeignKey(FForeignKeys[I]);
      if (FK.Columns.Count > 0) and (FK.RefTable <> '') then
      begin
        ColLine := Format('  CONSTRAINT %s FOREIGN KEY (', [QuoteId(FK.Name, ADriverType)]);
        for J := 0 to FK.Columns.Count - 1 do
        begin
          if J > 0 then ColLine := ColLine + ', ';
          ColLine := ColLine + QuoteId(FK.Columns[J], ADriverType);
        end;
        ColLine := ColLine + Format(') REFERENCES %s (', [QuoteId(FK.RefTable, ADriverType)]);
        for J := 0 to FK.RefColumns.Count - 1 do
        begin
          if J > 0 then ColLine := ColLine + ', ';
          ColLine := ColLine + QuoteId(FK.RefColumns[J], ADriverType);
        end;
        ColLine := ColLine + ')';

        if FK.OnUpdate <> '' then ColLine := ColLine + ' ON UPDATE ' + FK.OnUpdate;
        if FK.OnDelete <> '' then ColLine := ColLine + ' ON DELETE ' + FK.OnDelete;

        if I < FForeignKeys.Count - 1 then
          ColLine := ColLine + ',';

        Lines.Add(ColLine);
      end;
    end;

    // Menghapus koma trailing di baris terakhir jika ada
    if Lines[Lines.Count - 1].EndsWith(',') then
      Lines[Lines.Count - 1] := Copy(Lines[Lines.Count - 1], 1, Length(Lines[Lines.Count - 1]) - 1);

    if ADriverType in [dtMySQL, dtMariaDB] then
      Lines.Add(Format(') ENGINE=%s DEFAULT CHARSET=%s;', [FEngine, FCharset]))
    else
      Lines.Add(');');

    // 4. Perintah Tambahan Indeks
    for I := 0 to FIndexes.Count - 1 do
    begin
      Idx := TBuilderIndex(FIndexes[I]);
      if Idx.Columns.Count > 0 then
      begin
        ColLine := '';
        for J := 0 to Idx.Columns.Count - 1 do
        begin
          if J > 0 then ColLine := ColLine + ', ';
          ColLine := ColLine + QuoteId(Idx.Columns[J], ADriverType);
        end;

        if Idx.IndexType = 'UNIQUE' then
          ExtraIdxSQL := ExtraIdxSQL + Format(#13#10'CREATE UNIQUE INDEX %s ON %s (%s);', [QuoteId(Idx.Name, ADriverType), FullTableName, ColLine])
        else
          ExtraIdxSQL := ExtraIdxSQL + Format(#13#10'CREATE INDEX %s ON %s (%s);', [QuoteId(Idx.Name, ADriverType), FullTableName, ColLine]);
      end;
    end;

    Result := Lines.Text + ExtraIdxSQL;
  finally
    Lines.Free;
  end;
end;

end.
