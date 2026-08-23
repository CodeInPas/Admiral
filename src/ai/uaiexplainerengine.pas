unit uAIExplainerEngine;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  uAppTypes, uDBTypes, uModelConnection;

type
  { Struktur Hasil Dokumentasi & Penjelasan SQL }
  TAIExplanationResult = record
    Overview: string;
    LogicExplanation: string;
    AnnotatedSQL: string;
    RawResponse: string;
  end;

  { TAIExplainerEngine }
  TAIExplainerEngine = class
  public
    class function BuildSystemPrompt(const ADriverType: TDBDriverType): string;
    class function BuildUserPrompt(
      const ADriverType: TDBDriverType;
      const ASQL: string;
      const ADBTarget: string = ''
    ): string;
    class function ParseExplainerResponse(const AResponse: string): TAIExplanationResult;
    class function ExtractCodeBlock(const AText, ATag: string): string;
  end;

implementation

{ TAIExplainerEngine }

class function TAIExplainerEngine.BuildSystemPrompt(const ADriverType: TDBDriverType): string;
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
    'Anda adalah Lead Database Architect dan Technical Writer profesional khusus dialek ' + DialectName + '.' + LineEnding +
    'Tugas Anda:' + LineEnding +
    '1. Menjelaskan maksud dan tujuan kueri SQL secara konseptual (ringkasan eksekutif).' + LineEnding +
    '2. Membedah alur logika kueri langkah demi langkah (FROM/JOIN, WHERE filter, GROUP BY/Aggregasi, HAVING, ORDER BY, LIMIT).' + LineEnding +
    '3. Mengidentifikasi seluruh tabel, view, dan relasi kolom yang terlibat.' + LineEnding +
    '4. Membuat versi Annotated SQL yang rapi dengan header docstring komprehensif di awal kueri serta komentar inline (--) pada klausa-klausa penting.' + LineEnding + LineEnding +
    'FORMAT OUTPUT WAJIB:' + LineEnding +
    '- Berikan penjelasan lengkap, analisis langkah demi langkah, dan identifikasi tabel dalam teks Markdown.' + LineEnding +
    '- Bungkus kueri SQL beranotasi/berkomentar di dalam blok khusus: ```sql_annotated ... ```';
end;

class function TAIExplainerEngine.BuildUserPrompt(
  const ADriverType: TDBDriverType;
  const ASQL: string;
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
    SL.Add('### KUERI SQL UNTUK DIJELASKAN & DIDOKUMENTASIKAN ###');
    SL.Add(ASQL);
    SL.Add('');
    SL.Add('Silakan berikan:');
    SL.Add('1. Ringkasan Tujuan Kueri');
    SL.Add('2. Penjelasan Alur Logika Eksekusi (Step-by-Step)');
    SL.Add('3. Tabel & Field yang Terlibat');
    SL.Add('4. Kueri SQL Beranotasi Lengkap (dalam blok ```sql_annotated ... ```)');

    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

class function TAIExplainerEngine.ExtractCodeBlock(const AText, ATag: string): string;
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

class function TAIExplainerEngine.ParseExplainerResponse(const AResponse: string): TAIExplanationResult;
var
  AnnSQL: string;
begin
  Result.RawResponse := AResponse;
  AnnSQL := ExtractCodeBlock(AResponse, 'sql_annotated');
  if AnnSQL = '' then
    AnnSQL := ExtractCodeBlock(AResponse, 'sql');

  Result.AnnotatedSQL := AnnSQL;
  Result.LogicExplanation := Trim(AResponse);
end;

end.
