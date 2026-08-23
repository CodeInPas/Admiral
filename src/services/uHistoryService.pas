unit uHistoryService;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  uAppConst, uAppTypes, uDBTypes,
  uLocalStorage, uModelQueryHistory;

type
  { THistoryService }
  THistoryService = class
  private
    FStorage: TLocalStorage;
  public
    constructor Create(AStorage: TLocalStorage = nil);

    // Pencatatan & Pengelolaan Riwayat Query
    function LogExecution(const AConnectionID: Int64; const ADatabaseTarget, ASQL: string;
      const AResult: TDBQueryResult; const ACustomLabel: string = ''): Boolean;
    procedure GetHistory(AList: TQueryHistoryList; const AConnectionID: Int64 = -1;
      const ALimit: Integer = 200; const AFilterText: string = ''; const AOnlyBookmarked: Boolean = False);
    function ToggleBookmark(const AHistoryID: Int64; const AIsBookmarked: Boolean): Boolean;
    procedure ClearHistory(const AConnectionID: Int64 = -1);
    procedure PruneHistory;

    // Pengelolaan Snippets
    procedure GetSnippets(AList: TQuerySnippetList; const ADriverTarget: string = ''; const AFilterText: string = '');
    function SaveSnippet(ASnippet: TQuerySnippet): Boolean;
    function DeleteSnippet(const ASnippetID: Int64): Boolean;

    // Pengelolaan Tag
    procedure GetTags(AList: TQueryTagList);

    property Storage: TLocalStorage read FStorage write FStorage;
  end;

function HistoryService: THistoryService;

implementation

var
  GHistoryService: THistoryService = nil;

function HistoryService: THistoryService;
begin
  if not Assigned(GHistoryService) then
    GHistoryService := THistoryService.Create;
  Result := GHistoryService;
end;

{ THistoryService }

constructor THistoryService.Create(AStorage: TLocalStorage);
begin
  inherited Create;
  if Assigned(AStorage) then
    FStorage := AStorage
  else
    FStorage := LocalStorage;
end;

function THistoryService.LogExecution(const AConnectionID: Int64; const ADatabaseTarget, ASQL: string;
  const AResult: TDBQueryResult; const ACustomLabel: string): Boolean;
var
  Item: TQueryHistoryItem;
begin
  Result := False;
  if Trim(ASQL) = '' then Exit;

  Item := TQueryHistoryItem.Create;
  try
    Item.ConnectionID := AConnectionID;
    Item.DatabaseTarget := ADatabaseTarget;
    Item.QueryText := Trim(ASQL);
    Item.ExecutionTimeMS := AResult.ExecutionTimeMS;
    Item.RowsAffected := AResult.RowsAffected;
    Item.IsSuccess := AResult.IsSuccess;
    Item.ErrorMessage := AResult.ErrorMessage;
    Item.ExecutedAt := Now;
    Item.IsBookmarked := False;
    Item.CustomLabel := ACustomLabel;

    Result := FStorage.AddHistory(Item);
    PruneHistory;
  finally
    Item.Free;
  end;
end;

procedure THistoryService.GetHistory(AList: TQueryHistoryList; const AConnectionID: Int64;
  const ALimit: Integer; const AFilterText: string; const AOnlyBookmarked: Boolean);
var
  TempList: TQueryHistoryList;
  Item: TQueryHistoryItem;
  I: Integer;
  UpperFilter: string;
  MatchesFilter: Boolean;
begin
  AList.Clear;
  TempList := TQueryHistoryList.Create(True);
  try
    FStorage.LoadHistory(TempList, AConnectionID, ALimit);
    UpperFilter := UpperCase(Trim(AFilterText));

    for I := 0 to TempList.Count - 1 do
    begin
      Item := TempList[I];

      if AOnlyBookmarked and not Item.IsBookmarked then
        Continue;

      if UpperFilter <> '' then
      begin
        MatchesFilter := (Pos(UpperFilter, UpperCase(Item.QueryText)) > 0) or
                         (Pos(UpperFilter, UpperCase(Item.DatabaseTarget)) > 0) or
                         (Pos(UpperFilter, UpperCase(Item.CustomLabel)) > 0);
        if not MatchesFilter then
          Continue;
      end;

      AList.Add(Item.Clone);
    end;
  finally
    TempList.Free;
  end;
end;

function THistoryService.ToggleBookmark(const AHistoryID: Int64; const AIsBookmarked: Boolean): Boolean;
begin
  Result := FStorage.SetHistoryBookmark(AHistoryID, AIsBookmarked);
end;

procedure THistoryService.ClearHistory(const AConnectionID: Int64);
begin
  FStorage.ClearHistory(AConnectionID);
end;

procedure THistoryService.PruneHistory;
var
  MaxEntries: Integer;
begin
  MaxEntries := FStorage.GetSettingInt(SETTING_HISTORY_MAX_ENTRIES, DEFAULT_HISTORY_MAX_ENTRIES);
  if MaxEntries <= 0 then Exit;

  try
    FStorage.Connection.ExecuteDirect(Format(
      'DELETE FROM query_history WHERE is_bookmarked = 0 AND id NOT IN (' +
      '  SELECT id FROM query_history ORDER BY executed_at DESC LIMIT %d' +
      ');', [MaxEntries]
    ));
  except
    // Mengabaikan kegagalan pruning berkala
  end;
end;

procedure THistoryService.GetSnippets(AList: TQuerySnippetList; const ADriverTarget: string; const AFilterText: string);
var
  TempList: TQuerySnippetList;
  Snippet: TQuerySnippet;
  I: Integer;
  UpperFilter: string;
  MatchesFilter: Boolean;
begin
  AList.Clear;
  TempList := TQuerySnippetList.Create(True);
  try
    FStorage.LoadSnippets(TempList, ADriverTarget);
    UpperFilter := UpperCase(Trim(AFilterText));

    for I := 0 to TempList.Count - 1 do
    begin
      Snippet := TempList[I];

      if UpperFilter <> '' then
      begin
        MatchesFilter := (Pos(UpperFilter, UpperCase(Snippet.Title)) > 0) or
                         (Pos(UpperFilter, UpperCase(Snippet.Description)) > 0) or
                         (Pos(UpperFilter, UpperCase(Snippet.SQLContent)) > 0) or
                         (Pos(UpperFilter, UpperCase(Snippet.ShortcutPrefix)) > 0);
        if not MatchesFilter then
          Continue;
      end;

      AList.Add(Snippet.Clone);
    end;
  finally
    TempList.Free;
  end;
end;

function THistoryService.SaveSnippet(ASnippet: TQuerySnippet): Boolean;
begin
  Result := FStorage.SaveSnippet(ASnippet);
end;

function THistoryService.DeleteSnippet(const ASnippetID: Int64): Boolean;
begin
  Result := FStorage.DeleteSnippet(ASnippetID);
end;

procedure THistoryService.GetTags(AList: TQueryTagList);
begin
  FStorage.LoadTags(AList);
end;

finalization
  if Assigned(GHistoryService) then
    FreeAndNil(GHistoryService);

end.
