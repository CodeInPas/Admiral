unit uSafeModeGuardrails;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  uAppTypes, uDBTypes, uModelConnection;

type
  { Tingkat Risiko Kueri }
  TRiskLevel = (rlNone, rlLow, rlMedium, rlHigh, rlCritical);

  { Hasil Analisis Keamanan Kueri }
  TSafeGuardAnalysis = record
    IsDestructive: Boolean;
    RiskLevel: TRiskLevel;
    Title: string;
    RiskReason: string;
    AffectedOperation: string;
    OffendingSQL: string;
    IsProductionDB: Boolean;
  end;

  { Konfigurasi Safe Mode }
  TSafeModeConfig = class
  public
    EnableSafeMode: Boolean;
    BlockUnconditionalUpdateDelete: Boolean;
    BlockDropTruncate: Boolean;
    WarnOnProductionDB: Boolean;
    ProductionKeywords: TStringList;
    constructor Create;
    destructor Destroy; override;
    procedure SetDefaults;
  end;

  { TSafeModeGuardrails }
  TSafeModeGuardrails = class
  private
    class function StripCommentsAndLiterals(const ASQL: string): string;
    class function IsProductionTarget(AProfile: TConnectionProfile; const ADBName: string): Boolean;
    class function AnalyzeSingleStatement(
      const AOriginalStmt, ACleanStmt: string;
      const AIsProduction: Boolean
    ): TSafeGuardAnalysis;
  public
    class function AnalyzeQuery(
      AProfile: TConnectionProfile;
      const ADBTarget: string;
      const ASQL: string
    ): TSafeGuardAnalysis;
  end;

function SafeModeConfig: TSafeModeConfig;

implementation

var
  GSafeModeConfig: TSafeModeConfig = nil;

function SafeModeConfig: TSafeModeConfig;
begin
  if not Assigned(GSafeModeConfig) then
    GSafeModeConfig := TSafeModeConfig.Create;
  Result := GSafeModeConfig;
end;

{ TSafeModeConfig }

constructor TSafeModeConfig.Create;
begin
  inherited Create;
  ProductionKeywords := TStringList.Create;
  SetDefaults;
end;

destructor TSafeModeConfig.Destroy;
begin
  ProductionKeywords.Free;
  inherited Destroy;
end;

procedure TSafeModeConfig.SetDefaults;
begin
  EnableSafeMode := True;
  BlockUnconditionalUpdateDelete := True;
  BlockDropTruncate := True;
  WarnOnProductionDB := True;

  ProductionKeywords.Clear;
  ProductionKeywords.Add('PROD');
  ProductionKeywords.Add('PRODUCTION');
  ProductionKeywords.Add('LIVE');
  ProductionKeywords.Add('MASTER');
  ProductionKeywords.Add('UTAMA');
end;

{ TSafeModeGuardrails }

class function TSafeModeGuardrails.StripCommentsAndLiterals(const ASQL: string): string;
var
  I, Len: Integer;
  InSingleQuote, InDoubleQuote, InLineComment, InBlockComment: Boolean;
  C, NextC: Char;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create(Length(ASQL));
  try
    InSingleQuote := False;
    InDoubleQuote := False;
    InLineComment := False;
    InBlockComment := False;
    Len := Length(ASQL);
    I := 1;

    while I <= Len do
    begin
      C := ASQL[I];
      if I < Len then NextC := ASQL[I + 1] else NextC := #0;

      // Handle Line Comment (-- ...)
      if not InSingleQuote and not InDoubleQuote and not InBlockComment and (C = '-') and (NextC = '-') then
      begin
        InLineComment := True;
        Inc(I, 2);
        Continue;
      end;

      if InLineComment then
      begin
        if C in [#10, #13] then
        begin
          InLineComment := False;
          SB.Append(' ');
        end;
        Inc(I);
        Continue;
      end;

      // Handle Block Comment (/* ... */)
      if not InSingleQuote and not InDoubleQuote and not InLineComment and (C = '/') and (NextC = '*') then
      begin
        InBlockComment := True;
        Inc(I, 2);
        Continue;
      end;

      if InBlockComment then
      begin
        if (C = '*') and (NextC = '/') then
        begin
          InBlockComment := False;
          Inc(I, 2);
          SB.Append(' ');
          Continue;
        end;
        Inc(I);
        Continue;
      end;

      // Handle String Literals ('...')
      if (C = '''') and not InDoubleQuote then
      begin
        InSingleQuote := not InSingleQuote;
        SB.Append(' ');
        Inc(I);
        Continue;
      end;

      if InSingleQuote then
      begin
        Inc(I);
        Continue;
      end;

      // Regular Character
      SB.Append(C);
      Inc(I);
    end;

    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

class function TSafeModeGuardrails.IsProductionTarget(AProfile: TConnectionProfile; const ADBName: string): Boolean;
var
  TargetText: string;
  I: Integer;
begin
  Result := False;
  if not Assigned(AProfile) then Exit;

  TargetText := UpperCase(AProfile.ConnectionName + ' ' + AProfile.Host + ' ' + ADBName);
  for I := 0 to SafeModeConfig.ProductionKeywords.Count - 1 do
  begin
    if Pos(SafeModeConfig.ProductionKeywords[I], TargetText) > 0 then
      Exit(True);
  end;
end;

class function TSafeModeGuardrails.AnalyzeSingleStatement(
  const AOriginalStmt, ACleanStmt: string;
  const AIsProduction: Boolean
): TSafeGuardAnalysis;
var
  NormSQL: string;
  HasWhere: Boolean;
begin
  Result.IsDestructive := False;
  Result.RiskLevel := rlNone;
  Result.Title := '';
  Result.RiskReason := '';
  Result.AffectedOperation := '';
  Result.OffendingSQL := Trim(AOriginalStmt);
  Result.IsProductionDB := AIsProduction;

  NormSQL := ' ' + UpperCase(Trim(ACleanStmt)) + ' ';
  NormSQL := StringReplace(NormSQL, #13, ' ', [rfReplaceAll]);
  NormSQL := StringReplace(NormSQL, #10, ' ', [rfReplaceAll]);
  NormSQL := StringReplace(NormSQL, #9, ' ', [rfReplaceAll]);

  // 1. Deteksi DELETE tanpa WHERE
  if (Pos(' DELETE ', NormSQL) > 0) and (Pos(' FROM ', NormSQL) > 0) then
  begin
    HasWhere := (Pos(' WHERE ', NormSQL) > 0);
    if not HasWhere and SafeModeConfig.BlockUnconditionalUpdateDelete then
    begin
      Result.IsDestructive := True;
      Result.RiskLevel := rlCritical;
      Result.Title := 'KRITIKAL: DELETE Tanpa Klausa WHERE!';
      Result.AffectedOperation := 'DELETE TANPA FILTER';
      Result.RiskReason :=
        'Perintah ini akan MENGHAPUS SELURUH BARIS data pada tabel yang ditargetkan secara permanen karena tidak menyertakan klausa WHERE.';
      Exit;
    end;
  end;

  // 2. Deteksi UPDATE tanpa WHERE
  if (Pos(' UPDATE ', NormSQL) > 0) and (Pos(' SET ', NormSQL) > 0) then
  begin
    HasWhere := (Pos(' WHERE ', NormSQL) > 0);
    if not HasWhere and SafeModeConfig.BlockUnconditionalUpdateDelete then
    begin
      Result.IsDestructive := True;
      Result.RiskLevel := rlCritical;
      Result.Title := 'KRITIKAL: UPDATE Tanpa Klausa WHERE!';
      Result.AffectedOperation := 'UPDATE TANPA FILTER';
      Result.RiskReason :=
        'Perintah ini akan MENIMPA SELURUH BARIS data pada tabel karena tidak memiliki pembatas filter klausa WHERE.';
      Exit;
    end;
  end;

  // 3. Deteksi TRUNCATE TABLE
  if (Pos(' TRUNCATE ', NormSQL) > 0) and SafeModeConfig.BlockDropTruncate then
  begin
    Result.IsDestructive := True;
    Result.RiskLevel := rlHigh;
    Result.Title := 'PERINGATAN: TRUNCATE Tabel Terdeteksi';
    Result.AffectedOperation := 'TRUNCATE TABLE';
    Result.RiskReason :=
      'Perintah TRUNCATE akan mengosongkan seluruh data tabel dan mereset nilai auto-increment counter.';
    Exit;
  end;

  // 4. Deteksi DROP TABLE / DATABASE / SCHEMA
  if (Pos(' DROP ', NormSQL) > 0) and SafeModeConfig.BlockDropTruncate then
  begin
    if (Pos(' DROP TABLE ', NormSQL) > 0) or (Pos(' DROP DATABASE ', NormSQL) > 0) or
       (Pos(' DROP SCHEMA ', NormSQL) > 0) or (Pos(' DROP VIEW ', NormSQL) > 0) then
    begin
      Result.IsDestructive := True;
      Result.RiskLevel := rlCritical;
      Result.Title := 'BAHAYA: DROP Objek Database';
      Result.AffectedOperation := 'DROP OBJECT';
      Result.RiskReason :=
        'Perintah DROP akan MENGHAPUS tabel atau skema database beserta seluruh isi data dan indeks di dalamnya secara permanen.';
      Exit;
    end;
  end;

  // 5. Peringatan Eksekusi di Database Produksi
  if AIsProduction and SafeModeConfig.WarnOnProductionDB then
  begin
    if (Pos(' INSERT ', NormSQL) > 0) or (Pos(' UPDATE ', NormSQL) > 0) or
       (Pos(' DELETE ', NormSQL) > 0) or (Pos(' ALTER ', NormSQL) > 0) then
    begin
      Result.IsDestructive := True;
      Result.RiskLevel := rlHigh;
      Result.Title := 'PERINGATAN: Modifikasi di Server Produksi (LIVE)';
      Result.AffectedOperation := 'MODIFIKASI PRODUKSI';
      Result.RiskReason :=
        'Koneksi target teridentifikasi sebagai SERVER PRODUKSI / LIVE. Pastikan perubahan data telah divalidasi dengan benar.';
      Exit;
    end;
  end;
end;

class function TSafeModeGuardrails.AnalyzeQuery(
  AProfile: TConnectionProfile;
  const ADBTarget: string;
  const ASQL: string
): TSafeGuardAnalysis;
var
  CleanSQL: string;
  RawStmts, CleanStmts: TStringList;
  I: Integer;
  IsProd: Boolean;
  Analysis: TSafeGuardAnalysis;
begin
  Result.IsDestructive := False;
  Result.RiskLevel := rlNone;
  Result.Title := '';
  Result.RiskReason := '';
  Result.AffectedOperation := '';
  Result.OffendingSQL := '';
  Result.IsProductionDB := False;

  if not SafeModeConfig.EnableSafeMode or (Trim(ASQL) = '') then Exit;

  IsProd := IsProductionTarget(AProfile, ADBTarget);
  CleanSQL := StripCommentsAndLiterals(ASQL);

  RawStmts := TStringList.Create;
  CleanStmts := TStringList.Create;
  try
    RawStmts.Delimiter := ';';
    RawStmts.StrictDelimiter := True;
    RawStmts.DelimitedText := ASQL;

    CleanStmts.Delimiter := ';';
    CleanStmts.StrictDelimiter := True;
    CleanStmts.DelimitedText := CleanSQL;

    for I := 0 to CleanStmts.Count - 1 do
    begin
      if Trim(CleanStmts[I]) = '' then Continue;

      Analysis := AnalyzeSingleStatement(RawStmts[I], CleanStmts[I], IsProd);
      if Analysis.IsDestructive then
      begin
        Result := Analysis;
        Exit; // Intersep segera saat ditemukan pernyataan berisiko pertama
      end;
    end;
  finally
    CleanStmts.Free;
    RawStmts.Free;
  end;
end;

finalization
  if Assigned(GSafeModeConfig) then
    FreeAndNil(GSafeModeConfig);

end.
