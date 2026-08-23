unit uLocalStorage;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, ZConnection, ZDataset,
  uAppConst, uAppTypes, uAppUtils,
  uModelConnection, uModelQueryHistory,
  uStorageMigrator, uStorageSeeder;

type
  { TLocalStorage }
  TLocalStorage = class
  private
    FConnection: TZConnection;
    FDatabasePath: string;
    FIsInitialized: Boolean;

    procedure InitConnection;
    procedure EnsureInitialized;
    function GetLastInsertRowID: Int64;
  public
    constructor Create(const ADBPath: string = '');
    destructor Destroy; override;

    procedure Initialize;
    procedure Close;

    // Pengaturan Aplikasi (app_settings)
    function GetSetting(const AKey: string; const ADefault: string = ''): string;
    function GetSettingInt(const AKey: string; const ADefault: Integer = 0): Integer;
    function GetSettingBool(const AKey: string; const ADefault: Boolean = False): Boolean;
    procedure SetSetting(const AKey, AValue: string; const ADataType: string = 'STRING'; const ADescription: string = '');

    // Profil & Grup Koneksi
    procedure LoadGroups(AList: TConnectionGroupList);
    function SaveGroup(AGroup: TConnectionGroup): Boolean;
    function DeleteGroup(const AID: Int64): Boolean;

    procedure LoadProfiles(AList: TConnectionProfileList; const AGroupID: Int64 = -1);
    function LoadProfile(const AID: Int64; AProfile: TConnectionProfile): Boolean;
    function SaveProfile(AProfile: TConnectionProfile): Boolean;
    function DeleteProfile(const AID: Int64): Boolean;

    // Riwayat Query & Snippet
    procedure LoadHistory(AList: TQueryHistoryList; const AConnectionID: Int64 = -1; const ALimit: Integer = 500);
    function AddHistory(AItem: TQueryHistoryItem): Boolean;
    function SetHistoryBookmark(const AID: Int64; const ABookmarked: Boolean): Boolean;
    procedure ClearHistory(const AConnectionID: Int64 = -1);

    procedure LoadSnippets(AList: TQuerySnippetList; const ADriverTarget: string = '');
    function SaveSnippet(ASnippet: TQuerySnippet): Boolean;
    function DeleteSnippet(const AID: Int64): Boolean;

    // Tag Query
    procedure LoadTags(AList: TQueryTagList);

    property Connection: TZConnection read FConnection;
    property IsInitialized: Boolean read FIsInitialized;
  end;

function LocalStorage: TLocalStorage;

implementation

var
  GLocalStorage: TLocalStorage = nil;

function LocalStorage: TLocalStorage;
begin
  if not Assigned(GLocalStorage) then
    GLocalStorage := TLocalStorage.Create;
  Result := GLocalStorage;
end;

{ TLocalStorage }

constructor TLocalStorage.Create(const ADBPath: string);
begin
  inherited Create;
  if ADBPath <> '' then
    FDatabasePath := ADBPath
  else
    FDatabasePath := GetInternalDatabasePath;

  FIsInitialized := False;
  InitConnection;
end;

destructor TLocalStorage.Destroy;
begin
  Close;
  FConnection.Free;
  //inherited Destroy;
end;

procedure TLocalStorage.InitConnection;
begin
  FConnection := TZConnection.Create(nil);
  FConnection.Protocol := 'sqlite';
  FConnection.Database := FDatabasePath;
  FConnection.Properties.Add('foreign_keys=ON');
  FConnection.Properties.Add('busy_timeout=5000');
  FConnection.AutoCommit := True;
end;

procedure TLocalStorage.EnsureInitialized;
begin
  if not FIsInitialized then
    Initialize;
end;

function TLocalStorage.GetLastInsertRowID: Int64;
var
  Qry: TZQuery;
begin
  Result := 0;
  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text := 'SELECT last_insert_rowid() AS last_id;';
    Qry.Open;
    if not Qry.IsEmpty then
      Result := Qry.FieldByName('last_id').AsLargeInt;
  finally
    Qry.Free;
  end;
end;

procedure TLocalStorage.Initialize;
begin
  if FIsInitialized then Exit;

  EnsureDirectoryExists(ExtractFilePath(FDatabasePath));
  FConnection.Connect;

  // Eksekusi migrasi skema dan inisialisasi default
  TStorageMigrator.RunMigrations(FConnection);
  TStorageSeeder.SeedAll(FConnection);

  FIsInitialized := True;
end;

procedure TLocalStorage.Close;
begin
  if Assigned(FConnection) and FConnection.Connected then
    FConnection.Disconnect;
  FIsInitialized := False;
end;

{ --- Settings --- }

function TLocalStorage.GetSetting(const AKey: string; const ADefault: string): string;
var
  Qry: TZQuery;
begin
  EnsureInitialized;
  Result := ADefault;
  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text := 'SELECT value FROM app_settings WHERE key = :key LIMIT 1;';
    Qry.ParamByName('key').AsString := AKey;
    Qry.Open;
    if not Qry.IsEmpty then
      Result := Qry.FieldByName('value').AsString;
  finally
    Qry.Free;
  end;
end;

function TLocalStorage.GetSettingInt(const AKey: string; const ADefault: Integer): Integer;
begin
  Result := StrToIntDef(GetSetting(AKey, IntToStr(ADefault)), ADefault);
end;

function TLocalStorage.GetSettingBool(const AKey: string; const ADefault: Boolean): Boolean;
var
  S: string;
begin
  S := GetSetting(AKey, BoolToStr(ADefault, '1', '0'));
  Result := (S = '1') or SameText(S, 'true');
end;

procedure TLocalStorage.SetSetting(const AKey, AValue: string; const ADataType: string; const ADescription: string);
var
  Qry: TZQuery;
begin
  EnsureInitialized;
  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'INSERT INTO app_settings (key, value, data_type, description, updated_at) ' +
      'VALUES (:key, :value, :dtype, :descr, CURRENT_TIMESTAMP) ' +
      'ON CONFLICT(key) DO UPDATE SET ' +
      'value = excluded.value, ' +
      'data_type = COALESCE(NULLIF(:dtype, ''''), app_settings.data_type), ' +
      'description = COALESCE(NULLIF(:descr, ''''), app_settings.description), ' +
      'updated_at = CURRENT_TIMESTAMP;';
    Qry.ParamByName('key').AsString := AKey;
    Qry.ParamByName('value').AsString := AValue;
    Qry.ParamByName('dtype').AsString := ADataType;
    Qry.ParamByName('descr').AsString := ADescription;
    Qry.ExecSQL;
  finally
    Qry.Free;
  end;
end;

{ --- Connection Groups --- }

procedure TLocalStorage.LoadGroups(AList: TConnectionGroupList);
var
  Qry: TZQuery;
  Item: TConnectionGroup;
begin
  EnsureInitialized;
  AList.Clear;
  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text := 'SELECT id, name, sort_order, created_at FROM connection_groups ORDER BY sort_order, name;';
    Qry.Open;
    while not Qry.EOF do
    begin
      Item := TConnectionGroup.Create;
      Item.ID := Qry.FieldByName('id').AsLargeInt;
      Item.Name := Qry.FieldByName('name').AsString;
      Item.SortOrder := Qry.FieldByName('sort_order').AsInteger;
      Item.CreatedAt := Qry.FieldByName('created_at').AsDateTime;
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

function TLocalStorage.SaveGroup(AGroup: TConnectionGroup): Boolean;
var
  Qry: TZQuery;
begin
  EnsureInitialized;
  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    if AGroup.ID <= 0 then
    begin
      Qry.SQL.Text :=
        'INSERT INTO connection_groups (name, sort_order, created_at) ' +
        'VALUES (:name, :sort_order, CURRENT_TIMESTAMP);';
      Qry.ParamByName('name').AsString := AGroup.Name;
      Qry.ParamByName('sort_order').AsInteger := AGroup.SortOrder;
      Qry.ExecSQL;
      AGroup.ID := GetLastInsertRowID;
    end
    else
    begin
      Qry.SQL.Text :=
        'UPDATE connection_groups SET name = :name, sort_order = :sort_order WHERE id = :id;';
      Qry.ParamByName('id').AsLargeInt := AGroup.ID;
      Qry.ParamByName('name').AsString := AGroup.Name;
      Qry.ParamByName('sort_order').AsInteger := AGroup.SortOrder;
      Qry.ExecSQL;
    end;
    Result := True;
  finally
    Qry.Free;
  end;
end;

function TLocalStorage.DeleteGroup(const AID: Int64): Boolean;
var
  Qry: TZQuery;
begin
  EnsureInitialized;
  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text := 'DELETE FROM connection_groups WHERE id = :id;';
    Qry.ParamByName('id').AsLargeInt := AID;
    Qry.ExecSQL;
    Result := True;
  finally
    Qry.Free;
  end;
end;

{ --- Connection Profiles --- }

procedure TLocalStorage.LoadProfiles(AList: TConnectionProfileList; const AGroupID: Int64);
var
  Qry: TZQuery;
  Item: TConnectionProfile;
begin
  EnsureInitialized;
  AList.Clear;
  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    if AGroupID > 0 then
    begin
      Qry.SQL.Text := 'SELECT * FROM connection_profiles WHERE group_id = :gid ORDER BY is_favorite DESC, name;';
      Qry.ParamByName('gid').AsLargeInt := AGroupID;
    end
    else
      Qry.SQL.Text := 'SELECT * FROM connection_profiles ORDER BY is_favorite DESC, name;';

    Qry.Open;
    while not Qry.EOF do
    begin
      Item := TConnectionProfile.Create;
      Item.ID := Qry.FieldByName('id').AsLargeInt;
      Item.GroupID := Qry.FieldByName('group_id').AsLargeInt;
      Item.Name := Qry.FieldByName('name').AsString;
      Item.DriverType := StringToDriverType(Qry.FieldByName('driver_type').AsString);
      Item.Host := Qry.FieldByName('host').AsString;
      Item.Port := Qry.FieldByName('port').AsInteger;
      Item.DatabaseName := Qry.FieldByName('database_name').AsString;
      Item.Charset := Qry.FieldByName('charset').AsString;
      Item.Username := Qry.FieldByName('username').AsString;
      Item.PasswordEnc := Qry.FieldByName('password_enc').AsString;
      Item.TimeoutSec := Qry.FieldByName('timeout_sec').AsInteger;
      Item.SSLMode := StringToSSLMode(Qry.FieldByName('ssl_mode').AsString);
      Item.SSHEnabled := Qry.FieldByName('ssh_enabled').AsInteger = 1;
      Item.SSHHost := Qry.FieldByName('ssh_host').AsString;
      Item.SSHPort := Qry.FieldByName('ssh_port').AsInteger;
      Item.SSHUser := Qry.FieldByName('ssh_user').AsString;
      Item.SSHAuthType := StringToSSHAuthType(Qry.FieldByName('ssh_auth_type').AsString);
      Item.SSHKeyPath := Qry.FieldByName('ssh_key_path').AsString;
      Item.SSHPassEnc := Qry.FieldByName('ssh_pass_enc').AsString;
      Item.EnvTag := StringToEnvTag(Qry.FieldByName('env_tag').AsString);
      Item.ColorHex := Qry.FieldByName('color_hex').AsString;
      Item.IsFavorite := Qry.FieldByName('is_favorite').AsInteger = 1;
      Item.CreatedAt := Qry.FieldByName('created_at').AsDateTime;
      Item.UpdatedAt := Qry.FieldByName('updated_at').AsDateTime;
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

function TLocalStorage.LoadProfile(const AID: Int64; AProfile: TConnectionProfile): Boolean;
var
  Qry: TZQuery;
begin
  EnsureInitialized;
  Result := False;
  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text := 'SELECT * FROM connection_profiles WHERE id = :id LIMIT 1;';
    Qry.ParamByName('id').AsLargeInt := AID;
    Qry.Open;
    if not Qry.IsEmpty then
    begin
      AProfile.ID := Qry.FieldByName('id').AsLargeInt;
      AProfile.GroupID := Qry.FieldByName('group_id').AsLargeInt;
      AProfile.Name := Qry.FieldByName('name').AsString;
      AProfile.DriverType := StringToDriverType(Qry.FieldByName('driver_type').AsString);
      AProfile.Host := Qry.FieldByName('host').AsString;
      AProfile.Port := Qry.FieldByName('port').AsInteger;
      AProfile.DatabaseName := Qry.FieldByName('database_name').AsString;
      AProfile.Charset := Qry.FieldByName('charset').AsString;
      AProfile.Username := Qry.FieldByName('username').AsString;
      AProfile.PasswordEnc := Qry.FieldByName('password_enc').AsString;
      AProfile.TimeoutSec := Qry.FieldByName('timeout_sec').AsInteger;
      AProfile.SSLMode := StringToSSLMode(Qry.FieldByName('ssl_mode').AsString);
      AProfile.SSHEnabled := Qry.FieldByName('ssh_enabled').AsInteger = 1;
      AProfile.SSHHost := Qry.FieldByName('ssh_host').AsString;
      AProfile.SSHPort := Qry.FieldByName('ssh_port').AsInteger;
      AProfile.SSHUser := Qry.FieldByName('ssh_user').AsString;
      AProfile.SSHAuthType := StringToSSHAuthType(Qry.FieldByName('ssh_auth_type').AsString);
      AProfile.SSHKeyPath := Qry.FieldByName('ssh_key_path').AsString;
      AProfile.SSHPassEnc := Qry.FieldByName('ssh_pass_enc').AsString;
      AProfile.EnvTag := StringToEnvTag(Qry.FieldByName('env_tag').AsString);
      AProfile.ColorHex := Qry.FieldByName('color_hex').AsString;
      AProfile.IsFavorite := Qry.FieldByName('is_favorite').AsInteger = 1;
      AProfile.CreatedAt := Qry.FieldByName('created_at').AsDateTime;
      AProfile.UpdatedAt := Qry.FieldByName('updated_at').AsDateTime;
      Result := True;
    end;
  finally
    Qry.Free;
  end;
end;

function TLocalStorage.SaveProfile(AProfile: TConnectionProfile): Boolean;
var
  Qry: TZQuery;
begin
  EnsureInitialized;
  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    if AProfile.ID <= 0 then
    begin
      Qry.SQL.Text :=
        'INSERT INTO connection_profiles (' +
        'group_id, name, driver_type, host, port, database_name, charset, username, password_enc, ' +
        'timeout_sec, ssl_mode, ssh_enabled, ssh_host, ssh_port, ssh_user, ssh_auth_type, ' +
        'ssh_key_path, ssh_pass_enc, env_tag, color_hex, is_favorite, created_at, updated_at) ' +
        'VALUES (' +
        ':group_id, :name, :driver_type, :host, :port, :database_name, :charset, :username, :password_enc, ' +
        ':timeout_sec, :ssl_mode, :ssh_enabled, :ssh_host, :ssh_port, :ssh_user, :ssh_auth_type, ' +
        ':ssh_key_path, :ssh_pass_enc, :env_tag, :color_hex, :is_favorite, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);';
    end
    else
    begin
      Qry.SQL.Text :=
        'UPDATE connection_profiles SET ' +
        'group_id = :group_id, name = :name, driver_type = :driver_type, host = :host, port = :port, ' +
        'database_name = :database_name, charset = :charset, username = :username, password_enc = :password_enc, ' +
        'timeout_sec = :timeout_sec, ssl_mode = :ssl_mode, ssh_enabled = :ssh_enabled, ssh_host = :ssh_host, ' +
        'ssh_port = :ssh_port, ssh_user = :ssh_user, ssh_auth_type = :ssh_auth_type, ssh_key_path = :ssh_key_path, ' +
        'ssh_pass_enc = :ssh_pass_enc, env_tag = :env_tag, color_hex = :color_hex, is_favorite = :is_favorite, ' +
        'updated_at = CURRENT_TIMESTAMP WHERE id = :id;';
      Qry.ParamByName('id').AsLargeInt := AProfile.ID;
    end;

    if AProfile.GroupID > 0 then
      Qry.ParamByName('group_id').AsLargeInt := AProfile.GroupID
    else
      Qry.ParamByName('group_id').Clear;

    Qry.ParamByName('name').AsString := AProfile.Name;
    Qry.ParamByName('driver_type').AsString := DriverTypeToString(AProfile.DriverType);
    Qry.ParamByName('host').AsString := AProfile.Host;
    Qry.ParamByName('port').AsInteger := AProfile.Port;
    Qry.ParamByName('database_name').AsString := AProfile.DatabaseName;
    Qry.ParamByName('charset').AsString := AProfile.Charset;
    Qry.ParamByName('username').AsString := AProfile.Username;
    Qry.ParamByName('password_enc').AsString := AProfile.PasswordEnc;
    Qry.ParamByName('timeout_sec').AsInteger := AProfile.TimeoutSec;
    Qry.ParamByName('ssl_mode').AsString := SSLModeToString(AProfile.SSLMode);
    Qry.ParamByName('ssh_enabled').AsInteger := Ord(AProfile.SSHEnabled);
    Qry.ParamByName('ssh_host').AsString := AProfile.SSHHost;
    Qry.ParamByName('ssh_port').AsInteger := AProfile.SSHPort;
    Qry.ParamByName('ssh_user').AsString := AProfile.SSHUser;
    Qry.ParamByName('ssh_auth_type').AsString := SSHAuthTypeToString(AProfile.SSHAuthType);
    Qry.ParamByName('ssh_key_path').AsString := AProfile.SSHKeyPath;
    Qry.ParamByName('ssh_pass_enc').AsString := AProfile.SSHPassEnc;
    Qry.ParamByName('env_tag').AsString := EnvTagToString(AProfile.EnvTag);
    Qry.ParamByName('color_hex').AsString := AProfile.ColorHex;
    Qry.ParamByName('is_favorite').AsInteger := Ord(AProfile.IsFavorite);

    Qry.ExecSQL;
    if AProfile.ID <= 0 then
      AProfile.ID := GetLastInsertRowID;

    Result := True;
  finally
    Qry.Free;
  end;
end;

function TLocalStorage.DeleteProfile(const AID: Int64): Boolean;
var
  Qry: TZQuery;
begin
  EnsureInitialized;
  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text := 'DELETE FROM connection_profiles WHERE id = :id;';
    Qry.ParamByName('id').AsLargeInt := AID;
    Qry.ExecSQL;
    Result := True;
  finally
    Qry.Free;
  end;
end;

{ --- Query History --- }

procedure TLocalStorage.LoadHistory(AList: TQueryHistoryList; const AConnectionID: Int64; const ALimit: Integer);
var
  Qry: TZQuery;
  Item: TQueryHistoryItem;
begin
  EnsureInitialized;
  AList.Clear;
  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    if AConnectionID > 0 then
    begin
      Qry.SQL.Text :=
        'SELECT * FROM query_history WHERE connection_id = :cid ORDER BY executed_at DESC LIMIT :lim;';
      Qry.ParamByName('cid').AsLargeInt := AConnectionID;
    end
    else
    begin
      Qry.SQL.Text :=
        'SELECT * FROM query_history ORDER BY executed_at DESC LIMIT :lim;';
    end;
    Qry.ParamByName('lim').AsInteger := ALimit;

    Qry.Open;
    while not Qry.EOF do
    begin
      Item := TQueryHistoryItem.Create;
      Item.ID := Qry.FieldByName('id').AsLargeInt;
      Item.ConnectionID := Qry.FieldByName('connection_id').AsLargeInt;
      Item.DatabaseTarget := Qry.FieldByName('database_target').AsString;
      Item.QueryText := Qry.FieldByName('query_text').AsString;
      Item.ExecutionTimeMS := Qry.FieldByName('execution_time_ms').AsLargeInt;
      Item.RowsAffected := Qry.FieldByName('rows_affected').AsLargeInt;
      Item.IsSuccess := Qry.FieldByName('is_success').AsInteger = 1;
      Item.ErrorMessage := Qry.FieldByName('error_message').AsString;
      Item.ExecutedAt := Qry.FieldByName('executed_at').AsDateTime;
      Item.IsBookmarked := Qry.FieldByName('is_bookmarked').AsInteger = 1;
      Item.CustomLabel := Qry.FieldByName('custom_label').AsString;
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

function TLocalStorage.AddHistory(AItem: TQueryHistoryItem): Boolean;
var
  Qry: TZQuery;
begin
  EnsureInitialized;
  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'INSERT INTO query_history (connection_id, database_target, query_text, ' +
      'execution_time_ms, rows_affected, is_success, error_message, executed_at, is_bookmarked, custom_label) ' +
      'VALUES (:cid, :db, :sql, :time_ms, :rows, :succ, :err, CURRENT_TIMESTAMP, :bm, :lbl);';

    if AItem.ConnectionID > 0 then
      Qry.ParamByName('cid').AsLargeInt := AItem.ConnectionID
    else
      Qry.ParamByName('cid').Clear;

    Qry.ParamByName('db').AsString := AItem.DatabaseTarget;
    Qry.ParamByName('sql').AsString := AItem.QueryText;
    Qry.ParamByName('time_ms').AsLargeInt := AItem.ExecutionTimeMS;
    Qry.ParamByName('rows').AsLargeInt := AItem.RowsAffected;
    Qry.ParamByName('succ').AsInteger := Ord(AItem.IsSuccess);
    Qry.ParamByName('err').AsString := AItem.ErrorMessage;
    Qry.ParamByName('bm').AsInteger := Ord(AItem.IsBookmarked);
    Qry.ParamByName('lbl').AsString := AItem.CustomLabel;

    Qry.ExecSQL;
    AItem.ID := GetLastInsertRowID;
    Result := True;
  finally
    Qry.Free;
  end;
end;

function TLocalStorage.SetHistoryBookmark(const AID: Int64; const ABookmarked: Boolean): Boolean;
var
  Qry: TZQuery;
begin
  EnsureInitialized;
  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text := 'UPDATE query_history SET is_bookmarked = :bm WHERE id = :id;';
    Qry.ParamByName('id').AsLargeInt := AID;
    Qry.ParamByName('bm').AsInteger := Ord(ABookmarked);
    Qry.ExecSQL;
    Result := True;
  finally
    Qry.Free;
  end;
end;

procedure TLocalStorage.ClearHistory(const AConnectionID: Int64);
var
  Qry: TZQuery;
begin
  EnsureInitialized;
  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    if AConnectionID > 0 then
    begin
      Qry.SQL.Text := 'DELETE FROM query_history WHERE connection_id = :cid AND is_bookmarked = 0;';
      Qry.ParamByName('cid').AsLargeInt := AConnectionID;
    end
    else
      Qry.SQL.Text := 'DELETE FROM query_history WHERE is_bookmarked = 0;';
    Qry.ExecSQL;
  finally
    Qry.Free;
  end;
end;

{ --- Query Snippets --- }

procedure TLocalStorage.LoadSnippets(AList: TQuerySnippetList; const ADriverTarget: string);
var
  Qry: TZQuery;
  Item: TQuerySnippet;
begin
  EnsureInitialized;
  AList.Clear;
  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    if (ADriverTarget <> '') and not SameText(ADriverTarget, 'ALL') then
    begin
      Qry.SQL.Text := 'SELECT * FROM query_snippets WHERE target_driver IN (''ALL'', :drv) ORDER BY title;';
      Qry.ParamByName('drv').AsString := ADriverTarget;
    end
    else
      Qry.SQL.Text := 'SELECT * FROM query_snippets ORDER BY title;';

    Qry.Open;
    while not Qry.EOF do
    begin
      Item := TQuerySnippet.Create;
      Item.ID := Qry.FieldByName('id').AsLargeInt;
      Item.Title := Qry.FieldByName('title').AsString;
      Item.Description := Qry.FieldByName('description').AsString;
      Item.TargetDriver := Qry.FieldByName('target_driver').AsString;
      Item.SQLContent := Qry.FieldByName('sql_content').AsString;
      Item.ShortcutPrefix := Qry.FieldByName('shortcut_prefix').AsString;
      Item.CreatedAt := Qry.FieldByName('created_at').AsDateTime;
      Item.UpdatedAt := Qry.FieldByName('updated_at').AsDateTime;
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

function TLocalStorage.SaveSnippet(ASnippet: TQuerySnippet): Boolean;
var
  Qry: TZQuery;
begin
  EnsureInitialized;
  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    if ASnippet.ID <= 0 then
    begin
      Qry.SQL.Text :=
        'INSERT INTO query_snippets (title, description, target_driver, sql_content, shortcut_prefix, created_at, updated_at) ' +
        'VALUES (:title, :descr, :drv, :sql, :prefix, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);';
    end
    else
    begin
      Qry.SQL.Text :=
        'UPDATE query_snippets SET title = :title, description = :descr, target_driver = :drv, ' +
        'sql_content = :sql, shortcut_prefix = :prefix, updated_at = CURRENT_TIMESTAMP WHERE id = :id;';
      Qry.ParamByName('id').AsLargeInt := ASnippet.ID;
    end;

    Qry.ParamByName('title').AsString := ASnippet.Title;
    Qry.ParamByName('descr').AsString := ASnippet.Description;
    Qry.ParamByName('drv').AsString := ASnippet.TargetDriver;
    Qry.ParamByName('sql').AsString := ASnippet.SQLContent;
    Qry.ParamByName('prefix').AsString := ASnippet.ShortcutPrefix;

    Qry.ExecSQL;
    if ASnippet.ID <= 0 then
      ASnippet.ID := GetLastInsertRowID;

    Result := True;
  finally
    Qry.Free;
  end;
end;

function TLocalStorage.DeleteSnippet(const AID: Int64): Boolean;
var
  Qry: TZQuery;
begin
  EnsureInitialized;
  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text := 'DELETE FROM query_snippets WHERE id = :id;';
    Qry.ParamByName('id').AsLargeInt := AID;
    Qry.ExecSQL;
    Result := True;
  finally
    Qry.Free;
  end;
end;

{ --- Tags --- }

procedure TLocalStorage.LoadTags(AList: TQueryTagList);
var
  Qry: TZQuery;
  Item: TQueryTag;
begin
  EnsureInitialized;
  AList.Clear;
  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text := 'SELECT id, name, color_hex, created_at FROM query_tags ORDER BY name;';
    Qry.Open;
    while not Qry.EOF do
    begin
      Item := TQueryTag.Create;
      Item.ID := Qry.FieldByName('id').AsLargeInt;
      Item.Name := Qry.FieldByName('name').AsString;
      Item.ColorHex := Qry.FieldByName('color_hex').AsString;
      Item.CreatedAt := Qry.FieldByName('created_at').AsDateTime;
      AList.Add(Item);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

finalization
  if Assigned(GLocalStorage) then
    FreeAndNil(GLocalStorage);

end.
