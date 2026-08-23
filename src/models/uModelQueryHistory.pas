unit uModelQueryHistory;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fgl, uAppTypes, uAppConst;

type
  { TQueryTag }
  TQueryTag = class
  private
    FID: Int64;
    FName: string;
    FColorHex: string;
    FCreatedAt: TDateTime;
  public
    constructor Create;
    procedure Assign(Source: TQueryTag);
    function Clone: TQueryTag;

    property ID: Int64 read FID write FID;
    property Name: string read FName write FName;
    property ColorHex: string read FColorHex write FColorHex;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
  end;

  { TQueryHistoryItem }
  TQueryHistoryItem = class
  private
    FID: Int64;
    FConnectionID: Int64;
    FDatabaseTarget: string;
    FQueryText: string;
    FExecutionTimeMS: Int64;
    FRowsAffected: Int64;
    FIsSuccess: Boolean;
    FErrorMessage: string;
    FExecutedAt: TDateTime;
    FIsBookmarked: Boolean;
    FCustomLabel: string;
  public
    constructor Create;
    procedure Assign(Source: TQueryHistoryItem);
    function Clone: TQueryHistoryItem;

    property ID: Int64 read FID write FID;
    property ConnectionID: Int64 read FConnectionID write FConnectionID;
    property DatabaseTarget: string read FDatabaseTarget write FDatabaseTarget;
    property QueryText: string read FQueryText write FQueryText;
    property ExecutionTimeMS: Int64 read FExecutionTimeMS write FExecutionTimeMS;
    property RowsAffected: Int64 read FRowsAffected write FRowsAffected;
    property IsSuccess: Boolean read FIsSuccess write FIsSuccess;
    property ErrorMessage: string read FErrorMessage write FErrorMessage;
    property ExecutedAt: TDateTime read FExecutedAt write FExecutedAt;
    property IsBookmarked: Boolean read FIsBookmarked write FIsBookmarked;
    property CustomLabel: string read FCustomLabel write FCustomLabel;
  end;

  { TQuerySnippet }
  TQuerySnippet = class
  private
    FID: Int64;
    FTitle: string;
    FDescription: string;
    FTargetDriver: string;
    FSQLContent: string;
    FShortcutPrefix: string;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    constructor Create;
    procedure Assign(Source: TQuerySnippet);
    function Clone: TQuerySnippet;

    property ID: Int64 read FID write FID;
    property Title: string read FTitle write FTitle;
    property Description: string read FDescription write FDescription;
    property TargetDriver: string read FTargetDriver write FTargetDriver;
    property SQLContent: string read FSQLContent write FSQLContent;
    property ShortcutPrefix: string read FShortcutPrefix write FShortcutPrefix;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  // Daftar Generik
  TQueryTagList = specialize TFPGObjectList<TQueryTag>;
  TQueryHistoryList = specialize TFPGObjectList<TQueryHistoryItem>;
  TQuerySnippetList = specialize TFPGObjectList<TQuerySnippet>;

implementation

{ TQueryTag }

constructor TQueryTag.Create;
begin
  inherited Create;
  FID := 0;
  FName := '';
  FColorHex := '#6C757D';
  FCreatedAt := Now;
end;

procedure TQueryTag.Assign(Source: TQueryTag);
begin
  if Assigned(Source) then
  begin
    FID := Source.ID;
    FName := Source.Name;
    FColorHex := Source.ColorHex;
    FCreatedAt := Source.CreatedAt;
  end;
end;

function TQueryTag.Clone: TQueryTag;
begin
  Result := TQueryTag.Create;
  Result.Assign(Self);
end;

{ TQueryHistoryItem }

constructor TQueryHistoryItem.Create;
begin
  inherited Create;
  FID := 0;
  FConnectionID := 0;
  FDatabaseTarget := '';
  FQueryText := '';
  FExecutionTimeMS := 0;
  FRowsAffected := 0;
  FIsSuccess := True;
  FErrorMessage := '';
  FExecutedAt := Now;
  FIsBookmarked := False;
  FCustomLabel := '';
end;

procedure TQueryHistoryItem.Assign(Source: TQueryHistoryItem);
begin
  if Assigned(Source) then
  begin
    FID := Source.ID;
    FConnectionID := Source.ConnectionID;
    FDatabaseTarget := Source.DatabaseTarget;
    FQueryText := Source.QueryText;
    FExecutionTimeMS := Source.ExecutionTimeMS;
    FRowsAffected := Source.RowsAffected;
    FIsSuccess := Source.IsSuccess;
    FErrorMessage := Source.ErrorMessage;
    FExecutedAt := Source.ExecutedAt;
    FIsBookmarked := Source.IsBookmarked;
    FCustomLabel := Source.CustomLabel;
  end;
end;

function TQueryHistoryItem.Clone: TQueryHistoryItem;
begin
  Result := TQueryHistoryItem.Create;
  Result.Assign(Self);
end;

{ TQuerySnippet }

constructor TQuerySnippet.Create;
begin
  inherited Create;
  FID := 0;
  FTitle := '';
  FDescription := '';
  FTargetDriver := 'ALL';
  FSQLContent := '';
  FShortcutPrefix := '';
  FCreatedAt := Now;
  FUpdatedAt := Now;
end;

procedure TQuerySnippet.Assign(Source: TQuerySnippet);
begin
  if Assigned(Source) then
  begin
    FID := Source.ID;
    FTitle := Source.Title;
    FDescription := Source.Description;
    FTargetDriver := Source.TargetDriver;
    FSQLContent := Source.SQLContent;
    FShortcutPrefix := Source.ShortcutPrefix;
    FCreatedAt := Source.CreatedAt;
    FUpdatedAt := Source.UpdatedAt;
  end;
end;

function TQuerySnippet.Clone: TQuerySnippet;
begin
  Result := TQuerySnippet.Create;
  Result.Assign(Self);
end;

end.


