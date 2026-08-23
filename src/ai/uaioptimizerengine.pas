unit uAIOptimizerEngine;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  uAppTypes, uDBTypes, uModelConnection;

type
  { Struktur Hasil Optimasi AI }
  TAIOptimizerResult = record
    AnalysisText: string;
    OptimizedSQL: string;
    IndexDDL: string;
    RawResponse: string;
  end;

  { TAIOptimizerEngine }
  TAIOptimizerEngine = class
  public
    class function FormatExplainPlan(const APlan: TDBExecutionPlanArray): string;
    class function BuildSystemPrompt(const ADriverType: TDBDriverType): string;
    class function BuildUserPrompt(
      const ADriverType: TDBDriverType;
      const ASQL: string;
      const APlanText: string;
      const ADBTarget: string = ''
    ): string;
    class function ParseOptimizerResponse(const AResponse: string): TAIOptimizerResult;
    class function ExtractCodeBlock(const AText, ATag: string): string;
  end;

implementation

{ TAIOptimizerEngine }

class function TAIOptimizerEngine.FormatExplainPlan(const APlan: TDBExecutionPlanArray): string;
var
  SL: TStringList;
  I: Integer;
begin
  if Length(APlan) = 0 then Exit('(Explain plan kosong atau tidak didukung)');

  SL := TStringList.Create;
  try
    SL.Add('ID | Operasi | Objek Target | Estimasi Baris | Rincian');
    SL.Add('------------------------------------------------------------');
    for I := 0 to High(APlan) do
    begin
      SL.Add(Format('%d | %s | %s | %d | %s', [
        APlan[I].ID,
        APlan[I].Operation,
        APlan[I].TargetObject,
        APlan[I].EstimatedRows,
        APlan[I].Details
      ]));
    end;
    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

class function TAIOptimizerEngine.BuildSystemPrompt(const ADriverType: TDBDriverType): string;
var
  DialectName: string;
begin
  case ADriverType of
    dtMySQL: DialectName := 'MySQL';
    dtMariaDB: DialectName := 'MariaDB';
    dtPostgreSQL: DialectName := 'PostgreSQL';
    dtFirebird: DialectName := 'Firebird SQL';
    dtSQLite: DialectName := 'SQLite';
    else DialectName := 'ANSI SQL Standard';
  end;

  Result :=
    'Anda adalah Senior Database Administrator (DBA) & Query Performance Tuning Specialist khusus dialek ' + DialectName + '.' + LineEnding +
    'Tugas Anda:' + LineEnding +
    '1. Menganalisis kueri SQL dan hasil Execution Plan (EXPLAIN) untuk mendeteksi bottleneck (seperti Full Table Scan, Sorting lambat, Temporary Tables, Missing Indexes).' + LineEnding +
    '2. Melakukan Query Rewrite: Menulis ulang kueri SQL agar lebih efisien dan teroptimasi.' + LineEnding +
    '3. Memberikan rekomendasi pembuatan indeks (CREATE INDEX DDL) yang tepat dan spesifik.' + LineEnding +
    '4. Memberikan penjelasan singkat mengenai alasan optimasi.' + LineEnding + LineEnding +
    'FORMAT OUTPUT WAJIB:' + LineEnding +
    '- Bungkus kueri SQL hasil penulisan ulang di dalam blok: ```sql_optimized ... ```' + LineEnding +
    '- Bungkus skrip pembuatan indeks di dalam blok: ```sql_index ... ```' + LineEnding +
    '- Sediakan analisis dan alasan optimasi dalam teks biasa di luar blok kode.';
end;

class function TAIOptimizerEngine.BuildUserPrompt(
  const ADriverType: TDBDriverType;
  const ASQL: string;
  const APlanText: string;
  const ADBTarget: string
): string;
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Add('### INFORMASI TARGET DATABASE ###');
    if ADBTarget <> '' then
      SL.Add('Target Skema/Database: ' + ADBTarget);
    SL.Add('');
    SL.Add('### KUERI SQL ASLI ###');
    SL.Add(ASQL);
    SL.Add('');
    SL.Add('### HASIL EXECUTION PLAN (EXPLAIN) ###');
    SL.Add(APlanText);
    SL.Add('');
    SL.Add('Silakan berikan analisis performa, kueri SQL hasil rewrite yang dioptimasi (dalam ```sql_optimized```), dan rekomendasi indeks DDL (dalam ```sql_index```).');

    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

class function TAIOptimizerEngine.ExtractCodeBlock(const AText, ATag: string): string;
var
  StartTag, SubStr: string;
  StartPos, EndPos: Integer;
begin
  Result := '';
  StartTag := '```' + ATag;
  StartPos := Pos(LowerCase(StartTag), LowerCase(AText));

  if StartPos > 0 then
  begin
    SubStr := Copy(AText, StartPos + Length(StartTag), Length(AText));
    EndPos := Pos('```', SubStr);
    if EndPos > 0 then
      Exit(Trim(Copy(SubStr, 1, EndPos - 1)));
  end;
end;

class function TAIOptimizerEngine.ParseOptimizerResponse(const AResponse: string): TAIOptimizerResult;
var
  OptSQL, IdxDDL: string;
begin
  Result.RawResponse := AResponse;
  OptSQL := ExtractCodeBlock(AResponse, 'sql_optimized');
  if OptSQL = '' then
    OptSQL := ExtractCodeBlock(AResponse, 'sql'); // Fallback tag umum

  IdxDDL := ExtractCodeBlock(AResponse, 'sql_index');

  Result.OptimizedSQL := OptSQL;
  Result.IndexDDL := IdxDDL;
  Result.AnalysisText := Trim(AResponse);
end;

end.
