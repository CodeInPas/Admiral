unit uAppConst;

{$mode objfpc}{$H+}

interface

const
  // Informasi Aplikasi
  APP_NAME             = 'siadmin';
  APP_TITLE            = 'siadmin - Database Administrator';
  APP_VERSION          = '0.1.0';
  APP_INTERNAL_DB_NAME = 'siadmin_storage.db';

  // Identitas Driver DBMS
  DRIVER_SQLITE     = 'SQLITE';
  DRIVER_MYSQL      = 'MYSQL';
  DRIVER_MARIADB    = 'MARIADB';
  DRIVER_FIREBIRD   = 'FIREBIRD';
  DRIVER_POSTGRESQL = 'POSTGRESQL';

  // Default Port Jaringan DBMS
  DEFAULT_PORT_MYSQL      = 3306;
  DEFAULT_PORT_MARIADB    = 3306;
  DEFAULT_PORT_POSTGRESQL = 5432;
  DEFAULT_PORT_FIREBIRD   = 3050;
  DEFAULT_PORT_SSH        = 22;

  // Environment Tagging
  ENV_DEVELOPMENT = 'DEVELOPMENT';
  ENV_TESTING     = 'TESTING';
  ENV_STAGING     = 'STAGING';
  ENV_PRODUCTION  = 'PRODUCTION';

  // Warna Default Environment (Hex)
  COLOR_ENV_DEV   = '#4A90E2';
  COLOR_ENV_TEST  = '#9B59B6';
  COLOR_ENV_STAGE = '#E67E22';
  COLOR_ENV_PROD  = '#E74C3C';

  // SSL Mode
  SSL_MODE_DISABLE     = 'DISABLE';
  SSL_MODE_REQUIRE     = 'REQUIRE';
  SSL_MODE_VERIFY_CA   = 'VERIFY_CA';
  SSL_MODE_VERIFY_FULL = 'VERIFY_FULL';

  // SSH Auth Types
  SSH_AUTH_PASSWORD = 'PASSWORD';
  SSH_AUTH_KEY_FILE = 'KEY_FILE';

  // Kunci Pengaturan Internal (app_settings)
  SETTING_EDITOR_FONT_NAME         = 'app.editor.font_name';
  SETTING_EDITOR_FONT_SIZE         = 'app.editor.font_size';
  SETTING_EDITOR_TAB_WIDTH         = 'app.editor.tab_width';
  SETTING_EDITOR_AUTO_COMPLETE     = 'app.editor.auto_complete';
  SETTING_GRID_PAGE_LIMIT          = 'app.grid.page_limit';
  SETTING_GRID_NULL_REPRESENTATION = 'app.grid.null_representation';
  SETTING_HISTORY_MAX_ENTRIES      = 'app.history.max_entries';
  SETTING_CONFIRM_DESTRUCTIVE_SQL  = 'app.general.confirm_destructive_sql';

  // Nilai Default Pengaturan
  DEFAULT_EDITOR_FONT_NAME         = 'Courier New';
  DEFAULT_EDITOR_FONT_SIZE         = 11;
  DEFAULT_EDITOR_TAB_WIDTH         = 2;
  DEFAULT_EDITOR_AUTO_COMPLETE     = True;
  DEFAULT_GRID_PAGE_LIMIT          = 500;
  DEFAULT_GRID_NULL_REPRESENTATION = '(NULL)';
  DEFAULT_HISTORY_MAX_ENTRIES      = 5000;
  DEFAULT_CONFIRM_DESTRUCTIVE_SQL  = True;
  DEFAULT_CONNECTION_TIMEOUT       = 15;

  // Target Versi Skema Database Internal
  CURRENT_STORAGE_SCHEMA_VERSION   = 2;

implementation

end.

