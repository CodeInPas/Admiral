unit uRESTGeneratorNodeJS;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  uAppTypes, uDBTypes, uModelConnection, uModelRESTConfig;

type
  { TRESTEngineNodeJS }
  TRESTEngineNodeJS = class
  private
    class procedure SaveTextFile(const AFilePath, AContent: string);
    class function GeneratePackageJSON(AConfig: TRestProjectConfig): string;
    class function GenerateEnvFile(AConfig: TRestProjectConfig): string;
    class function GenerateGitIgnore: string;
    class function GenerateDBModule(AConfig: TRestProjectConfig): string;
    class function GenerateAuthMiddleware(AConfig: TRestProjectConfig): string;
    class function GenerateTableRoute(AConfig: TRestProjectConfig; ATable: TRestTableConfig): string;
    class function GenerateServerJS(AConfig: TRestProjectConfig): string;
    class function GenerateReadme(AConfig: TRestProjectConfig): string;
  public
    class function GenerateProject(AConfig: TRestProjectConfig; out AErrorMsg: string): Boolean;
  end;

implementation

class procedure TRESTEngineNodeJS.SaveTextFile(const AFilePath, AContent: string);
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Text := AContent;
    SL.SaveToFile(AFilePath);
  finally
    SL.Free;
  end;
end;

class function TRESTEngineNodeJS.GeneratePackageJSON(AConfig: TRestProjectConfig): string;
var
  DBDep: string;
begin
  case AConfig.Profile.DriverType of
    dtMySQL, dtMariaDB: DBDep := '    "mysql2": "^3.9.0",';
    dtPostgreSQL:       DBDep := '    "pg": "^8.11.3",';
    dtSQLite:           DBDep := '    "better-sqlite3": "^9.4.3",';
    else                DBDep := '    "mysql2": "^3.9.0",';
  end;

  Result :=
    '{' + LineEnding +
    '  "name": "' + LowerCase(StringReplace(AConfig.DatabaseName, ' ', '-', [rfReplaceAll])) + '-api",' + LineEnding +
    '  "version": "1.0.0",' + LineEnding +
    '  "description": "REST API generated automatically by siadmin Studio",' + LineEnding +
    '  "main": "src/server.js",' + LineEnding +
    '  "scripts": {' + LineEnding +
    '    "start": "node src/server.js",' + LineEnding +
    '    "dev": "nodemon src/server.js"' + LineEnding +
    '  },' + LineEnding +
    '  "dependencies": {' + LineEnding +
    '    "cors": "^2.8.5",' + LineEnding +
    '    "dotenv": "^16.4.5",' + LineEnding +
    '    "express": "^4.19.2",' + LineEnding +
    '    "morgan": "^1.10.0",' + LineEnding +
    DBDep + LineEnding +
    '    "helmet": "^7.1.0"' + LineEnding +
    '  },' + LineEnding +
    '  "devDependencies": {' + LineEnding +
    '    "nodemon": "^3.1.0"' + LineEnding +
    '  }' + LineEnding +
    '}';
end;

class function TRESTEngineNodeJS.GenerateEnvFile(AConfig: TRestProjectConfig): string;
begin
  Result :=
    '# Konfigurasi Server' + LineEnding +
    Format('PORT=%d', [AConfig.ServerPort]) + LineEnding +
    Format('BASE_ROUTE=%s', [AConfig.BaseRoute]) + LineEnding +
    LineEnding +
    '# Konfigurasi Database' + LineEnding +
    Format('DB_HOST=%s', [AConfig.Profile.Host]) + LineEnding +
    Format('DB_PORT=%d', [AConfig.Profile.Port]) + LineEnding +
    Format('DB_NAME=%s', [AConfig.DatabaseName]) + LineEnding +
    Format('DB_USER=%s', [AConfig.Profile.Username]) + LineEnding +
    Format('DB_PASSWORD=%s', [AConfig.Profile.Password]) + LineEnding +
    LineEnding +
    '# Keamanan API' + LineEnding +
    Format('API_KEY=%s', [AConfig.ApiKey]);
end;

class function TRESTEngineNodeJS.GenerateGitIgnore: string;
begin
  Result :=
    'node_modules/' + LineEnding +
    '.env' + LineEnding +
    '*.log' + LineEnding +
    '.DS_Store';
end;

class function TRESTEngineNodeJS.GenerateDBModule(AConfig: TRestProjectConfig): string;
begin
  case AConfig.Profile.DriverType of
    dtMySQL, dtMariaDB:
      Result :=
        'const mysql = require(''mysql2/promise'');' + LineEnding +
        'require(''dotenv'').config();' + LineEnding + LineEnding +
        'const pool = mysql.createPool({' + LineEnding +
        '  host: process.env.DB_HOST || ''localhost'',' + LineEnding +
        '  port: process.env.DB_PORT || 3306,' + LineEnding +
        '  user: process.env.DB_USER || ''root'',' + LineEnding +
        '  password: process.env.DB_PASSWORD || '''',' + LineEnding +
        '  database: process.env.DB_NAME,' + LineEnding +
        '  waitForConnections: true,' + LineEnding +
        '  connectionLimit: 10,' + LineEnding +
        '  queueLimit: 0' + LineEnding +
        '});' + LineEnding + LineEnding +
        'module.exports = {' + LineEnding +
        '  query: (sql, params) => pool.query(sql, params),' + LineEnding +
        '  pool' + LineEnding +
        '};';

    dtPostgreSQL:
      Result :=
        'const { Pool } = require(''pg'');' + LineEnding +
        'require(''dotenv'').config();' + LineEnding + LineEnding +
        'const pool = new Pool({' + LineEnding +
        '  host: process.env.DB_HOST || ''localhost'',' + LineEnding +
        '  port: process.env.DB_PORT || 5432,' + LineEnding +
        '  user: process.env.DB_USER || ''postgres'',' + LineEnding +
        '  password: process.env.DB_PASSWORD || '''',' + LineEnding +
        '  database: process.env.DB_NAME,' + LineEnding +
        '  max: 10' + LineEnding +
        '});' + LineEnding + LineEnding +
        'module.exports = {' + LineEnding +
        '  query: (text, params) => pool.query(text, params),' + LineEnding +
        '  pool' + LineEnding +
        '};';

    dtSQLite:
      Result :=
        'const Database = require(''better-sqlite3'');' + LineEnding +
        'require(''dotenv'').config();' + LineEnding + LineEnding +
        'const db = new Database(process.env.DB_NAME || ''database.db'');' + LineEnding +
        'db.pragma(''journal_mode = WAL'');' + LineEnding + LineEnding +
        'module.exports = {' + LineEnding +
        '  query: (sql, params = []) => {' + LineEnding +
        '    const stmt = db.prepare(sql);' + LineEnding +
        '    if (sql.trim().toUpperCase().startsWith(''SELECT'')) {' + LineEnding +
        '      return [stmt.all(...params)];' + LineEnding +
        '    }' + LineEnding +
        '    const info = stmt.run(...params);' + LineEnding +
        '    return [{ affectedRows: info.changes, insertId: info.lastInsertRowid }];' + LineEnding +
        '  },' + LineEnding +
        '  db' + LineEnding +
        '};';
    else
      Result := '// Driver belum didukung secara penuh';
  end;
end;

class function TRESTEngineNodeJS.GenerateAuthMiddleware(AConfig: TRestProjectConfig): string;
begin
  if not AConfig.EnableAuth then
  begin
    Result :=
      'module.exports = (req, res, next) => next(); // Auth dinonaktifkan';
    Exit;
  end;

  Result :=
    'require(''dotenv'').config();' + LineEnding + LineEnding +
    'module.exports = (req, res, next) => {' + LineEnding +
    '  const apiKey = req.headers[''x-api-key''] || req.query.api_key;' + LineEnding +
    '  const validKey = process.env.API_KEY;' + LineEnding + LineEnding +
    '  if (!apiKey || apiKey !== validKey) {' + LineEnding +
    '    return res.status(401).json({' + LineEnding +
    '      success: false,' + LineEnding +
    '      message: ''Unauthorized: API Key tidak valid atau tidak disertakan (header x-api-key)''' + LineEnding +
    '    });' + LineEnding +
    '  }' + LineEnding +
    '  next();' + LineEnding +
    '};';
end;

class function TRESTEngineNodeJS.GenerateTableRoute(AConfig: TRestProjectConfig; ATable: TRestTableConfig): string;
var
  PK: string;
  SelectCols: string;
  I: Integer;
  Code: TStringList;
begin
  PK := ATable.PrimaryKey;
  if PK = '' then PK := 'id';

  // Susun kolom yang diambil (dikecualikan dari ExcludedColumns)
  if ATable.SelectedColumns.Count > 0 then
  begin
    SelectCols := '';
    for I := 0 to ATable.SelectedColumns.Count - 1 do
    begin
      if ATable.ExcludedColumns.IndexOf(ATable.SelectedColumns[I]) < 0 then
      begin
        if SelectCols <> '' then SelectCols := SelectCols + ', ';
        SelectCols := SelectCols + ATable.SelectedColumns[I];
      end;
    end;
  end
  else
    SelectCols := '*';

  Code := TStringList.Create;
  try
    Code.Add('const express = require(''express'');');
    Code.Add('const router = express.Router();');
    Code.Add('const db = require(''../db'');');
    Code.Add('');

    // 1. GET ALL / LIST dengan Pagination & Filter
    if roList in ATable.AllowedOperations then
    begin
      Code.Add(Format('// GET /api/v1/%s (List & Filter)', [ATable.CustomRoute]));
      Code.Add('router.get(''/'', async (req, res) => {');
      Code.Add('  try {');
      Code.Add('    const page = parseInt(req.query.page) || 1;');
      Code.Add('    const limit = parseInt(req.query.limit) || 20;');
      Code.Add('    const offset = (page - 1) * limit;');
      Code.Add('    const search = req.query.search || '''';');
      Code.Add('');
      Code.Add('    let whereClause = '''';');
      Code.Add('    let params = [];');
      Code.Add('');
      if ATable.SearchableColumns.Count > 0 then
      begin
        Code.Add('    if (search) {');
        Code.Add(Format('      whereClause = " WHERE (%s LIKE ?)";', [ATable.SearchableColumns[0]]));
        Code.Add('      params.push(`%${search}%`);');
        Code.Add('    }');
      end;
      Code.Add(Format('    const sql = `SELECT %s FROM %s${whereClause} LIMIT ? OFFSET ?`;', [SelectCols, ATable.TableName]));
      Code.Add('    const queryParams = [...params, limit, offset];');
      Code.Add('    const [rows] = await db.query(sql, queryParams);');
      Code.Add('');
      Code.Add(Format('    const [countResult] = await db.query(`SELECT COUNT(*) as total FROM %s${whereClause}`, params);', [ATable.TableName]));
      Code.Add('    const total = countResult[0].total || 0;');
      Code.Add('');
      Code.Add('    res.json({');
      Code.Add('      success: true,');
      Code.Add('      pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },');
      Code.Add('      data: rows');
      Code.Add('    });');
      Code.Add('  } catch (err) {');
      Code.Add('    res.status(500).json({ success: false, error: err.message });');
      Code.Add('  }');
      Code.Add('});');
      Code.Add('');
    end;

    // 2. GET DETAIL BY PK
    if roDetail in ATable.AllowedOperations then
    begin
      Code.Add(Format('// GET /api/v1/%s/:id (Detail)', [ATable.CustomRoute]));
      Code.Add('router.get(''/:id'', async (req, res) => {');
      Code.Add('  try {');
      Code.Add(Format('    const [rows] = await db.query(''SELECT %s FROM %s WHERE %s = ?'', [req.params.id]);', [SelectCols, ATable.TableName, PK]));
      Code.Add('    if (rows.length === 0) {');
      Code.Add('      return res.status(404).json({ success: false, message: ''Data tidak ditemukan'' });');
      Code.Add('    }');
      Code.Add('    res.json({ success: true, data: rows[0] });');
      Code.Add('  } catch (err) {');
      Code.Add('    res.status(500).json({ success: false, error: err.message });');
      Code.Add('  }');
      Code.Add('});');
      Code.Add('');
    end;

    // 3. POST (INSERT)
    if (roCreate in ATable.AllowedOperations) and not ATable.IsView then
    begin
      Code.Add(Format('// POST /api/v1/%s (Create)', [ATable.CustomRoute]));
      Code.Add('router.post(''/'', async (req, res) => {');
      Code.Add('  try {');
      Code.Add('    const payload = req.body;');
      Code.Add('    const keys = Object.keys(payload);');
      Code.Add('    if (keys.length === 0) {');
      Code.Add('      return res.status(400).json({ success: false, message: ''Payload body kosong'' });');
      Code.Add('    }');
      Code.Add('    const values = Object.values(payload);');
      Code.Add('    const placeholders = keys.map(() => ''?'').join('', '');');
      Code.Add(Format('    const sql = `INSERT INTO %s (${keys.join('', '')}) VALUES (${placeholders})`;', [ATable.TableName]));
      Code.Add('    const [result] = await db.query(sql, values);');
      Code.Add('    res.status(201).json({ success: true, insertId: result.insertId, message: ''Data berhasil ditambahkan'' });');
      Code.Add('  } catch (err) {');
      Code.Add('    res.status(500).json({ success: false, error: err.message });');
      Code.Add('  }');
      Code.Add('});');
      Code.Add('');
    end;

    // 4. PUT (UPDATE)
    if (roUpdate in ATable.AllowedOperations) and not ATable.IsView then
    begin
      Code.Add(Format('// PUT /api/v1/%s/:id (Update)', [ATable.CustomRoute]));
      Code.Add('router.put(''/:id'', async (req, res) => {');
      Code.Add('  try {');
      Code.Add('    const payload = req.body;');
      Code.Add('    const keys = Object.keys(payload);');
      Code.Add('    if (keys.length === 0) {');
      Code.Add('      return res.status(400).json({ success: false, message: ''Payload pembaruan kosong'' });');
      Code.Add('    }');
      Code.Add('    const setClause = keys.map(k => `${k} = ?`).join('', '');');
      Code.Add('    const values = [...Object.values(payload), req.params.id];');
      Code.Add(Format('    const sql = `UPDATE %s SET ${setClause} WHERE %s = ?`;', [ATable.TableName, PK]));
      Code.Add('    const [result] = await db.query(sql, values);');
      Code.Add('    res.json({ success: true, affectedRows: result.affectedRows, message: ''Data berhasil diperbarui'' });');
      Code.Add('  } catch (err) {');
      Code.Add('    res.status(500).json({ success: false, error: err.message });');
      Code.Add('  }');
      Code.Add('});');
      Code.Add('');
    end;

    // 5. DELETE
    if (roDelete in ATable.AllowedOperations) and not ATable.IsView then
    begin
      Code.Add(Format('// DELETE /api/v1/%s/:id (Delete)', [ATable.CustomRoute]));
      Code.Add('router.delete(''/:id'', async (req, res) => {');
      Code.Add('  try {');
      Code.Add(Format('    const [result] = await db.query(''DELETE FROM %s WHERE %s = ?'', [req.params.id]);', [ATable.TableName, PK]));
      Code.Add('    res.json({ success: true, affectedRows: result.affectedRows, message: ''Data berhasil dihapus'' });');
      Code.Add('  } catch (err) {');
      Code.Add('    res.status(500).json({ success: false, error: err.message });');
      Code.Add('  }');
      Code.Add('});');
    end;

    Code.Add('');
    Code.Add('module.exports = router;');
    Result := Code.Text;
  finally
    Code.Free;
  end;
end;

class function TRESTEngineNodeJS.GenerateServerJS(AConfig: TRestProjectConfig): string;
var
  I: Integer;
  Code: TStringList;
  Tbl: TRestTableConfig;
begin
  Code := TStringList.Create;
  try
    Code.Add('const express = require(''express'');');
    Code.Add('const cors = require(''cors'');');
    Code.Add('const helmet = require(''helmet'');');
    Code.Add('const morgan = require(''morgan'');');
    Code.Add('const authMiddleware = require(''./middleware/auth'');');
    Code.Add('require(''dotenv'').config();');
    Code.Add('');
    Code.Add('const app = express();');
    Code.Add('const PORT = process.env.PORT || ' + IntToStr(AConfig.ServerPort) + ';');
    Code.Add('const BASE = process.env.BASE_ROUTE || ''' + AConfig.BaseRoute + ''';');
    Code.Add('');
    Code.Add('app.use(helmet());');
    Code.Add('app.use(cors());');
    Code.Add('app.use(morgan(''dev''));');
    Code.Add('app.use(express.json());');
    Code.Add('app.use(express.urlencoded({ extended: true }));');
    Code.Add('');
    Code.Add('// Root Healthcheck');
    Code.Add('app.get(''/'', (req, res) => {');
    Code.Add('  res.json({ status: ''online'', service: ''siadmin Generated REST API'', version: ''1.0.0'' });');
    Code.Add('});');
    Code.Add('');
    Code.Add('// Pasang Auth Middleware');
    Code.Add('app.use(BASE, authMiddleware);');
    Code.Add('');
    Code.Add('// Registrasi Rute Otomatis');
    for I := 0 to AConfig.TableCount - 1 do
    begin
      Tbl := AConfig.Tables[I];
      Code.Add(Format('const %sRoute = require(''./routes/%s'');', [Tbl.TableName, Tbl.TableName]));
      Code.Add(Format('app.use(`${BASE}/%s`, %sRoute);', [Tbl.CustomRoute, Tbl.TableName]));
    end;
    Code.Add('');
    Code.Add('// Global 404 Handler');
    Code.Add('app.use((req, res) => {');
    Code.Add('  res.status(404).json({ success: false, message: ''Endpoint URL tidak ditemukan'' });');
    Code.Add('});');
    Code.Add('');
    Code.Add('app.listen(PORT, () => {');
    Code.Add('  console.log(`⚡ Server berjalan di http://localhost:${PORT}${BASE}`);');
    Code.Add('});');

    Result := Code.Text;
  finally
    Code.Free;
  end;
end;

class function TRESTEngineNodeJS.GenerateReadme(AConfig: TRestProjectConfig): string;
var
  I: Integer;
begin
  Result :=
    Format('# %s REST API Service', [AConfig.DatabaseName]) + LineEnding +
    'Dihasilkan secara otomatis oleh **siadmin Database Studio**.' + LineEnding + LineEnding +
    '## 🚀 Cara Menjalankan' + LineEnding +
    '1. Pasang dependensi:' + LineEnding +
    '   ```bash' + LineEnding +
    '   npm install' + LineEnding +
    '   ```' + LineEnding +
    '2. Konfigurasi kredensial database di berkas `.env`.' + LineEnding +
    '3. Jalankan server:' + LineEnding +
    '   ```bash' + LineEnding +
    '   npm run dev' + LineEnding +
    '   ```' + LineEnding + LineEnding +
    '## 📋 Daftar Endpoint Tersedia' + LineEnding;

  for I := 0 to AConfig.TableCount - 1 do
  begin
    Result := Result + Format('* `%s/%s` (%s)' + LineEnding, [
      AConfig.BaseRoute,
      AConfig.Tables[I].CustomRoute,
      AConfig.Tables[I].TableName
    ]);
  end;
end;

class function TRESTEngineNodeJS.GenerateProject(AConfig: TRestProjectConfig; out AErrorMsg: string): Boolean;
var
  OutDir, SrcDir, RoutesDir, MidDir: string;
  I: Integer;
  Tbl: TRestTableConfig;
begin
  Result := False;
  AErrorMsg := '';

  if (AConfig.OutputDirectory = '') or (AConfig.TableCount = 0) then
  begin
    AErrorMsg := 'Direktori keluaran atau daftar tabel terpilih masih kosong.';
    Exit;
  end;

  OutDir := IncludeTrailingPathDelimiter(AConfig.OutputDirectory);
  SrcDir := OutDir + 'src' + PathDelim;
  RoutesDir := SrcDir + 'routes' + PathDelim;
  MidDir := SrcDir + 'middleware' + PathDelim;

  try
    ForceDirectories(RoutesDir);
    ForceDirectories(MidDir);

    // 1. Root Files
    SaveTextFile(OutDir + 'package.json', GeneratePackageJSON(AConfig));
    SaveTextFile(OutDir + '.env', GenerateEnvFile(AConfig));
    SaveTextFile(OutDir + '.gitignore', GenerateGitIgnore);
    SaveTextFile(OutDir + 'README.md', GenerateReadme(AConfig));

    // 2. Src Files
    SaveTextFile(SrcDir + 'db.js', GenerateDBModule(AConfig));
    SaveTextFile(MidDir + 'auth.js', GenerateAuthMiddleware(AConfig));
    SaveTextFile(SrcDir + 'server.js', GenerateServerJS(AConfig));

    // 3. Routes Files
    for I := 0 to AConfig.TableCount - 1 do
    begin
      Tbl := AConfig.Tables[I];
      SaveTextFile(RoutesDir + Tbl.TableName + '.js', GenerateTableRoute(AConfig, Tbl));
    end;

    Result := True;
  except
    on E: Exception do
      AErrorMsg := E.Message;
  end;
end;

end.
