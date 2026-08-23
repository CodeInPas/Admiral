unit uModelSchemaObject;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fgl, uAppTypes;

type
  { Forward Declarations }
  TSchemaColumn = class;
  TSchemaIndex = class;
  TSchemaForeignKey = class;
  TSchemaObject = class;

  { Daftar Generik }
  TSchemaColumnList = specialize TFPGObjectList<TSchemaColumn>;
  TSchemaIndexList = specialize TFPGObjectList<TSchemaIndex>;
  TSchemaForeignKeyList = specialize TFPGObjectList<TSchemaForeignKey>;
  TSchemaObjectList = specialize TFPGObjectList<TSchemaObject>;

  { TSchemaColumn }
  TSchemaColumn = class
  private
    FName: string;
    FDataType: string;
    FLength: Integer;
    FPrecision: Integer;
    FScale: Integer;
    FIsNullable: Boolean;
    FIsPrimaryKey: Boolean;
    FIsAutoIncrement: Boolean;
    FDefaultValue: string;
    FComment: string;
    FOrdinalPosition: Integer;
  public
    constructor Create;
    procedure Assign(Source: TSchemaColumn);

    property Name: string read FName write FName;
    property DataType: string read FDataType write FDataType;
    property Length: Integer read FLength write FLength;
    property Precision: Integer read FPrecision write FPrecision;
    property Scale: Integer read FScale write FScale;
    property IsNullable: Boolean read FIsNullable write FIsNullable;
    property IsPrimaryKey: Boolean read FIsPrimaryKey write FIsPrimaryKey;
    property IsAutoIncrement: Boolean read FIsAutoIncrement write FIsAutoIncrement;
    property DefaultValue: string read FDefaultValue write FDefaultValue;
    property Comment: string read FComment write FComment;
    property OrdinalPosition: Integer read FOrdinalPosition write FOrdinalPosition;
  end;

  { TSchemaIndex }
  TSchemaIndex = class
  private
    FName: string;
    FTableName: string;
    FIsUnique: Boolean;
    FIsPrimary: Boolean;
    FIndexType: string;
    FColumns: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TSchemaIndex);

    property Name: string read FName write FName;
    property TableName: string read FTableName write FTableName;
    property IsUnique: Boolean read FIsUnique write FIsUnique;
    property IsPrimary: Boolean read FIsPrimary write FIsPrimary;
    property IndexType: string read FIndexType write FIndexType;
    property Columns: TStringList read FColumns;
  end;

  { TSchemaForeignKey }
  TSchemaForeignKey = class
  private
    FName: string;
    FTableName: string;
    FColumnNames: TStringList;
    FRefTableName: string;
    FRefColumnNames: TStringList;
    FOnUpdate: string;
    FOnDelete: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TSchemaForeignKey);

    property Name: string read FName write FName;
    property TableName: string read FTableName write FTableName;
    property ColumnNames: TStringList read FColumnNames;
    property RefTableName: string read FRefTableName write FRefTableName;
    property RefColumnNames: TStringList read FRefColumnNames;
    property OnUpdate: string read FOnUpdate write FOnUpdate;
    property OnDelete: string read FOnDelete write FOnDelete;
  end;

  { TSchemaObject }
  TSchemaObject = class
  private
    FName: string;
    FDatabaseName: string;
    FSchemaName: string;
    FObjectType: TSchemaObjectType;
    FDDL: string;
    FRowCount: Int64;
    FComment: string;
    FChildren: TSchemaObjectList;
    FColumns: TSchemaColumnList;
    FIndexes: TSchemaIndexList;
    FFreqForeignKeys: TSchemaForeignKeyList;
    FParent: TSchemaObject;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;

    property Name: string read FName write FName;
    property DatabaseName: string read FDatabaseName write FDatabaseName;
    property SchemaName: string read FSchemaName write FSchemaName;
    property ObjectType: TSchemaObjectType read FObjectType write FObjectType;
    property DDL: string read FDDL write FDDL;
    property RowCount: Int64 read FRowCount write FRowCount;
    property Comment: string read FComment write FComment;
    property Parent: TSchemaObject read FParent write FParent;

    // Hirarki dan Sub-objek
    property Children: TSchemaObjectList read FChildren;
    property Columns: TSchemaColumnList read FColumns;
    property Indexes: TSchemaIndexList read FIndexes;
    property ForeignKeys: TSchemaForeignKeyList read FFreqForeignKeys;
  end;

implementation

{ TSchemaColumn }

constructor TSchemaColumn.Create;
begin
  inherited Create;
  FName := '';
  FDataType := '';
  FLength := 0;
  FPrecision := 0;
  FScale := 0;
  FIsNullable := True;
  FIsPrimaryKey := False;
  FIsAutoIncrement := False;
  FDefaultValue := '';
  FComment := '';
  FOrdinalPosition := 0;
end;

procedure TSchemaColumn.Assign(Source: TSchemaColumn);
begin
  if Assigned(Source) then
  begin
    FName := Source.Name;
    FDataType := Source.DataType;
    FLength := Source.Length;
    FPrecision := Source.Precision;
    FScale := Source.Scale;
    FIsNullable := Source.IsNullable;
    FIsPrimaryKey := Source.IsPrimaryKey;
    FIsAutoIncrement := Source.IsAutoIncrement;
    FDefaultValue := Source.DefaultValue;
    FComment := Source.Comment;
    FOrdinalPosition := Source.OrdinalPosition;
  end;
end;

{ TSchemaIndex }

constructor TSchemaIndex.Create;
begin
  inherited Create;
  FName := '';
  FTableName := '';
  FIsUnique := False;
  FIsPrimary := False;
  FIndexType := 'BTREE';
  FColumns := TStringList.Create;
end;

destructor TSchemaIndex.Destroy;
begin
  FColumns.Free;
  //inherited Destroy;
end;

procedure TSchemaIndex.Assign(Source: TSchemaIndex);
begin
  if Assigned(Source) then
  begin
    FName := Source.Name;
    FTableName := Source.TableName;
    FIsUnique := Source.IsUnique;
    FIsPrimary := Source.IsPrimary;
    FIndexType := Source.IndexType;
    FColumns.Assign(Source.Columns);
  end;
end;

{ TSchemaForeignKey }

constructor TSchemaForeignKey.Create;
begin
  inherited Create;
  FName := '';
  FTableName := '';
  FColumnNames := TStringList.Create;
  FRefTableName := '';
  FRefColumnNames := TStringList.Create;
  FOnUpdate := 'NO ACTION';
  FOnDelete := 'NO ACTION';
end;

destructor TSchemaForeignKey.Destroy;
begin
  FColumnNames.Free;
  FRefColumnNames.Free;
  //inherited Destroy;
end;

procedure TSchemaForeignKey.Assign(Source: TSchemaForeignKey);
begin
  if Assigned(Source) then
  begin
    FName := Source.Name;
    FTableName := Source.TableName;
    FColumnNames.Assign(Source.ColumnNames);
    FRefTableName := Source.RefTableName;
    FRefColumnNames.Assign(Source.RefColumnNames);
    FOnUpdate := Source.OnUpdate;
    FOnDelete := Source.OnDelete;
  end;
end;

{ TSchemaObject }

constructor TSchemaObject.Create;
begin
  inherited Create;
  FName := '';
  FDatabaseName := '';
  FSchemaName := '';
  FObjectType := sotTable;
  FDDL := '';
  FRowCount := 0;
  FComment := '';
  FParent := nil;
  FChildren := TSchemaObjectList.Create(True);
  FColumns := TSchemaColumnList.Create(True);
  FIndexes := TSchemaIndexList.Create(True);
  FFreqForeignKeys := TSchemaForeignKeyList.Create(True);
end;

destructor TSchemaObject.Destroy;
begin
  FChildren.Free;
  FColumns.Free;
  FIndexes.Free;
  FFreqForeignKeys.Free;
  //inherited Destroy;
end;

procedure TSchemaObject.Clear;
begin
  FName := '';
  FDatabaseName := '';
  FSchemaName := '';
  FDDL := '';
  FRowCount := 0;
  FComment := '';
  FChildren.Clear;
  FColumns.Clear;
  FIndexes.Clear;
  FFreqForeignKeys.Clear;
end;

end.s

