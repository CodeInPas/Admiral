unit uAIDiagnosticsEngine;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  uAppTypes, uDBTypes, uModelConnection;

type
  { Hasil Diagnostik AI }
  TAIDiagnosticResult = record
    Explanation: string;
    FixedSQL: string;
    RawResponse: string;
  end;

  { TAIDiagnosticsEngine }
  TAIDiagnosticsEngine = class
  public
    class function BuildSystemPrompt(const ADriverType: TDBDriverType): string;
    class function BuildUserPrompt(
      const ADriverType: TDBDriverType;
      const AFailedSQL: string;
      const AErrorMessage: string;
      const ADBTarget: string = ''
    ): string;
    class function ParseDiagnosticResponse(const AResponse: string): TAIDiagnosticResult;
    class function ExtractSQLCodeBlock(const AText: string): string;
  end;

implementation

{ TAIDiagnosticsEngine }

class function TAIDiagnosticsEngine.BuildSystemPrompt(const ADriverType: TDBDriverType): string;
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
    'Anda adalah Database Administrator dan SQL Diagnostics Expert berpengalaman khusus untuk dialek ' + DialectName + '.' + LineEnding +
    'Tugas Anda:' + LineEnding +
    '1. Menganalisis kueri SQL yang gagal beserta pesan runtime error (EDBError / EZSQLException).' + LineEnding +
    '2. Menjelaskan akar masalah (root cause) dalam bahasa Indonesia yang ringkas dan jelas.' + LineEnding +
    '3. Memberikan kueri SQL hasil perbaikan (Auto-Fix) yang valid dan siap dieksekusi.' + LineEnding +
    'PENTING: Selalu bungkus kueri SQL hasil koreksi di dalam blok Markdown ```sql ... ``` agar sistem dapat mengekstraknya secara otomatis.';
end;

class function TAIDiagnosticsEngine.BuildUserPrompt(
  const ADriverType: TDBDriverType;
  const AFailedSQL: string;
  const AErrorMessage: string;
  const ADBTarget: string
): string;
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Add('### INFORMASI KESALAHAN DATABASE ###');
    if ADBTarget <> '' then
      SL.Add('Target Database: ' + ADBTarget);
    SL.Add('Pesan Runtime Error:');
    SL.Add(AErrorMessage);
    SL.Add('');
    SL.Add('### KUERI SQL YANG GAGAL ###');
    SL.Add(AFailedSQL);
    SL.Add('');
    SL.Add('Berikan:');
    SL.Add('1. Analisis Penyebab Kesalahan');
    SL.Add('2. Solusi / Saran Perbaikan');
    SL.Add('3. Kueri SQL yang sudah diperbaiki (dalam blok ```sql ... ```)');

    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

class function TAIDiagnosticsEngine.ExtractSQLCodeBlock(const AText: string): string;
var
  StartPos, EndPos: Integer;
  SubStr: string;
begin
  Result := '';
  // 1. Cari blok ```sql ... ```
  StartPos := Pos('```sql', LowerCase(AText));
  if StartPos > 0 then
  begin
    SubStr := Copy(AText, StartPos + 6, Length(AText));
    EndPos := Pos('```', SubStr);
    if EndPos > 0 then
      Exit(Trim(Copy(SubStr, 1, EndPos - 1)));
  end;

  // 2. Fallback: Cari blok ``` ... ``` umum
  StartPos := Pos('```', AText);
  if StartPos > 0 then
  begin
    SubStr := Copy(AText, StartPos + 3, Length(AText));
    EndPos := Pos('```', SubStr);
    if EndPos > 0 then
      Exit(Trim(Copy(SubStr, 1, EndPos - 1)));
  end;

  Result := Trim(AText);
end;

class function TAIDiagnosticsEngine.ParseDiagnosticResponse(const AResponse: string): TAIDiagnosticResult;
begin
  Result.RawResponse := AResponse;
  Result.FixedSQL := ExtractSQLCodeBlock(AResponse);
  Result.Explanation := Trim(AResponse);
end;

end.
