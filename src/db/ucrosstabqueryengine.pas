unit uCrosstabQueryEngine;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  ZConnection, ZDataset,
  uAppTypes, uDBTypes, uModelConnection;

type
  { TCrosstabQueryEngine }
  TCrosstabQueryEngine = class
  public
    class function GenerateCrosstabSQL(
      AProfile: TConnectionProfile;
      const ADBName: string;
      const ATableName: string;
      const ARowField: string;
      const AColField: string;
      const AValueField: string;
      const AAggFunc: string;
      const AIncludeRowTotal: Boolean;
      out AGeneratedSQL: string
    ): Boolean;
  end;

implementation

class function TCrosstabQueryEngine.GenerateCrosstabSQL(
  AProfile: TConnectionProfile;
  const ADBName: string;
  const ATableName: string;
  const ARowField: string;
  const AColField: string;
  const AValueField: string;
  const AAggFunc: string;
  const AIncludeRowTotal: Boolean;
  out AGeneratedSQL: string
): Boolean;
var
  Conn: TZConnection;
  Qry: TZQuery;
  DistinctValues: TStringList;
  I: Integer;
  ValStr, SafeColAlias, CaseLines, FuncName: string;
  SL: TStringList;
begin
  Result := False;
  AGeneratedSQL := '';
  if not Assigned(AProfile) or (ATableName = '') or (ARowField = '') or (AColField = '') or (AValueField = '') then Exit;

  FuncName := UpperCase(Trim(AAggFunc));
  if FuncName = '' then FuncName := 'SUM';

  DistinctValues := TStringList.Create;
  Conn := TZConnection.Create(nil);
  Qry := TZQuery.Create(nil);
  SL := TStringList.Create;
  try
    // 1. Koneksi ke Database
    case AProfile.DriverType of
      dtMySQL:      Conn.Protocol := 'mysql';
      dtMariaDB:    Conn.Protocol := 'mariadb';
      dtPostgreSQL: Conn.Protocol := 'postgresql';
      dtFirebird:   Conn.Protocol := 'firebird';
      dtSQLite:     Conn.Protocol := 'sqlite';
    end;
    Conn.HostName := AProfile.Host;
    Conn.Port := AProfile.Port;
    if ADBName <> '' then
      Conn.Database := ADBName
    else
      Conn.Database := AProfile.DatabaseName;
    Conn.User := AProfile.Username;
    Conn.Password := AProfile.Password;
    Conn.AutoCommit := True;
    Conn.Connect;

    // 2. Ambil seluruh nilai unik (Distinct) untuk dijadikan Header Kolom Horizontal
    Qry.Connection := Conn;
    Qry.SQL.Text := Format(
      'SELECT DISTINCT %s AS col_header FROM %s WHERE %s IS NOT NULL ORDER BY 1;',
      [AColField, ATableName, AColField]
    );
    Qry.Open;

    while not Qry.EOF do
    begin
      ValStr := Qry.FieldByName('col_header').AsString;
      if Trim(ValStr) <> '' then
        DistinctValues.Add(ValStr);
      Qry.Next;
    end;
    Qry.Close;

    if DistinctValues.Count = 0 then
      Exit(False);

    // 3. Susun Ekspresi Pivot CASE WHEN
    CaseLines := '';
    for I := 0 to DistinctValues.Count - 1 do
    begin
      ValStr := DistinctValues[I];
      SafeColAlias := StringReplace(ValStr, '"', '""', [rfReplaceAll]);

      CaseLines := CaseLines + Format(
        '  %s(CASE WHEN %s = ''%s'' THEN %s ELSE NULL END) AS "%s"',
        [FuncName, AColField, StringReplace(ValStr, '''', '''''', [rfReplaceAll]), AValueField, SafeColAlias]
      );

      if (I < DistinctValues.Count - 1) or AIncludeRowTotal then
        CaseLines := CaseLines + ',' + LineEnding;
    end;

    // Tambahkan kolom total horizontal jika diminta
    if AIncludeRowTotal then
      CaseLines := CaseLines + Format('  %s(%s) AS "Total_Keseluruhan"', [FuncName, AValueField]);

    // 4. Susun Skrip SQL Final
    SL.Add('SELECT');
    SL.Add('  ' + ARowField + ',');
    SL.Add(CaseLines);
    SL.Add('FROM ' + ATableName);
    SL.Add('GROUP BY ' + ARowField);
    SL.Add('ORDER BY ' + ARowField + ';');

    AGeneratedSQL := SL.Text;
    Result := True;
  finally
    SL.Free;
    Qry.Free;
    Conn.Free;
    DistinctValues.Free;
  end;
end;

end.
