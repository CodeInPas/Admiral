unit uRESTGeneratorPHP;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  uAppTypes, uDBTypes, uModelConnection, uModelRESTConfig;

type
  { TRESTEnginePHP }
  TRESTEnginePHP = class
  private
    class procedure SaveTextFile(const AFilePath, AContent: string);
    class function GenerateHtaccess(AConfig: TRestProjectConfig): string;
    class function GenerateConfigPHP(AConfig: TRestProjectConfig): string;
    class function GenerateDatabasePHP(AConfig: TRestProjectConfig): string;
    class function GenerateResponseHelperPHP: string;
    class function GenerateAuthPHP(AConfig: TRestProjectConfig): string;
    class function GenerateTableRoutePHP(AConfig: TRestProjectConfig; ATable: TRestTableConfig): string;
    class function GenerateIndexPHP(AConfig: TRestProjectConfig): string;
    class function GenerateReadme(AConfig: TRestProjectConfig): string;
  public
    class function GenerateProject(AConfig: TRestProjectConfig; out AErrorMsg: string): Boolean;
  end;

implementation

class procedure TRESTEnginePHP.SaveTextFile(const AFilePath, AContent: string);
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

class function TRESTEnginePHP.GenerateHtaccess(AConfig: TRestProjectConfig): string;
begin
  Result :=
    '<IfModule mod_rewrite.c>' + LineEnding +
    '    RewriteEngine On' + LineEnding +
    '    RewriteCond %{REQUEST_FILENAME} !-f' + LineEnding +
    '    RewriteCond %{REQUEST_FILENAME} !-d' + LineEnding +
    '    RewriteRule ^(.*)$ index.php [QSA,L]' + LineEnding +
    '</IfModule>' + LineEnding +
    '# Proteksi berkas konfigurasi' + LineEnding +
    '<Files config.php>' + LineEnding +
    '    Order allow,deny' + LineEnding +
    '    Deny from all' + LineEnding +
    '</Files>';
end;

class function TRESTEnginePHP.GenerateConfigPHP(AConfig: TRestProjectConfig): string;
begin
  Result :=
    '<?php' + LineEnding +
    '// Konfigurasi Database dan Aplikasi' + LineEnding +
    'define(''DB_HOST'', ''' + AConfig.Profile.Host + ''');' + LineEnding +
    'define(''DB_PORT'', ''' + IntToStr(AConfig.Profile.Port) + ''');' + LineEnding +
    'define(''DB_NAME'', ''' + AConfig.DatabaseName + ''');' + LineEnding +
    'define(''DB_USER'', ''' + AConfig.Profile.Username + ''');' + LineEnding +
    'define(''DB_PASS'', ''' + AConfig.Profile.Password + ''');' + LineEnding +
    'define(''BASE_ROUTE'', ''' + AConfig.BaseRoute + ''');' + LineEnding +
    'define(''API_KEY'', ''' + AConfig.ApiKey + ''');' + LineEnding +
    'define(''AUTH_ENABLED'', ' + LowerCase(BoolToStr(AConfig.EnableAuth, True)) + ');' + LineEnding;
end;

class function TRESTEnginePHP.GenerateDatabasePHP(AConfig: TRestProjectConfig): string;
var
  DsnExpr: string;
begin
  case AConfig.Profile.DriverType of
    dtMySQL, dtMariaDB:
      DsnExpr := '"mysql:host=" . DB_HOST . ";port=" . DB_PORT . ";dbname=" . DB_NAME . ";charset=utf8mb4"';
    dtPostgreSQL:
      DsnExpr := '"pgsql:host=" . DB_HOST . ";port=" . DB_PORT . ";dbname=" . DB_NAME';
    dtSQLite:
      DsnExpr := '"sqlite:" . DB_NAME';
    dtFirebird:
      DsnExpr := '"firebird:dbname=" . DB_HOST . "/" . DB_PORT . ":" . DB_NAME . ";charset=UTF8"';
    else
      DsnExpr := '"mysql:host=" . DB_HOST . ";port=" . DB_PORT . ";dbname=" . DB_NAME . ";charset=utf8mb4"';
  end;

  Result :=
    '<?php' + LineEnding +
    'require_once __DIR__ . ''/config.php'';' + LineEnding + LineEnding +
    'class Database {' + LineEnding +
    '    private static ?PDO $instance = null;' + LineEnding + LineEnding +
    '    public static function getConnection(): PDO {' + LineEnding +
    '        if (self::$instance === null) {' + LineEnding +
    '            try {' + LineEnding +
    '                $dsn = ' + DsnExpr + ';' + LineEnding +
    '                self::$instance = new PDO($dsn, DB_USER, DB_PASS, [' + LineEnding +
    '                    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,' + LineEnding +
    '                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,' + LineEnding +
    '                    PDO::ATTR_EMULATE_PREPARES   => false,' + LineEnding +
    '                ]);' + LineEnding +
    '            } catch (PDOException $e) {' + LineEnding +
    '                http_response_code(500);' + LineEnding +
    '                echo json_encode(["success" => false, "error" => "Koneksi Database Gagal: " . $e->getMessage()]);' + LineEnding +
    '                exit;' + LineEnding +
    '            }' + LineEnding +
    '        }' + LineEnding +
    '        return self::$instance;' + LineEnding +
    '    }' + LineEnding +
    '}' + LineEnding;
end;

class function TRESTEnginePHP.GenerateResponseHelperPHP: string;
begin
  Result :=
    '<?php' + LineEnding +
    'class Response {' + LineEnding +
    '    public static function json(array $data, int $statusCode = 200): void {' + LineEnding +
    '        http_response_code($statusCode);' + LineEnding +
    '        header(''Content-Type: application/json; charset=utf-8'');' + LineEnding +
    '        echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);' + LineEnding +
    '        exit;' + LineEnding +
    '    }' + LineEnding + LineEnding +
    '    public static function error(string $message, int $statusCode = 500): void {' + LineEnding +
    '        self::json(["success" => false, "error" => $message], $statusCode);' + LineEnding +
    '    }' + LineEnding + LineEnding +
    '    public static function getJsonBody(): array {' + LineEnding +
    '        $raw = file_get_contents(''php://input'');' + LineEnding +
    '        if (empty($raw)) return [];' + LineEnding +
    '        $json = json_decode($raw, true);' + LineEnding +
    '        return is_array($json) ? $json : [];' + LineEnding +
    '    }' + LineEnding +
    '}' + LineEnding;
end;

class function TRESTEnginePHP.GenerateAuthPHP(AConfig: TRestProjectConfig): string;
begin
  Result :=
    '<?php' + LineEnding +
    'require_once __DIR__ . ''/../config/config.php'';' + LineEnding +
    'require_once __DIR__ . ''/../helpers/response.php'';' + LineEnding + LineEnding +
    'class AuthMiddleware {' + LineEnding +
    '    public static function authenticate(): void {' + LineEnding +
    '        if (!AUTH_ENABLED) return;' + LineEnding + LineEnding +
    '        $headers = getallheaders();' + LineEnding +
    '        $apiKey = $headers[''x-api-key''] ?? $headers[''X-Api-Key''] ?? $_GET[''api_key''] ?? null;' + LineEnding + LineEnding +
    '        if (!$apiKey || $apiKey !== API_KEY) {' + LineEnding +
    '            Response::error("Unauthorized: Header x-api-key tidak valid atau tidak disertakan.", 401);' + LineEnding +
    '        }' + LineEnding +
    '    }' + LineEnding +
    '}' + LineEnding;
end;

class function TRESTEnginePHP.GenerateTableRoutePHP(AConfig: TRestProjectConfig; ATable: TRestTableConfig): string;
var
  PK, SelectCols: string;
  I: Integer;
  Code: TStringList;
begin
  PK := ATable.PrimaryKey;
  if PK = '' then PK := 'id';

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
    Code.Add('<?php');
    Code.Add('require_once __DIR__ . ''/../config/database.php'';');
    Code.Add('require_once __DIR__ . ''/../helpers/response.php'';');
    Code.Add('');
    Code.Add(Format('class %sController {', [ATable.TableName]));

    // 1. GET LIST
    if roList in ATable.AllowedOperations then
    begin
      Code.Add('    public static function getList(): void {');
      Code.Add('        $db = Database::getConnection();');
      Code.Add('        $page = max(1, (int)($_GET[''page''] ?? 1));');
      Code.Add('        $limit = max(1, min(100, (int)($_GET[''limit''] ?? 20)));');
      Code.Add('        $offset = ($page - 1) * $limit;');
      Code.Add('        $search = trim($_GET[''search''] ?? '''');');
      Code.Add('');
      Code.Add('        $where = "";');
      Code.Add('        $params = [];');
      if ATable.SearchableColumns.Count > 0 then
      begin
        Code.Add('        if ($search !== '''') {');
        Code.Add(Format('            $where = " WHERE %s LIKE ?";', [ATable.SearchableColumns[0]]));
        Code.Add('            $params[] = "%" . $search . "%";');
        Code.Add('        }');
      end;
      Code.Add('');
      Code.Add(Format('        $countStmt = $db->prepare("SELECT COUNT(*) FROM %s" . $where);', [ATable.TableName]));
      Code.Add('        $countStmt->execute($params);');
      Code.Add('        $total = (int)$countStmt->fetchColumn();');
      Code.Add('');
      Code.Add(Format('        $sql = "SELECT %s FROM %s" . $where . " LIMIT " . (int)$limit . " OFFSET " . (int)$offset;', [SelectCols, ATable.TableName]));
      Code.Add('        $stmt = $db->prepare($sql);');
      Code.Add('        $stmt->execute($params);');
      Code.Add('        $rows = $stmt->fetchAll();');
      Code.Add('');
      Code.Add('        Response::json([');
      Code.Add('            "success" => true,');
      Code.Add('            "pagination" => [');
      Code.Add('                "page" => $page,');
      Code.Add('                "limit" => $limit,');
      Code.Add('                "total" => $total,');
      Code.Add('                "total_pages" => (int)ceil($total / $limit)');
      Code.Add('            ],');
      Code.Add('            "data" => $rows');
      Code.Add('        ]);');
      Code.Add('    }');
      Code.Add('');
    end;

    // 2. GET DETAIL BY PK
    if roDetail in ATable.AllowedOperations then
    begin
      Code.Add('    public static function getDetail($id): void {');
      Code.Add('        $db = Database::getConnection();');
      Code.Add(Format('        $stmt = $db->prepare("SELECT %s FROM %s WHERE %s = ?");', [SelectCols, ATable.TableName, PK]));
      Code.Add('        $stmt->execute([$id]);');
      Code.Add('        $row = $stmt->fetch();');
      Code.Add('        if (!$row) {');
      Code.Add('            Response::error("Data tidak ditemukan", 404);');
      Code.Add('        }');
      Code.Add('        Response::json(["success" => true, "data" => $row]);');
      Code.Add('    }');
      Code.Add('');
    end;

    // 3. POST (CREATE)
    if (roCreate in ATable.AllowedOperations) and not ATable.IsView then
    begin
      Code.Add('    public static function create(): void {');
      Code.Add('        $payload = Response::getJsonBody();');
      Code.Add('        if (empty($payload)) {');
      Code.Add('            Response::error("Payload body kosong atau format tidak valid", 400);');
      Code.Add('        }');
      Code.Add('        $db = Database::getConnection();');
      Code.Add('        $cols = array_keys($payload);');
      Code.Add('        $placeholders = array_fill(0, count($cols), ''?'');');
      Code.Add(Format('        $sql = "INSERT INTO %s (" . implode(", ", $cols) . ") VALUES (" . implode(", ", $placeholders) . ")";', [ATable.TableName]));
      Code.Add('        try {');
      Code.Add('            $stmt = $db->prepare($sql);');
      Code.Add('            $stmt->execute(array_values($payload));');
      Code.Add('            Response::json([');
      Code.Add('                "success" => true,');
      Code.Add('                "insert_id" => $db->lastInsertId(),');
      Code.Add('                "message" => "Data berhasil ditambahkan"');
      Code.Add('            ], 201);');
      Code.Add('        } catch (PDOException $e) {');
      Code.Add('            Response::error($e->getMessage(), 500);');
      Code.Add('        }');
      Code.Add('    }');
      Code.Add('');
    end;

    // 4. PUT (UPDATE)
    if (roUpdate in ATable.AllowedOperations) and not ATable.IsView then
    begin
      Code.Add('    public static function update($id): void {');
      Code.Add('        $payload = Response::getJsonBody();');
      Code.Add('        if (empty($payload)) {');
      Code.Add('            Response::error("Payload pembaruan kosong", 400);');
      Code.Add('        }');
      Code.Add('        $db = Database::getConnection();');
      Code.Add('        $setClauses = [];');
      Code.Add('        foreach (array_keys($payload) as $k) {');
      Code.Add('            $setClauses[] = "$k = ?";');
      Code.Add('        }');
      Code.Add('        $values = array_values($payload);');
      Code.Add('        $values[] = $id;');
      Code.Add(Format('        $sql = "UPDATE %s SET " . implode(", ", $setClauses) . " WHERE %s = ?";', [ATable.TableName, PK]));
      Code.Add('        try {');
      Code.Add('            $stmt = $db->prepare($sql);');
      Code.Add('            $stmt->execute($values);');
      Code.Add('            Response::json([');
      Code.Add('                "success" => true,');
      Code.Add('                "affected_rows" => $stmt->rowCount(),');
      Code.Add('                "message" => "Data berhasil diperbarui"');
      Code.Add('            ]);');
      Code.Add('        } catch (PDOException $e) {');
      Code.Add('            Response::error($e->getMessage(), 500);');
      Code.Add('        }');
      Code.Add('    }');
      Code.Add('');
    end;

    // 5. DELETE
    if (roDelete in ATable.AllowedOperations) and not ATable.IsView then
    begin
      Code.Add('    public static function delete($id): void {');
      Code.Add('        $db = Database::getConnection();');
      Code.Add(Format('        $stmt = $db->prepare("DELETE FROM %s WHERE %s = ?");', [ATable.TableName, PK]));
      Code.Add('        try {');
      Code.Add('            $stmt->execute([$id]);');
      Code.Add('            Response::json([');
      Code.Add('                "success" => true,');
      Code.Add('                "affected_rows" => $stmt->rowCount(),');
      Code.Add('                "message" => "Data berhasil dihapus"');
      Code.Add('            ]);');
      Code.Add('        } catch (PDOException $e) {');
      Code.Add('            Response::error($e->getMessage(), 500);');
      Code.Add('        }');
      Code.Add('    }');
    end;

    Code.Add('}');
    Result := Code.Text;
  finally
    Code.Free;
  end;
end;

class function TRESTEnginePHP.GenerateIndexPHP(AConfig: TRestProjectConfig): string;
var
  I: Integer;
  Code: TStringList;
  Tbl: TRestTableConfig;
begin
  Code := TStringList.Create;
  try
    Code.Add('<?php');
    Code.Add('// Front Controller REST API');
    Code.Add('header(''Access-Control-Allow-Origin: *'');');
    Code.Add('header(''Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS'');');
    Code.Add('header(''Access-Control-Allow-Headers: Content-Type, Authorization, x-api-key'');');
    Code.Add('');
    Code.Add('if ($_SERVER[''REQUEST_METHOD''] === ''OPTIONS'') {');
    Code.Add('    http_response_code(200);');
    Code.Add('    exit;');
    Code.Add('}');
    Code.Add('');
    Code.Add('require_once __DIR__ . ''/config/config.php'';');
    Code.Add('require_once __DIR__ . ''/helpers/response.php'';');
    Code.Add('require_once __DIR__ . ''/middleware/auth.php'';');
    Code.Add('');
    for I := 0 to AConfig.TableCount - 1 do
    begin
      Tbl := AConfig.Tables[I];
      Code.Add(Format('require_once __DIR__ . ''/routes/%s.php'';', [Tbl.TableName]));
    end;
    Code.Add('');
    Code.Add('$method = $_SERVER[''REQUEST_METHOD''];');
    Code.Add('$uri = parse_url($_SERVER[''REQUEST_URI''], PHP_URL_PATH);');
    Code.Add('$base = rtrim(BASE_ROUTE, ''/'');');
    Code.Add('');
    Code.Add('// Normalisasi path');
    Code.Add('if (strpos($uri, $base) === 0) {');
    Code.Add('    $path = trim(substr($uri, strlen($base)), ''/'');');
    Code.Add('} else {');
    Code.Add('    $path = trim($uri, ''/'');');
    Code.Add('}');
    Code.Add('');
    Code.Add('if ($path === '''' || $path === ''index.php'') {');
    Code.Add('    Response::json([');
    Code.Add('        "status" => "online",');
    Code.Add('        "engine" => "PHP Native PDO REST Service",');
    Code.Add('        "version" => "1.0.0"');
    Code.Add('    ]);');
    Code.Add('}');
    Code.Add('');
    Code.Add('// Otentikasi API Key');
    Code.Add('AuthMiddleware::authenticate();');
    Code.Add('');
    Code.Add('$parts = explode(''/'', $path);');
    Code.Add('$resource = $parts[0] ?? '''';');
    Code.Add('$paramId = $parts[1] ?? null;');
    Code.Add('');
    Code.Add('switch ($resource) {');
    for I := 0 to AConfig.TableCount - 1 do
    begin
      Tbl := AConfig.Tables[I];
      Code.Add(Format('    case ''%s'':', [Tbl.CustomRoute]));
      Code.Add('        if ($method === ''GET'') {');
      if roDetail in Tbl.AllowedOperations then
        Code.Add(Format('            if ($paramId !== null) { %sController::getDetail($paramId); }', [Tbl.TableName]));
      if roList in Tbl.AllowedOperations then
        Code.Add(Format('            %sController::getList();', [Tbl.TableName]));
      Code.Add('        }');
      if (roCreate in Tbl.AllowedOperations) and not Tbl.IsView then
        Code.Add(Format('        elseif ($method === ''POST'') { %sController::create(); }', [Tbl.TableName]));
      if (roUpdate in Tbl.AllowedOperations) and not Tbl.IsView then
        Code.Add(Format('        elseif ($method === ''PUT'' && $paramId !== null) { %sController::update($paramId); }', [Tbl.TableName]));
      if (roDelete in Tbl.AllowedOperations) and not Tbl.IsView then
        Code.Add(Format('        elseif ($method === ''DELETE'' && $paramId !== null) { %sController::delete($paramId); }', [Tbl.TableName]));
      Code.Add('        break;');
      Code.Add('');
    end;
    Code.Add('    default:');
    Code.Add('        Response::error("Endpoint URL tidak ditemukan", 404);');
    Code.Add('        break;');
    Code.Add('}');

    Result := Code.Text;
  finally
    Code.Free;
  end;
end;

class function TRESTEnginePHP.GenerateReadme(AConfig: TRestProjectConfig): string;
var
  I: Integer;
begin
  Result :=
    Format('# %s PHP (Native PDO) REST API', [AConfig.DatabaseName]) + LineEnding +
    'Dihasilkan secara otomatis oleh **siadmin Database Studio**.' + LineEnding + LineEnding +
    '## 🚀 Panduan Deployment (cPanel / Shared Hosting / XAMPP)' + LineEnding +
    '1. Unggah seluruh isi folder ini ke dalam folder `public_html` atau subfolder domain Anda.' + LineEnding +
    '2. Pastikan file `.htaccess` terunggah dan modul `mod_rewrite` aktif.' + LineEnding +
    '3. Sesuaikan kredensial database di `config/config.php`.' + LineEnding +
    '4. Tidak memerlukan instalasi Composer ataupun dependensi tambahan (*Zero-Dependency*).' + LineEnding + LineEnding +
    '## 📋 Endpoint Rute Tersedia' + LineEnding;

  for I := 0 to AConfig.TableCount - 1 do
  begin
    Result := Result + Format('* `%s/%s` (%s)' + LineEnding, [
      AConfig.BaseRoute,
      AConfig.Tables[I].CustomRoute,
      AConfig.Tables[I].TableName
    ]);
  end;
end;

class function TRESTEnginePHP.GenerateProject(AConfig: TRestProjectConfig; out AErrorMsg: string): Boolean;
var
  OutDir, CfgDir, HelpersDir, RoutesDir, MidDir: string;
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
  CfgDir := OutDir + 'config' + PathDelim;
  HelpersDir := OutDir + 'helpers' + PathDelim;
  RoutesDir := OutDir + 'routes' + PathDelim;
  MidDir := OutDir + 'middleware' + PathDelim;

  try
    ForceDirectories(CfgDir);
    ForceDirectories(HelpersDir);
    ForceDirectories(RoutesDir);
    ForceDirectories(MidDir);

    // Root Files
    SaveTextFile(OutDir + '.htaccess', GenerateHtaccess(AConfig));
    SaveTextFile(OutDir + 'index.php', GenerateIndexPHP(AConfig));
    SaveTextFile(OutDir + 'README.md', GenerateReadme(AConfig));

    // Support Packages
    SaveTextFile(CfgDir + 'config.php', GenerateConfigPHP(AConfig));
    SaveTextFile(CfgDir + 'database.php', GenerateDatabasePHP(AConfig));
    SaveTextFile(HelpersDir + 'response.php', GenerateResponseHelperPHP);
    SaveTextFile(MidDir + 'auth.php', GenerateAuthPHP(AConfig));

    // Routes per Table
    for I := 0 to AConfig.TableCount - 1 do
    begin
      Tbl := AConfig.Tables[I];
      SaveTextFile(RoutesDir + Tbl.TableName + '.php', GenerateTableRoutePHP(AConfig, Tbl));
    end;

    Result := True;
  except
    on E: Exception do
      AErrorMsg := E.Message;
  end;
end;

end.
