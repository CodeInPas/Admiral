unit uStorageSeeder;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, ZConnection, ZDataset, uAppConst;

type
  { TStorageSeeder }
  TStorageSeeder = class
  private
    class procedure SeedSettings(AConnection: TZConnection);
    class procedure SeedConnectionGroups(AConnection: TZConnection);
    class procedure SeedSnippets(AConnection: TZConnection);
  public
    class procedure SeedAll(AConnection: TZConnection);
  end;

implementation

{ TStorageSeeder }

class procedure TStorageSeeder.SeedSettings(AConnection: TZConnection);
const
  SQL_INSERT_SETTING =
    'INSERT OR IGNORE INTO app_settings (key, value, data_type, description) VALUES ' +
    '(:key, :val, :dtype, :descr);';
var
  Qry: TZQuery;

  procedure AddSetting(const AKey, AVal, ADataType, ADescr: string);
  begin
    Qry.ParamByName('key').AsString := AKey;
    Qry.ParamByName('val').AsString := AVal;
    Qry.ParamByName('dtype').AsString := ADataType;
    Qry.ParamByName('descr').AsString := ADescr;
    Qry.ExecSQL;
  end;

begin
  Qry := TZQuery.Create(nil);
  try
    Qry.Connection := AConnection;
    Qry.SQL.Text := SQL_INSERT_SETTING;

    AddSetting(SETTING_EDITOR_FONT_NAME, DEFAULT_EDITOR_FONT_NAME, 'STRING', 'Font editor SQL SynEdit');
    AddSetting(SETTING_EDITOR_FONT_SIZE, IntToStr(DEFAULT_EDITOR_FONT_SIZE), 'INTEGER', 'Ukuran font editor');
    AddSetting(SETTING_EDITOR_TAB_WIDTH, IntToStr(DEFAULT_EDITOR_TAB_WIDTH), 'INTEGER', 'Ukuran spasi per indentasi');
    AddSetting(SETTING_EDITOR_AUTO_COMPLETE, BoolToStr(DEFAULT_EDITOR_AUTO_COMPLETE, '1', '0'), 'BOOLEAN', 'Aktifkan auto-completion');
    AddSetting(SETTING_GRID_PAGE_LIMIT, IntToStr(DEFAULT_GRID_PAGE_LIMIT), 'INTEGER', 'Jumlah limit record per fetch');
    AddSetting(SETTING_GRID_NULL_REPRESENTATION, DEFAULT_GRID_NULL_REPRESENTATION, 'STRING', 'Representasi visual nilai NULL');
    AddSetting(SETTING_HISTORY_MAX_ENTRIES, IntToStr(DEFAULT_HISTORY_MAX_ENTRIES), 'INTEGER', 'Maksimal entri riwayat query');
    AddSetting(SETTING_CONFIRM_DESTRUCTIVE_SQL, BoolToStr(DEFAULT_CONFIRM_DESTRUCTIVE_SQL, '1', '0'), 'BOOLEAN', 'Konfirmasi eksekusi query destruktif');
  finally
    Qry.Free;
  end;
end;

class procedure TStorageSeeder.SeedConnectionGroups(AConnection: TZConnection);
begin
  AConnection.ExecuteDirect(
    'INSERT OR IGNORE INTO connection_groups (id, name, sort_order) VALUES ' +
    '(1, ''Local Instances'', 1), ' +
    '(2, ''Remote Servers'', 2);'
  );
end;

class procedure TStorageSeeder.SeedSnippets(AConnection: TZConnection);
const
  SQL_SNIPPETS =
    'INSERT OR IGNORE INTO query_snippets (id, title, description, target_driver, sql_content, shortcut_prefix) VALUES ' +
    '(1, ''Select All Limit 100'', ''Mengambil 100 record pertama dari tabel'', ''ALL'', ''SELECT * FROM ${table_name} LIMIT 100;'', ''sel100''), ' +
    '(2, ''Count Table Rows'', ''Menghitung total baris tabel'', ''ALL'', ''SELECT COUNT(1) AS total_records FROM ${table_name};'', ''cnt''), ' +
    '(3, ''Table Size Summary (PostgreSQL)'', ''Melihat kapasitas penyimpanan tabel'', ''POSTGRESQL'', ''SELECT pg_size_pretty(pg_total_relation_size(''''${table_name}'''')) AS total_size;'', ''pgsize'');';
begin
  AConnection.ExecuteDirect(SQL_SNIPPETS);
end;

class procedure TStorageSeeder.SeedAll(AConnection: TZConnection);
begin
  AConnection.StartTransaction;
  try
    SeedSettings(AConnection);
    SeedConnectionGroups(AConnection);
    SeedSnippets(AConnection);
    AConnection.Commit;
  except
    on E: Exception do
    begin
      if AConnection.InTransaction then
        AConnection.Rollback;
      raise Exception.CreateFmt('Seeding internal storage failed: %s', [E.Message]);
    end;
  end;
end;

end.

