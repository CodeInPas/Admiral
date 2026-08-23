unit uERDForwardEngine;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  ZConnection,
  uAppTypes, uDBTypes, uModelConnection, uDBConnectionFactory, uERDModel;

type
  { TERDForwardEngine }
  TERDForwardEngine = class
  private
    class function QuoteIdentifier(const AIdent: string; ADriver: TDBDriverType): string;
    class function FormatColumnDDL(ACol: TERDColumn; ADriver: TDBDriverType): string;
  public
    class function GenerateDDLScript(AGraph: TERDGraph; ADriver: TDBDriverType;
      const ADBName: string = ''; ASingleNode: TERDTableNode = nil): string;
    class function ExecuteForwardToDB(AProfile: TConnectionProfile; const ADBName: string;
      const ADDLScript: string; out AErrorMsg: string): Boolean;
  end;

implementation

{ TERDForwardEngine }

class function TERDForwardEngine.QuoteIdentifier(const AIdent: string; ADriver: TDBDriverType): string;
begin
  case ADriver of
    dtMySQL, dtMariaDB: Result := '`' + AIdent + '`';
    dtPostgreSQL:       Result := '"' + AIdent + '"';
    dtSQLite:           Result := '"' + AIdent + '"';
    else                Result := AIdent;
  end;
end;

class function TERDForwardEngine.FormatColumnDDL(ACol: TERDColumn; ADriver: TDBDriverType): string;
var
  ColName, DType: string;
begin
  ColName := QuoteIdentifier(ACol.Name, ADriver);
  DType := ACol.DataType;
  if DType = '' then DType := 'VARCHAR(255)';

  Result := ColName + ' ' + DType;

  if ACol.IsPK then
  begin
    if ADriver = dtSQLite then
      Result := Result + ' PRIMARY KEY'
    else
      Result := Result + ' NOT NULL';
  end;
end;

class function TERDForwardEngine.GenerateDDLScript(AGraph: TERDGraph; ADriver: TDBDriverType;
  const ADBName: string; ASingleNode: TERDTableNode): string;
var
  SB: TStringList;
  I, J: Integer;
  Node: TERDTableNode;
  Rel: TERDRelation;
  TblName, PKCols, ColDefs, FKName: string;
begin
  SB := TStringList.Create;
  try
    SB.Add('-- ====================================================================');
    if Assigned(ASingleNode) then
      SB.Add(Format('-- ADMIRAL ERD FORWARD SYNC - SINGLE TABLE: %s', [ASingleNode.Name]))
    else
      SB.Add('-- ADMIRAL ERD FORWARD SYNC - FULL DIAGRAM MODEL');
    SB.Add(Format('-- Waktu: %s | DBMS: %s', [FormatDateTime('YYYY-MM-DD hh:nn:ss', Now), TDBConnectionFactory.GetDriverDisplayName(ADriver)]));
    if ADBName <> '' then
      SB.Add(Format('-- Target Database : %s', [ADBName]));
    SB.Add('-- ====================================================================');
    SB.Add('');

    if (ADriver in [dtMySQL, dtMariaDB]) and (ADBName <> '') then
    begin
      SB.Add(Format('CREATE DATABASE IF NOT EXISTS %s;', [QuoteIdentifier(ADBName, ADriver)]));
      SB.Add(Format('USE %s;', [QuoteIdentifier(ADBName, ADriver)]));
      SB.Add('');
    end;

    // 1. Generate CREATE TABLE (Aman dengan IF NOT EXISTS)
    for I := 0 to AGraph.NodeCount - 1 do
    begin
      Node := AGraph.Nodes[I];

      // Jika dalam mode single table, lewati node lain
      if Assigned(ASingleNode) and (Node <> ASingleNode) then
        Continue;

      TblName := QuoteIdentifier(Node.Name, ADriver);

      SB.Add(Format('-- Definisi Tabel: %s', [Node.Name]));
      SB.Add(Format('CREATE TABLE IF NOT EXISTS %s (', [TblName]));

      ColDefs := '';
      PKCols := '';

      for J := 0 to Node.ColumnCount - 1 do
      begin
        if ColDefs <> '' then ColDefs := ColDefs + ',' + sLineBreak;
        ColDefs := ColDefs + '  ' + FormatColumnDDL(Node.Columns[J], ADriver);

        if Node.Columns[J].IsPK and (ADriver <> dtSQLite) then
        begin
          if PKCols <> '' then PKCols := PKCols + ', ';
          PKCols := PKCols + QuoteIdentifier(Node.Columns[J].Name, ADriver);
        end;
      end;

      SB.Add(ColDefs);

      if (PKCols <> '') and (ADriver <> dtSQLite) then
      begin
        SB.Add(',');
        SB.Add(Format('  PRIMARY KEY (%s)', [PKCols]));
      end;

      if ADriver in [dtMySQL, dtMariaDB] then
        SB.Add(') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;')
      else
        SB.Add(');');

      SB.Add('');
    end;

    // 2. Generate Foreign Key Constraints (ALTER TABLE)
    if (AGraph.RelationCount > 0) and (ADriver <> dtSQLite) then
    begin
      for I := 0 to AGraph.RelationCount - 1 do
      begin
        Rel := AGraph.Relations[I];
        if not Assigned(Rel.SourceNode) or not Assigned(Rel.TargetNode) then Continue;

        // Jika mode single table, hanya sertakan relasi milik tabel tersebut
        if Assigned(ASingleNode) and (Rel.SourceNode <> ASingleNode) then Continue;

        FKName := Format('fk_%s_%s', [Rel.SourceNode.Name, Rel.SourceColumn]);
        SB.Add(Format('ALTER TABLE %s', [QuoteIdentifier(Rel.SourceNode.Name, ADriver)]));
        SB.Add(Format('  ADD CONSTRAINT %s', [QuoteIdentifier(FKName, ADriver)]));
        SB.Add(Format('  FOREIGN KEY (%s) REFERENCES %s (%s)', [
          QuoteIdentifier(Rel.SourceColumn, ADriver),
          QuoteIdentifier(Rel.TargetNode.Name, ADriver),
          QuoteIdentifier(Rel.TargetColumn, ADriver)
        ]));
        SB.Add('  ON DELETE CASCADE ON UPDATE CASCADE;');
        SB.Add('');
      end;
    end;

    Result := SB.Text;
  finally
    SB.Free;
  end;
end;

class function TERDForwardEngine.ExecuteForwardToDB(AProfile: TConnectionProfile; const ADBName: string;
  const ADDLScript: string; out AErrorMsg: string): Boolean;
var
  Conn: TZConnection;
begin
  Result := False;
  AErrorMsg := '';

  Conn := TZConnection.Create(nil);
  try
    try
      case AProfile.DriverType of
        dtMySQL:      Conn.Protocol := 'mysql';
        dtMariaDB:    Conn.Protocol := 'mariadb';
        dtPostgreSQL: Conn.Protocol := 'postgresql';
        dtSQLite:     Conn.Protocol := 'sqlite';
        dtFirebird:   Conn.Protocol := 'firebird';
      end;

      // Mendukung tunneling SSH maupun direct connection
      Conn.HostName := TDBConnectionFactory.GetEffectiveHost(AProfile);
      Conn.Port := TDBConnectionFactory.GetEffectivePort(AProfile);

      if ADBName <> '' then Conn.Database := ADBName else Conn.Database := AProfile.DatabaseName;
      Conn.User := AProfile.Username;
      Conn.Password := AProfile.Password;
      Conn.AutoCommit := True;
      Conn.Connect;

      Conn.ExecuteDirect(ADDLScript);
      Result := True;
    except
      on E: Exception do
        AErrorMsg := E.Message;
    end;
  finally
    Conn.Free;
  end;
end;

end.
