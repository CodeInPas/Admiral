unit uModelVisualQuery;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  uAppTypes, uDBTypes;

type
  { Tipe Agregasi Kolom }
  TQueryAggregate = (qaNone, qaCount, qaCountDistinct, qaSum, qaAvg, qaMin, qaMax);

  { Tipe Relasi JOIN }
  TQueryJoinType = (qjtInner, qjtLeft, qjtRight, qjtFull, qjtCross);

  { Tipe Pengurutan }
  TQuerySortDir = (qsdNone, qsdAsc, qsdDesc);

  { Representasi Kolom Terpilih }
  TVisualColumn = class
  public
    TableAlias: string;
    ColumnName: string;
    OutputAlias: string;
    Aggregate: TQueryAggregate;
    IsSelected: Boolean;
    SortDir: TQuerySortDir;
    SortOrder: Integer;
  end;

  { Representasi Relasi Antar Tabel }
  TVisualJoin = class
  public
    JoinType: TQueryJoinType;
    LeftTableAlias: string;
    LeftColumn: string;
    RightTableAlias: string;
    RightColumn: string;
  end;

  { Representasi Kriteria Filter (WHERE / HAVING) }
  TVisualCondition = class
  public
    TableAlias: string;
    ColumnName: string;
    OperatorStr: string;
    ValueStr: string;
    Connector: string;
  end;

  { Representasi Tabel pada Canvas Visual }
  TVisualTable = class
  public
    TableName: string;
    SchemaName: string;
    Alias: string;
    Columns: TList;
    constructor Create;
    destructor Destroy; override;
  end;

  { TVisualQueryModel }
  TVisualQueryModel = class
  private
    FTableCounter: Integer;
    FTables: TList;
    FJoins: TList;
    FConditions: TList;
    FDistinct: Boolean;
    FLimit: Integer;
    FOffset: Integer;
    function QuoteId(const AName: string; const ADriver: TDBDriverType): string;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;
    function AddTable(const ATableName, ASchema, AAlias: string): TVisualTable;
    function FindTableByAlias(const AAlias: string): TVisualTable;
    procedure RemoveTable(const AAlias: string);

    procedure AddJoin(const AType: TQueryJoinType; const ALeftAlias, ALeftCol, ARightAlias, ARightCol: string);
    procedure AddCondition(const AAlias, ACol, AOp, AVal, AConnector: string);

    function GenerateSQL(const ADriverType: TDBDriverType): string;

    property Tables: TList read FTables;
    property Joins: TList read FJoins;
    property Conditions: TList read FConditions;
    property Distinct: Boolean read FDistinct write FDistinct;
    property Limit: Integer read FLimit write FLimit;
    property Offset: Integer read FOffset write FOffset;
  end;

implementation

{ TVisualTable }

constructor TVisualTable.Create;
begin
  inherited Create;
  Columns := TList.Create;
end;

destructor TVisualTable.Destroy;
var
  I: Integer;
begin
  for I := 0 to Columns.Count - 1 do
    TVisualColumn(Columns[I]).Free;
  Columns.Free;
  //inherited Destroy;
end;

{ TVisualQueryModel }

constructor TVisualQueryModel.Create;
begin
  inherited Create;
  FTableCounter := 0;
  FTables := TList.Create;
  FJoins := TList.Create;
  FConditions := TList.Create;
  FDistinct := False;
  FLimit := 0;
  FOffset := 0;
end;

destructor TVisualQueryModel.Destroy;
begin
  Clear;
  FTables.Free;
  FJoins.Free;
  FConditions.Free;
  //inherited Destroy;
end;

procedure TVisualQueryModel.Clear;
var
  I: Integer;
begin
  for I := 0 to FTables.Count - 1 do
    TVisualTable(FTables[I]).Free;
  FTables.Clear;

  for I := 0 to FJoins.Count - 1 do
    TVisualJoin(FJoins[I]).Free;
  FJoins.Clear;

  for I := 0 to FConditions.Count - 1 do
    TVisualCondition(FConditions[I]).Free;
  FConditions.Clear;

  FDistinct := False;
  FLimit := 0;
  FOffset := 0;
end;

function TVisualQueryModel.AddTable(const ATableName, ASchema, AAlias: string): TVisualTable;
begin
  Result := TVisualTable.Create;
  Result.TableName := ATableName;
  Result.SchemaName := ASchema;
  Inc(FTableCounter);
  if AAlias <> '' then
    Result.Alias := AAlias
  else
    Result.Alias := 't' + IntToStr(FTableCounter);
  FTables.Add(Result);
end;

function TVisualQueryModel.FindTableByAlias(const AAlias: string): TVisualTable;
var
  I: Integer;
  Tbl: TVisualTable;
begin
  Result := nil;
  for I := 0 to FTables.Count - 1 do
  begin
    Tbl := TVisualTable(FTables[I]);
    if SameText(Tbl.Alias, AAlias) then
      Exit(Tbl);
  end;
end;

procedure TVisualQueryModel.RemoveTable(const AAlias: string);
var
  I: Integer;
  Tbl: TVisualTable;
  Jn: TVisualJoin;
  Cond: TVisualCondition;
begin
  for I := FTables.Count - 1 downto 0 do
  begin
    Tbl := TVisualTable(FTables[I]);
    if SameText(Tbl.Alias, AAlias) then
    begin
      Tbl.Free;
      FTables.Delete(I);
      Break;
    end;
  end;

  for I := FJoins.Count - 1 downto 0 do
  begin
    Jn := TVisualJoin(FJoins[I]);
    if SameText(Jn.LeftTableAlias, AAlias) or SameText(Jn.RightTableAlias, AAlias) then
    begin
      Jn.Free;
      FJoins.Delete(I);
    end;
  end;

  for I := FConditions.Count - 1 downto 0 do
  begin
    Cond := TVisualCondition(FConditions[I]);
    if SameText(Cond.TableAlias, AAlias) then
    begin
      Cond.Free;
      FConditions.Delete(I);
    end;
  end;
end;

procedure TVisualQueryModel.AddJoin(const AType: TQueryJoinType; const ALeftAlias, ALeftCol, ARightAlias, ARightCol: string);
var
  Jn: TVisualJoin;
begin
  Jn := TVisualJoin.Create;
  Jn.JoinType := AType;
  Jn.LeftTableAlias := ALeftAlias;
  Jn.LeftColumn := ALeftCol;
  Jn.RightTableAlias := ARightAlias;
  Jn.RightColumn := ARightCol;
  FJoins.Add(Jn);
end;

procedure TVisualQueryModel.AddCondition(const AAlias, ACol, AOp, AVal, AConnector: string);
var
  Cond: TVisualCondition;
begin
  Cond := TVisualCondition.Create;
  Cond.TableAlias := AAlias;
  Cond.ColumnName := ACol;
  Cond.OperatorStr := UpperCase(Trim(AOp));
  Cond.ValueStr := Trim(AVal);
  if UpperCase(AConnector) = 'OR' then
    Cond.Connector := 'OR'
  else
    Cond.Connector := 'AND';
  FConditions.Add(Cond);
end;

function TVisualQueryModel.QuoteId(const AName: string; const ADriver: TDBDriverType): string;
begin
  if AName = '*' then Exit('*');
  case ADriver of
    dtMySQL, dtMariaDB: Result := '`' + AName + '`';
    dtPostgreSQL, dtSQLite, dtFirebird: Result := '"' + AName + '"';
    else Result := AName;
  end;
end;

function TVisualQueryModel.GenerateSQL(const ADriverType: TDBDriverType): string;
var
  SQL, SelectClause, FromClause, WhereClause, GroupClause, OrderClause: string;
  I, J: Integer;
  Tbl, MainTbl: TVisualTable;
  Col: TVisualColumn;
  Jn: TVisualJoin;
  Cond: TVisualCondition;
  HasAggregate, HasNonAggregate: Boolean;
  ColExpr, FullColName, JoinWord: string;
  SortedCols: TList;
begin
  if FTables.Count = 0 then
    Exit('-- Pilih minimal satu tabel untuk membuat kueri SQL.');

  SelectClause := 'SELECT ';
  if FDistinct then
    SelectClause := SelectClause + 'DISTINCT ';

  HasAggregate := False;
  HasNonAggregate := False;
  GroupClause := '';
  ColExpr := '';

  for I := 0 to FTables.Count - 1 do
  begin
    Tbl := TVisualTable(FTables[I]);
    for J := 0 to Tbl.Columns.Count - 1 do
    begin
      Col := TVisualColumn(Tbl.Columns[J]);
      if Col.IsSelected then
      begin
        if Col.ColumnName = '*' then
          FullColName := Format('%s.*', [Tbl.Alias])
        else
          FullColName := Format('%s.%s', [Tbl.Alias, QuoteId(Col.ColumnName, ADriverType)]);

        case Col.Aggregate of
          qaCount:
          begin
            ColExpr := Format('COUNT(%s)', [FullColName]);
            HasAggregate := True;
          end;
          qaCountDistinct:
          begin
            ColExpr := Format('COUNT(DISTINCT %s)', [FullColName]);
            HasAggregate := True;
          end;
          qaSum:
          begin
            ColExpr := Format('SUM(%s)', [FullColName]);
            HasAggregate := True;
          end;
          qaAvg:
          begin
            ColExpr := Format('AVG(%s)', [FullColName]);
            HasAggregate := True;
          end;
          qaMin:
          begin
            ColExpr := Format('MIN(%s)', [FullColName]);
            HasAggregate := True;
          end;
          qaMax:
          begin
            ColExpr := Format('MAX(%s)', [FullColName]);
            HasAggregate := True;
          end;
          else
          begin
            ColExpr := FullColName;
            HasNonAggregate := True;
            if GroupClause <> '' then GroupClause := GroupClause + ', ';
            GroupClause := GroupClause + FullColName;
          end;
        end;

        if Col.OutputAlias <> '' then
          ColExpr := Format('%s AS %s', [ColExpr, QuoteId(Col.OutputAlias, ADriverType)]);

        if (SelectClause <> 'SELECT ') and (SelectClause <> 'SELECT DISTINCT ') then
          SelectClause := SelectClause + ', ';
        SelectClause := SelectClause + ColExpr;
      end;
    end;
  end;

  if (SelectClause = 'SELECT ') or (SelectClause = 'SELECT DISTINCT ') then
    SelectClause := SelectClause + '*';

  MainTbl := TVisualTable(FTables[0]);
  FromClause := Format('FROM %s %s', [QuoteId(MainTbl.TableName, ADriverType), MainTbl.Alias]);

  for I := 0 to FJoins.Count - 1 do
  begin
    Jn := TVisualJoin(FJoins[I]);
    Tbl := FindTableByAlias(Jn.RightTableAlias);
    if Assigned(Tbl) then
    begin
      case Jn.JoinType of
        qjtInner: JoinWord := 'INNER JOIN';
        qjtLeft:  JoinWord := 'LEFT JOIN';
        qjtRight: JoinWord := 'RIGHT JOIN';
        qjtFull:  JoinWord := 'FULL OUTER JOIN';
        qjtCross: JoinWord := 'CROSS JOIN';
      end;

      if Jn.JoinType = qjtCross then
        FromClause := Format('%s'#13#10'  %s %s %s', [
          FromClause,
          JoinWord,
          QuoteId(Tbl.TableName, ADriverType),
          Tbl.Alias
        ])
      else
        FromClause := Format('%s'#13#10'  %s %s %s ON %s.%s = %s.%s', [
          FromClause,
          JoinWord,
          QuoteId(Tbl.TableName, ADriverType),
          Tbl.Alias,
          Jn.LeftTableAlias,
          QuoteId(Jn.LeftColumn, ADriverType),
          Jn.RightTableAlias,
          QuoteId(Jn.RightColumn, ADriverType)
        ]);
    end;
  end;

  WhereClause := '';
  for I := 0 to FConditions.Count - 1 do
  begin
    Cond := TVisualCondition(FConditions[I]);
    if WhereClause <> '' then
      WhereClause := WhereClause + ' ' + Cond.Connector + ' ';

    FullColName := Format('%s.%s', [Cond.TableAlias, QuoteId(Cond.ColumnName, ADriverType)]);

    if (Cond.OperatorStr = 'IS NULL') or (Cond.OperatorStr = 'IS NOT NULL') then
      WhereClause := WhereClause + Format('%s %s', [FullColName, Cond.OperatorStr])
    else if Cond.OperatorStr = 'IN' then
      WhereClause := WhereClause + Format('%s IN (%s)', [FullColName, Cond.ValueStr])
    else if (Cond.OperatorStr = 'LIKE') or (Cond.OperatorStr = 'NOT LIKE') then
      WhereClause := WhereClause + Format('%s %s ''%s''', [FullColName, Cond.OperatorStr, Cond.ValueStr])
    else
      WhereClause := WhereClause + Format('%s %s %s', [FullColName, Cond.OperatorStr, Cond.ValueStr]);
  end;

  OrderClause := '';
  SortedCols := TList.Create;
  try
    for I := 0 to FTables.Count - 1 do
    begin
      Tbl := TVisualTable(FTables[I]);
      for J := 0 to Tbl.Columns.Count - 1 do
      begin
        Col := TVisualColumn(Tbl.Columns[J]);
        if Col.SortDir <> qsdNone then
          SortedCols.Add(Col);
      end;
    end;

    for I := 0 to SortedCols.Count - 1 do
    begin
      Col := TVisualColumn(SortedCols[I]);
      if OrderClause <> '' then OrderClause := OrderClause + ', ';
      FullColName := Format('%s.%s', [Col.TableAlias, QuoteId(Col.ColumnName, ADriverType)]);
      if Col.SortDir = qsdAsc then
        OrderClause := OrderClause + FullColName + ' ASC'
      else
        OrderClause := OrderClause + FullColName + ' DESC';
    end;
  finally
    SortedCols.Free;
  end;

  SQL := SelectClause + #13#10 + FromClause;

  if WhereClause <> '' then
    SQL := SQL + #13#10'WHERE ' + WhereClause;

  if HasAggregate and HasNonAggregate and (GroupClause <> '') then
    SQL := SQL + #13#10'GROUP BY ' + GroupClause;

  if OrderClause <> '' then
    SQL := SQL + #13#10'ORDER BY ' + OrderClause;

  if FLimit > 0 then
  begin
    if FOffset > 0 then
      SQL := Format('%s'#13#10'LIMIT %d OFFSET %d', [SQL, FLimit, FOffset])
    else
      SQL := Format('%s'#13#10'LIMIT %d', [SQL, FLimit]);
  end;

  Result := SQL + ';';
end;

end.
