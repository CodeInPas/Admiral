unit uMockDataEngine;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils, Math,
  uAppTypes, uDBTypes, uModelConnection, uDBDriverBase, uModelSchemaObject;

type
  { Kategori Tipe Data Mock }
  TMockRuleType = (
    mrtAutoDetect,
    mrtPersonName,
    mrtEmail,
    mrtPhone,
    mrtCityAddress,
    mrtIntegerRange,
    mrtFloatRange,
    mrtDateRange,
    mrtBoolean,
    mrtUUID,
    mrtLoremText,
    mrtPatternMask,
    mrtFixedValue,
    mrtForeignKeyLookup,
    mrtIncremental
  );

  { Konfigurasi Aturan Tiap Kolom }
  TMockColumnRule = class
  public
    ColumnName: string;
    DataType: string;
    IsPrimaryKey: Boolean;
    IsAutoIncrement: Boolean;
    IsForeignKey: Boolean;
    IsNullable: Boolean;
    NullPercentage: Integer; // 0 - 100%

    RuleType: TMockRuleType;
    MinInt: Int64;
    MaxInt: Int64;
    MinFloat: Double;
    MaxFloat: Double;
    StartDate: TDateTime;
    EndDate: TDateTime;
    CustomPattern: string;
    FixedValue: string;

    // Relasi FK
    RefTableName: string;
    RefColumnName: string;

    constructor Create;
  end;

  { Konfigurasi Mocking per Tabel }
  TMockTableConfig = class
  public
    TableName: string;
    RowCount: Integer;
    Rules: TList; // List of TMockColumnRule
    constructor Create;
    destructor Destroy; override;
    function FindRule(const AColName: string): TMockColumnRule;
  end;

  { Service Engine Mock Generator }
  TMockDataEngine = class
  public
    class function TopoSortTables(ADriver: TDBDriverBase; const ATables: TStrings; out ASortedTables: TStringList; out AError: string): Boolean;
    class procedure AutoConfigureRules(ADriver: TDBDriverBase; ATableConfig: TMockTableConfig);
    class function GenerateValue(ARule: TMockColumnRule; const AIncrementalIdx: Int64; const AParentPKPool: TStrings): string;
    class function ParsePattern(const APattern: string): string;
  end;

implementation

const
  FIRST_NAMES: array[0..29] of string = (
    'Ahmad', 'Budi', 'Chandra', 'Dewi', 'Eko', 'Fajar', 'Gita', 'Hadi', 'Indah', 'Joko',
    'Kartika', 'Lestari', 'Muhammad', 'Nur', 'Oki', 'Putri', 'Rian', 'Siti', 'Taufik', 'Utami',
    'Vina', 'Wahyu', 'Yoga', 'Zul', 'Bambang', 'Anisa', 'Rizky', 'Fitri', 'Bayu', 'Dian'
  );

  LAST_NAMES: array[0..19] of string = (
    'Pratama', 'Saputra', 'Wijaya', 'Kusuma', 'Hidayat', 'Santoso', 'Nugroho', 'Setiawan',
    'Siregar', 'Nasution', 'Wibowo', 'Ramadhan', 'Gunawan', 'Permana', 'Lubis', 'Hartono',
    'Susanto', 'Purnama', 'Firmansyah', 'Kurniawan'
  );

  DOMAINS: array[0..5] of string = (
    'gmail.com', 'yahoo.com', 'outlook.com', 'mail.com', 'company.id', 'techcorp.io'
  );

  CITIES: array[0..14] of string = (
    'Jakarta', 'Surabaya', 'Bandung', 'Medan', 'Semarang', 'Makassar', 'Palembang',
    'Yogyakarta', 'Denpasar', 'Banda Aceh', 'Malang', 'Balikpapan', 'Batam', 'Padang', 'Pontianak'
  );

  LOREM_WORDS: array[0..24] of string = (
    'lorem', 'ipsum', 'dolor', 'sit', 'amet', 'consectetur', 'adipiscing', 'elit',
    'sed', 'do', 'eiusmod', 'tempor', 'incididunt', 'ut', 'labore', 'et', 'dolore',
    'magna', 'aliqua', 'enim', 'ad', 'minim', 'veniam', 'quis', 'nostrud'
  );

{ TMockColumnRule }

constructor TMockColumnRule.Create;
begin
  inherited Create;
  IsPrimaryKey := False;
  IsAutoIncrement := False;
  IsForeignKey := False;
  IsNullable := True;
  NullPercentage := 0;
  RuleType := mrtAutoDetect;
  MinInt := 1;
  MaxInt := 1000;
  MinFloat := 10.0;
  MaxFloat := 10000.0;
  StartDate := EncodeDate(2020, 1, 1);
  EndDate := Date;
  CustomPattern := '';
  FixedValue := '';
  RefTableName := '';
  RefColumnName := '';
end;

{ TMockTableConfig }

constructor TMockTableConfig.Create;
begin
  inherited Create;
  RowCount := 100;
  Rules := TList.Create;
end;

destructor TMockTableConfig.Destroy;
var
  I: Integer;
begin
  for I := 0 to Rules.Count - 1 do
    TMockColumnRule(Rules[I]).Free;
  Rules.Free;
  inherited Destroy;
end;

function TMockTableConfig.FindRule(const AColName: string): TMockColumnRule;
var
  I: Integer;
  R: TMockColumnRule;
begin
  Result := nil;
  for I := 0 to Rules.Count - 1 do
  begin
    R := TMockColumnRule(Rules[I]);
    if SameText(R.ColumnName, AColName) then
      Exit(R);
  end;
end;

{ TMockDataEngine }

class function TMockDataEngine.TopoSortTables(ADriver: TDBDriverBase; const ATables: TStrings; out ASortedTables: TStringList; out AError: string): Boolean;
var
  I, J: Integer;
  TblName: string;
  FKList: TSchemaForeignKeyList;
  InDegree: array of Integer;
  AdjList: array of TStringList;
  Queue: TStringList;
  Current: string;
  CurrIdx, NeighborIdx: Integer;
begin
  Result := False;
  AError := '';
  ASortedTables := TStringList.Create;

  if ATables.Count = 0 then Exit(True);

  SetLength(InDegree, ATables.Count);
  SetLength(AdjList, ATables.Count);
  Queue := TStringList.Create;
  FKList := TSchemaForeignKeyList.Create;
  try
    for I := 0 to ATables.Count - 1 do
    begin
      InDegree[I] := 0;
      AdjList[I] := TStringList.Create;
    end;

    // 1. Konstruksi Directed Graph dependensi FK (Parent -> Child)
    for I := 0 to ATables.Count - 1 do
    begin
      TblName := ATables[I];
      FKList.Clear;
      try
        ADriver.ExtractForeignKeys('', '', TblName, FKList);
        for J := 0 to FKList.Count - 1 do
        begin
          NeighborIdx := ATables.IndexOf(FKList[J].RefTableName);
          // Jika parent table ada di dalam list yang akan digenerate dan bukan self-referencing
          if (NeighborIdx >= 0) and (NeighborIdx <> I) then
          begin
            if AdjList[NeighborIdx].IndexOf(TblName) < 0 then
            begin
              AdjList[NeighborIdx].Add(TblName);
              Inc(InDegree[I]);
            end;
          end;
        end;
      except
      end;
    end;

    // 2. Inisialisasi Queue untuk node berderajat masuk 0 (Tidak bergantung tabel lain)
    for I := 0 to ATables.Count - 1 do
    begin
      if InDegree[I] = 0 then
        Queue.Add(ATables[I]);
    end;

    // 3. Algoritma Kahn (Topological BFS)
    while Queue.Count > 0 do
    begin
      Current := Queue[0];
      Queue.Delete(0);
      ASortedTables.Add(Current);

      CurrIdx := ATables.IndexOf(Current);
      if CurrIdx >= 0 then
      begin
        for J := 0 to AdjList[CurrIdx].Count - 1 do
        begin
          NeighborIdx := ATables.IndexOf(AdjList[CurrIdx][J]);
          if NeighborIdx >= 0 then
          begin
            Dec(InDegree[NeighborIdx]);
            if InDegree[NeighborIdx] = 0 then
              Queue.Add(ATables[NeighborIdx]);
          end;
        end;
      end;
    end;

    // 4. Deteksi Siklus (Circular Dependency)
    if ASortedTables.Count < ATables.Count then
    begin
      // Fallback: Masukkan tabel yang tersisa jika terjadi relasi sirkular
      for I := 0 to ATables.Count - 1 do
      begin
        if ASortedTables.IndexOf(ATables[I]) < 0 then
          ASortedTables.Add(ATables[I]);
      end;
    end;

    Result := True;
  finally
    for I := 0 to ATables.Count - 1 do
      AdjList[I].Free;
    Queue.Free;
    FKList.Free;
  end;
end;

class procedure TMockDataEngine.AutoConfigureRules(ADriver: TDBDriverBase; ATableConfig: TMockTableConfig);
var
  Cols: TSchemaColumnList;
  FKs: TSchemaForeignKeyList;
  I, J: Integer;
  Col: TSchemaColumn;
  Rule: TMockColumnRule;
  ColUpper: string;
begin
  Cols := TSchemaColumnList.Create;
  FKs := TSchemaForeignKeyList.Create;
  try
    ADriver.ExtractColumns('', '', ATableConfig.TableName, Cols);
    try
      ADriver.ExtractForeignKeys('', '', ATableConfig.TableName, FKs);
    except
    end;

    for I := 0 to Cols.Count - 1 do
    begin
      Col := Cols[I];
      Rule := TMockColumnRule.Create;
      Rule.ColumnName := Col.Name;
      Rule.DataType := UpperCase(Col.DataType);
      Rule.IsPrimaryKey := Col.IsPrimaryKey;
      Rule.IsAutoIncrement := Col.IsAutoIncrement;
      Rule.IsNullable := Col.IsNullable;
      ColUpper := UpperCase(Col.Name);

      // Cek apakah kolom merupakan Foreign Key
      for J := 0 to FKs.Count - 1 do
      begin
        if (FKs[J].ColumnNames.Count > 0) and SameText(FKs[J].ColumnNames[0], Col.Name) then
        begin
          Rule.IsForeignKey := True;
          Rule.RuleType := mrtForeignKeyLookup;
          Rule.RefTableName := FKs[J].RefTableName;
          if FKs[J].RefColumnNames.Count > 0 then
            Rule.RefColumnName := FKs[J].RefColumnNames[0]
          else
            Rule.RefColumnName := 'id';
          Break;
        end;
      end;

      // Heuristik Deteksi Nama Kolom
      if not Rule.IsForeignKey then
      begin
        if Rule.IsAutoIncrement then
          Rule.RuleType := mrtIncremental
        else if (Pos('EMAIL', ColUpper) > 0) or (Pos('SUREL', ColUpper) > 0) then
          Rule.RuleType := mrtEmail
        else if (Pos('PHONE', ColUpper) > 0) or (Pos('TELP', ColUpper) > 0) or (Pos('HP', ColUpper) > 0) or (Pos('WA', ColUpper) > 0) then
          Rule.RuleType := mrtPhone
        else if (Pos('NAMA', ColUpper) > 0) or (Pos('NAME', ColUpper) > 0) then
          Rule.RuleType := mrtPersonName
        else if (Pos('CITY', ColUpper) > 0) or (Pos('KOTA', ColUpper) > 0) or (Pos('ALAMAT', ColUpper) > 0) or (Pos('ADDRESS', ColUpper) > 0) then
          Rule.RuleType := mrtCityAddress
        else if (Pos('UUID', ColUpper) > 0) or (Pos('GUID', ColUpper) > 0) then
          Rule.RuleType := mrtUUID
        else if (Pos('INT', Rule.DataType) > 0) then
          Rule.RuleType := mrtIntegerRange
        else if (Pos('DATE', Rule.DataType) > 0) or (Pos('TIME', Rule.DataType) > 0) then
          Rule.RuleType := mrtDateRange
        else if (Pos('FLOAT', Rule.DataType) > 0) or (Pos('DECIMAL', Rule.DataType) > 0) or (Pos('NUMERIC', Rule.DataType) > 0) or (Pos('DOUBLE', Rule.DataType) > 0) then
          Rule.RuleType := mrtFloatRange
        else if (Pos('BOOL', Rule.DataType) > 0) then
          Rule.RuleType := mrtBoolean
        else if (Pos('TEXT', Rule.DataType) > 0) or (Pos('MEMO', Rule.DataType) > 0) then
          Rule.RuleType := mrtLoremText
        else
          Rule.RuleType := mrtPersonName;
      end;

      ATableConfig.Rules.Add(Rule);
    end;
  finally
    FKs.Free;
    Cols.Free;
  end;
end;

class function TMockDataEngine.ParsePattern(const APattern: string): string;
var
  I: Integer;
  Res: string;
begin
  Res := '';
  for I := 1 to Length(APattern) do
  begin
    case APattern[I] of
      '#': Res := Res + IntToStr(Random(10));
      'A': Res := Res + Chr(65 + Random(26));
      'a': Res := Res + Chr(97 + Random(26));
      '?': Res := Res + Chr(97 + Random(26));
      else Res := Res + APattern[I];
    end;
  end;
  Result := Res;
end;

class function TMockDataEngine.GenerateValue(ARule: TMockColumnRule; const AIncrementalIdx: Int64; const AParentPKPool: TStrings): string;
var
  Fn, Ln: string;
  DaysDiff: Integer;
  RndDate: TDateTime;
  Guid: TGUID;
begin
  // Penanganan Null Probability
  if ARule.IsNullable and (ARule.NullPercentage > 0) then
  begin
    if Random(100) < ARule.NullPercentage then
      Exit('NULL');
  end;

  case ARule.RuleType of
    mrtIncremental:
      Result := IntToStr(AIncrementalIdx);

    mrtPersonName:
    begin
      Fn := FIRST_NAMES[Random(Length(FIRST_NAMES))];
      Ln := LAST_NAMES[Random(Length(LAST_NAMES))];
      Result := Format('%s %s', [Fn, Ln]);
    end;

    mrtEmail:
    begin
      Fn := AnsiLowerCase(FIRST_NAMES[Random(Length(FIRST_NAMES))]);
      Ln := AnsiLowerCase(LAST_NAMES[Random(Length(LAST_NAMES))]);
      Result := Format('%s.%s%d@%s', [Fn, Ln, Random(99) + 1, DOMAINS[Random(Length(DOMAINS))]]);
    end;

    mrtPhone:
      Result := Format('08%d%s', [Random(8) + 11, ParsePattern('########')]);

    mrtCityAddress:
      Result := Format('Jl. %s No. %d, %s', [LAST_NAMES[Random(Length(LAST_NAMES))], Random(150) + 1, CITIES[Random(Length(CITIES))]]);

    mrtIntegerRange:
    begin
      if ARule.MaxInt <= ARule.MinInt then
        Result := IntToStr(ARule.MinInt)
      else
        Result := IntToStr(ARule.MinInt + Random(ARule.MaxInt - ARule.MinInt + 1));
    end;

    mrtFloatRange:
    begin
      if ARule.MaxFloat <= ARule.MinFloat then
        Result := FloatToStrF(ARule.MinFloat, ffFixed, 10, 2)
      else
        Result := FloatToStrF(ARule.MinFloat + (Random * (ARule.MaxFloat - ARule.MinFloat)), ffFixed, 10, 2);
    end;

    mrtDateRange:
    begin
      DaysDiff := Trunc(ARule.EndDate) - Trunc(ARule.StartDate);
      if DaysDiff <= 0 then DaysDiff := 1;
      RndDate := ARule.StartDate + Random(DaysDiff);
      Result := FormatDateTime('YYYY-MM-DD', RndDate);
    end;

    mrtBoolean:
    begin
      if Random(2) = 1 then Result := '1' else Result := '0';
    end;

    mrtUUID:
    begin
      CreateGUID(Guid);
      Result := GUIDToString(Guid).Replace('{', '').Replace('}', '');
    end;

    mrtLoremText:
    begin
      Result := Format('%s %s %s %s %s %s.', [
        LOREM_WORDS[Random(Length(LOREM_WORDS))],
        LOREM_WORDS[Random(Length(LOREM_WORDS))],
        LOREM_WORDS[Random(Length(LOREM_WORDS))],
        LOREM_WORDS[Random(Length(LOREM_WORDS))],
        LOREM_WORDS[Random(Length(LOREM_WORDS))],
        LOREM_WORDS[Random(Length(LOREM_WORDS))]
      ]);
      Result[1] := UpCase(Result[1]);
    end;

    mrtPatternMask:
      Result := ParsePattern(ARule.CustomPattern);

    mrtFixedValue:
      Result := ARule.FixedValue;

    mrtForeignKeyLookup:
    begin
      if Assigned(AParentPKPool) and (AParentPKPool.Count > 0) then
        Result := AParentPKPool[Random(AParentPKPool.Count)]
      else
        Result := IntToStr(Random(10) + 1);
    end;

    else
      Result := 'MockData_' + IntToStr(AIncrementalIdx);
  end;
end;

end.s
