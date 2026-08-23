unit uStorageMigrations;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

type
  { TMigrationStep }
  TMigrationStep = record
    Version: Integer;
    Description: string;
    SQLScript: string;
  end;

  TMigrationStepArray = array of TMigrationStep;

// Mendapatkan seluruh daftar migrasi database internal berurutan
function GetAvailableMigrations: TMigrationStepArray;

implementation

const
  SQL_MIGRATION_V1 =
    'PRAGMA foreign_keys = ON;' + LineEnding +
    'CREATE TABLE IF NOT EXISTS app_settings (' + LineEnding +
    '    key          TEXT PRIMARY KEY,' + LineEnding +
    '    value        TEXT NOT NULL,' + LineEnding +
    '    data_type    TEXT NOT NULL DEFAULT ''STRING'' CHECK (data_type IN (''STRING'', ''INTEGER'', ''BOOLEAN'', ''JSON'')),' + LineEnding +
    '    description  TEXT,' + LineEnding +
    '    updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP' + LineEnding +
    ');' + LineEnding +
    'CREATE TABLE IF NOT EXISTS connection_groups (' + LineEnding +
    '    id           INTEGER PRIMARY KEY AUTOINCREMENT,' + LineEnding +
    '    name         TEXT NOT NULL UNIQUE,' + LineEnding +
    '    sort_order   INTEGER NOT NULL DEFAULT 0,' + LineEnding +
    '    created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP' + LineEnding +
    ');' + LineEnding +
    'CREATE TABLE IF NOT EXISTS connection_profiles (' + LineEnding +
    '    id              INTEGER PRIMARY KEY AUTOINCREMENT,' + LineEnding +
    '    group_id        INTEGER REFERENCES connection_groups(id) ON DELETE SET NULL,' + LineEnding +
    '    name            TEXT NOT NULL,' + LineEnding +
    '    driver_type     TEXT NOT NULL CHECK (driver_type IN (''SQLITE'', ''MYSQL'', ''MARIADB'', ''FIREBIRD'', ''POSTGRESQL'')),' + LineEnding +
    '    host            TEXT,' + LineEnding +
    '    port            INTEGER,' + LineEnding +
    '    database_name   TEXT NOT NULL,' + LineEnding +
    '    charset         TEXT NOT NULL DEFAULT ''UTF8'',' + LineEnding +
    '    username        TEXT,' + LineEnding +
    '    password_enc    TEXT,' + LineEnding +
    '    timeout_sec     INTEGER NOT NULL DEFAULT 15,' + LineEnding +
    '    ssl_mode        TEXT NOT NULL DEFAULT ''DISABLE'' CHECK (ssl_mode IN (''DISABLE'', ''REQUIRE'', ''VERIFY_CA'', ''VERIFY_FULL'')),' + LineEnding +
    '    ssh_enabled     INTEGER NOT NULL DEFAULT 0 CHECK (ssh_enabled IN (0, 1)),' + LineEnding +
    '    ssh_host        TEXT,' + LineEnding +
    '    ssh_port        INTEGER DEFAULT 22,' + LineEnding +
    '    ssh_user        TEXT,' + LineEnding +
    '    ssh_auth_type   TEXT DEFAULT ''PASSWORD'' CHECK (ssh_auth_type IN (''PASSWORD'', ''KEY_FILE'')),' + LineEnding +
    '    ssh_key_path    TEXT,' + LineEnding +
    '    ssh_pass_enc    TEXT,' + LineEnding +
    '    env_tag         TEXT NOT NULL DEFAULT ''DEVELOPMENT'' CHECK (env_tag IN (''DEVELOPMENT'', ''TESTING'', ''STAGING'', ''PRODUCTION'')),' + LineEnding +
    '    color_hex       TEXT NOT NULL DEFAULT ''#4A90E2'',' + LineEnding +
    '    is_favorite     INTEGER NOT NULL DEFAULT 0 CHECK (is_favorite IN (0, 1)),' + LineEnding +
    '    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,' + LineEnding +
    '    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP' + LineEnding +
    ');' + LineEnding +
    'CREATE TABLE IF NOT EXISTS query_history (' + LineEnding +
    '    id                INTEGER PRIMARY KEY AUTOINCREMENT,' + LineEnding +
    '    connection_id     INTEGER REFERENCES connection_profiles(id) ON DELETE SET NULL,' + LineEnding +
    '    database_target   TEXT,' + LineEnding +
    '    query_text        TEXT NOT NULL,' + LineEnding +
    '    execution_time_ms INTEGER NOT NULL DEFAULT 0,' + LineEnding +
    '    rows_affected     INTEGER NOT NULL DEFAULT 0,' + LineEnding +
    '    is_success        INTEGER NOT NULL CHECK (is_success IN (0, 1)),' + LineEnding +
    '    error_message     TEXT,' + LineEnding +
    '    executed_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP' + LineEnding +
    ');' + LineEnding +
    'CREATE TABLE IF NOT EXISTS query_snippets (' + LineEnding +
    '    id              INTEGER PRIMARY KEY AUTOINCREMENT,' + LineEnding +
    '    title           TEXT NOT NULL,' + LineEnding +
    '    description     TEXT,' + LineEnding +
    '    target_driver   TEXT NOT NULL DEFAULT ''ALL'' CHECK (target_driver IN (''ALL'', ''SQLITE'', ''MYSQL'', ''MARIADB'', ''FIREBIRD'', ''POSTGRESQL'')),' + LineEnding +
    '    sql_content     TEXT NOT NULL,' + LineEnding +
    '    shortcut_prefix TEXT,' + LineEnding +
    '    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,' + LineEnding +
    '    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP' + LineEnding +
    ');' + LineEnding +
    'CREATE INDEX IF NOT EXISTS idx_conn_group ON connection_profiles(group_id);' + LineEnding +
    'CREATE INDEX IF NOT EXISTS idx_conn_driver ON connection_profiles(driver_type);' + LineEnding +
    'CREATE INDEX IF NOT EXISTS idx_history_conn_time ON query_history(connection_id, executed_at DESC);' + LineEnding +
    'CREATE INDEX IF NOT EXISTS idx_history_executed_at ON query_history(executed_at DESC);' + LineEnding +
    'CREATE INDEX IF NOT EXISTS idx_snippets_driver ON query_snippets(target_driver);';

  SQL_MIGRATION_V2 =
    'PRAGMA foreign_keys = ON;' + LineEnding +
    'CREATE TABLE IF NOT EXISTS query_tags (' + LineEnding +
    '    id          INTEGER PRIMARY KEY AUTOINCREMENT,' + LineEnding +
    '    name        TEXT NOT NULL UNIQUE,' + LineEnding +
    '    color_hex   TEXT NOT NULL DEFAULT ''#6C757D'',' + LineEnding +
    '    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP' + LineEnding +
    ');' + LineEnding +
    'CREATE TABLE IF NOT EXISTS snippet_tag_map (' + LineEnding +
    '    snippet_id  INTEGER NOT NULL REFERENCES query_snippets(id) ON DELETE CASCADE,' + LineEnding +
    '    tag_id      INTEGER NOT NULL REFERENCES query_tags(id) ON DELETE CASCADE,' + LineEnding +
    '    PRIMARY KEY (snippet_id, tag_id)' + LineEnding +
    ');' + LineEnding +
    'ALTER TABLE query_history ADD COLUMN is_bookmarked INTEGER NOT NULL DEFAULT 0 CHECK (is_bookmarked IN (0, 1));' + LineEnding +
    'ALTER TABLE query_history ADD COLUMN custom_label TEXT;' + LineEnding +
    'CREATE INDEX IF NOT EXISTS idx_tags_name ON query_tags(name);' + LineEnding +
    'CREATE INDEX IF NOT EXISTS idx_snippet_tag_fk ON snippet_tag_map(tag_id);' + LineEnding +
    'CREATE INDEX IF NOT EXISTS idx_history_bookmarked ON query_history(is_bookmarked);' + LineEnding +
    'INSERT OR IGNORE INTO query_tags (name, color_hex) VALUES' + LineEnding +
    '(''Maintenance'', ''#E74C3C''),' + LineEnding +
    '(''Reporting'',   ''#27AE60''),' + LineEnding +
    '(''Performance'', ''#F39C12''),' + LineEnding +
    '(''Migration'',   ''#8E44AD''),' + LineEnding +
    '(''Utility'',     ''#2980B9'');';

function GetAvailableMigrations: TMigrationStepArray;
begin
  SetLength(Result, 2);

  Result[0].Version := 1;
  Result[0].Description := 'Initial schema setup for siadmin internal storage';
  Result[0].SQLScript := SQL_MIGRATION_V1;

  Result[1].Version := 2;
  Result[1].Description := 'Add query tags and bookmark attributes';
  Result[1].SQLScript := SQL_MIGRATION_V2;
end;

end.

