unit uRESTGeneratorGoFiber;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  uAppTypes, uDBTypes, uModelConnection, uModelRESTConfig;

type
  { TRESTEngineGoFiber }
  TRESTEngineGoFiber = class
  private
    class procedure SaveTextFile(const AFilePath, AContent: string);
    class function GenerateGoMod(AConfig: TRestProjectConfig): string;
    class function GenerateEnvFile(AConfig: TRestProjectConfig): string;
    class function GenerateGitIgnore: string;
    class function GenerateDatabaseGo(AConfig: TRestProjectConfig): string;
    class function GenerateAuthMiddleware(AConfig: TRestProjectConfig): string;
    class function GenerateTableHandler(AConfig: TRestProjectConfig; ATable: TRestTableConfig): string;
    class function GenerateMainGo(AConfig: TRestProjectConfig): string;
    class function GenerateReadme(AConfig: TRestProjectConfig): string;
  public
    class function GenerateProject(AConfig: TRestProjectConfig; out AErrorMsg: string): Boolean;
  end;

implementation

class procedure TRESTEngineGoFiber.SaveTextFile(const AFilePath, AContent: string);
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

class function TRESTEngineGoFiber.GenerateGoMod(AConfig: TRestProjectConfig): string;
var
  ModName, DBDriverDep: string;
begin
  ModName := LowerCase(StringReplace(AConfig.DatabaseName, ' ', '-', [rfReplaceAll])) + '-api';
  case AConfig.Profile.DriverType of
    dtMySQL, dtMariaDB: DBDriverDep := '	github.com/go-sql-driver/mysql v1.8.1' + LineEnding;
    dtPostgreSQL:       DBDriverDep := '	github.com/lib/pq v1.10.9' + LineEnding;
    dtSQLite:           DBDriverDep := '	modernc.org/sqlite v1.29.5' + LineEnding;
    dtFirebird:         DBDriverDep := '	github.com/nakagami/firebirdsql v0.9.8' + LineEnding;
    else                DBDriverDep := '	github.com/go-sql-driver/mysql v1.8.1' + LineEnding;
  end;

  Result :=
    'module ' + ModName + LineEnding + LineEnding +
    'go 1.22' + LineEnding + LineEnding +
    'require (' + LineEnding +
    '	github.com/gofiber/fiber/v2 v2.52.4' + LineEnding +
    '	github.com/joho/godotenv v1.5.1' + LineEnding +
    DBDriverDep +
    ')';
end;

class function TRESTEngineGoFiber.GenerateEnvFile(AConfig: TRestProjectConfig): string;
begin
  Result :=
    '# Konfigurasi Server' + LineEnding +
    Format('PORT=%d', [AConfig.ServerPort]) + LineEnding +
    Format('BASE_ROUTE=%s', [AConfig.BaseRoute]) + LineEnding +
    LineEnding +
    '# Kredensial Database' + LineEnding +
    Format('DB_HOST=%s', [AConfig.Profile.Host]) + LineEnding +
    Format('DB_PORT=%d', [AConfig.Profile.Port]) + LineEnding +
    Format('DB_NAME=%s', [AConfig.DatabaseName]) + LineEnding +
    Format('DB_USER=%s', [AConfig.Profile.Username]) + LineEnding +
    Format('DB_PASSWORD=%s', [AConfig.Profile.Password]) + LineEnding +
    LineEnding +
    '# Keamanan API' + LineEnding +
    Format('API_KEY=%s', [AConfig.ApiKey]);
end;

class function TRESTEngineGoFiber.GenerateGitIgnore: string;
begin
  Result :=
    'bin/' + LineEnding +
    '*.exe' + LineEnding +
    '*.exe~' + LineEnding +
    '*.dll' + LineEnding +
    '*.so' + LineEnding +
    '*.dylib' + LineEnding +
    '.env' + LineEnding +
    '*.db' + LineEnding +
    '*.sqlite3' + LineEnding +
    '.DS_Store';
end;

class function TRESTEngineGoFiber.GenerateDatabaseGo(AConfig: TRestProjectConfig): string;
var
  DriverPkg, DriverName, DSNExpr: string;
begin
  case AConfig.Profile.DriverType of
    dtMySQL, dtMariaDB:
    begin
      DriverPkg := '	_ "github.com/go-sql-driver/mysql"';
      DriverName := 'mysql';
      DSNExpr := 'fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true&charset=utf8mb4", user, pass, host, port, name)';
    end;
    dtPostgreSQL:
    begin
      DriverPkg := '	_ "github.com/lib/pq"';
      DriverName := 'postgres';
      DSNExpr := 'fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable", host, port, user, pass, name)';
    end;
    dtSQLite:
    begin
      DriverPkg := '	_ "modernc.org/sqlite"';
      DriverName := 'sqlite';
      DSNExpr := 'name';
    end;
    dtFirebird:
    begin
      DriverPkg := '	_ "github.com/nakagami/firebirdsql"';
      DriverName := 'firebirdsql';
      DSNExpr := 'fmt.Sprintf("%s:%s@%s:%s/%s", user, pass, host, port, name)';
    end;
    else
    begin
      DriverPkg := '	_ "github.com/go-sql-driver/mysql"';
      DriverName := 'mysql';
      DSNExpr := 'fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true", user, pass, host, port, name)';
    end;
  end;

  Result :=
    'package config' + LineEnding + LineEnding +
    'import (' + LineEnding +
    '	"database/sql"' + LineEnding +
    '	"fmt"' + LineEnding +
    '	"log"' + LineEnding +
    '	"os"' + LineEnding +
    '	"time"' + LineEnding +
    DriverPkg + LineEnding +
    ')' + LineEnding + LineEnding +
    'var DB *sql.DB' + LineEnding + LineEnding +
    'func ConnectDB() {' + LineEnding +
    '	host := os.Getenv("DB_HOST")' + LineEnding +
    '	port := os.Getenv("DB_PORT")' + LineEnding +
    '	user := os.Getenv("DB_USER")' + LineEnding +
    '	pass := os.Getenv("DB_PASSWORD")' + LineEnding +
    '	name := os.Getenv("DB_NAME")' + LineEnding + LineEnding +
    '	dsn := ' + DSNExpr + LineEnding +
    '	var err error' + LineEnding +
    '	DB, err = sql.Open("' + DriverName + '", dsn)' + LineEnding +
    '	if err != nil {' + LineEnding +
    '		log.Fatalf("Gagal membuka koneksi database: %v", err)' + LineEnding +
    '	}' + LineEnding + LineEnding +
    '	DB.SetMaxOpenConns(25)' + LineEnding +
    '	DB.SetMaxIdleConns(5)' + LineEnding +
    '	DB.SetConnMaxLifetime(5 * time.Minute)' + LineEnding + LineEnding +
    '	if err = DB.Ping(); err != nil {' + LineEnding +
    '		log.Printf("Peringatan: Ping database gagal: %v", err)' + LineEnding +
    '	} else {' + LineEnding +
    '		log.Println("🔌 Berhasil terhubung ke database pool.")' + LineEnding +
    '	}' + LineEnding +
    '}' + LineEnding + LineEnding +
    '// Helper untuk scan baris SQL dinamis ke bentuk map JSON' + LineEnding +
    'func QueryToMapList(db *sql.DB, query string, args ...interface{}) ([]map[string]interface{}, error) {' + LineEnding +
    '	rows, err := db.Query(query, args...)' + LineEnding +
    '	if err != nil {' + LineEnding +
    '		return nil, err' + LineEnding +
    '	}' + LineEnding +
    '	defer rows.Close()' + LineEnding + LineEnding +
    '	cols, err := rows.Columns()' + LineEnding +
    '	if err != nil {' + LineEnding +
    '		return nil, err' + LineEnding +
    '	}' + LineEnding + LineEnding +
    '	var result []map[string]interface{}' + LineEnding +
    '	for rows.Next() {' + LineEnding +
    '		columns := make([]interface{}, len(cols))' + LineEnding +
    '		columnPointers := make([]interface{}, len(cols))' + LineEnding +
    '		for i := range columns {' + LineEnding +
    '			columnPointers[i] = &columns[i]' + LineEnding +
    '		}' + LineEnding +
    '		if err := rows.Scan(columnPointers...); err != nil {' + LineEnding +
    '			return nil, err' + LineEnding +
    '		}' + LineEnding +
    '		m := make(map[string]interface{})' + LineEnding +
    '		for i, colName := range cols {' + LineEnding +
    '			val := columns[i]' + LineEnding +
    '			if b, ok := val.([]byte); ok {' + LineEnding +
    '				m[colName] = string(b)' + LineEnding +
    '			} else {' + LineEnding +
    '				m[colName] = val' + LineEnding +
    '			}' + LineEnding +
    '		}' + LineEnding +
    '		result = append(result, m)' + LineEnding +
    '	}' + LineEnding +
    '	return result, nil' + LineEnding +
    '}';
end;

class function TRESTEngineGoFiber.GenerateAuthMiddleware(AConfig: TRestProjectConfig): string;
begin
  if not AConfig.EnableAuth then
  begin
    Result :=
      'package middleware' + LineEnding + LineEnding +
      'import "github.com/gofiber/fiber/v2"' + LineEnding + LineEnding +
      'func AuthKeyMiddleware() fiber.Handler {' + LineEnding +
      '	return func(c *fiber.Ctx) error {' + LineEnding +
      '		return c.Next()' + LineEnding +
      '	}' + LineEnding +
      '}';
    Exit;
  end;

  Result :=
    'package middleware' + LineEnding + LineEnding +
    'import (' + LineEnding +
    '	"os"' + LineEnding +
    '	"github.com/gofiber/fiber/v2"' + LineEnding +
    ')' + LineEnding + LineEnding +
    'func AuthKeyMiddleware() fiber.Handler {' + LineEnding +
    '	return func(c *fiber.Ctx) error {' + LineEnding +
    '		apiKey := c.Get("x-api-key")' + LineEnding +
    '		if apiKey == "" {' + LineEnding +
    '			apiKey = c.Query("api_key")' + LineEnding +
    '		}' + LineEnding +
    '		validKey := os.Getenv("API_KEY")' + LineEnding +
    '		if apiKey == "" || apiKey != validKey {' + LineEnding +
    '			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{' + LineEnding +
    '				"success": false,' + LineEnding +
    '				"message": "Unauthorized: Header x-api-key tidak valid atau tidak disertakan",' + LineEnding +
    '			})' + LineEnding +
    '		}' + LineEnding +
    '		return c.Next()' + LineEnding +
    '	}' + LineEnding +
    '}';
end;

class function TRESTEngineGoFiber.GenerateTableHandler(AConfig: TRestProjectConfig; ATable: TRestTableConfig): string;
var
  PK, SelectCols: string;
  I: Integer;
  Code: TStringList;
  IsPostgres: Boolean;
begin
  PK := ATable.PrimaryKey;
  if PK = '' then PK := 'id';
  IsPostgres := (AConfig.Profile.DriverType = dtPostgreSQL);

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
    Code.Add('package handlers');
    Code.Add('');
    Code.Add('import (');
    Code.Add('	"fmt"');
    Code.Add('	"math"');
    Code.Add('	"strconv"');
    Code.Add('	"strings"');
    Code.Add('	"github.com/gofiber/fiber/v2"');
    Code.Add('	"' + LowerCase(StringReplace(AConfig.DatabaseName, ' ', '-', [rfReplaceAll])) + '-api/config"');
    Code.Add(')');
    Code.Add('');
    Code.Add(Format('func Register%sRoutes(router fiber.Router) {', [ATable.TableName]));
    Code.Add(Format('	group := router.Group("/%s")', [ATable.CustomRoute]));

    if roList in ATable.AllowedOperations then
      Code.Add(Format('	group.Get("/", Get%sList)', [ATable.TableName]));
    if roDetail in ATable.AllowedOperations then
      Code.Add(Format('	group.Get("/:id", Get%sDetail)', [ATable.TableName]));
    if (roCreate in ATable.AllowedOperations) and not ATable.IsView then
      Code.Add(Format('	group.Post("/", Create%s)', [ATable.TableName]));
    if (roUpdate in ATable.AllowedOperations) and not ATable.IsView then
      Code.Add(Format('	group.Put("/:id", Update%s)', [ATable.TableName]));
    if (roDelete in ATable.AllowedOperations) and not ATable.IsView then
      Code.Add(Format('	group.Delete("/:id", Delete%s)', [ATable.TableName]));

    Code.Add('}');
    Code.Add('');

    // 1. GET LIST & SEARCH
    if roList in ATable.AllowedOperations then
    begin
      Code.Add(Format('func Get%sList(c *fiber.Ctx) error {', [ATable.TableName]));
      Code.Add('	page, _ := strconv.Atoi(c.Query("page", "1"))');
      Code.Add('	limit, _ := strconv.Atoi(c.Query("limit", "20"))');
      Code.Add('	if page < 1 { page = 1 }');
      Code.Add('	if limit < 1 || limit > 100 { limit = 20 }');
      Code.Add('	offset := (page - 1) * limit');
      Code.Add('	search := c.Query("search")');
      Code.Add('');
      Code.Add('	whereClause := ""');
      Code.Add('	var args []interface{}');
      Code.Add('');
      if ATable.SearchableColumns.Count > 0 then
      begin
        Code.Add('	if search != "" {');
        if IsPostgres then
          Code.Add(Format('		whereClause = " WHERE (%s ILIKE $1)"', [ATable.SearchableColumns[0]]))
        else
          Code.Add(Format('		whereClause = " WHERE (%s LIKE ?)"', [ATable.SearchableColumns[0]]));
        Code.Add('		args = append(args, "%"+search+"%")');
        Code.Add('	}');
      end;
      Code.Add('');
      Code.Add(Format('	countQuery := fmt.Sprintf("SELECT COUNT(*) FROM %s%%s", whereClause)', [ATable.TableName]));
      Code.Add('	var total int');
      Code.Add('	if err := config.DB.QueryRow(countQuery, args...).Scan(&total); err != nil {');
      Code.Add('		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": err.Error()})');
      Code.Add('	}');
      Code.Add('');
      if IsPostgres then
      begin
        Code.Add('	args = append(args, limit, offset)');
        Code.Add(Format('	sqlQuery := fmt.Sprintf("SELECT %s FROM %s%%s LIMIT $%d OFFSET $%d", whereClause, len(args)-1, len(args))', [SelectCols, ATable.TableName]));
      end
      else
      begin
        Code.Add('	args = append(args, limit, offset)');
        Code.Add(Format('	sqlQuery := fmt.Sprintf("SELECT %s FROM %s%%s LIMIT ? OFFSET ?", whereClause)', [SelectCols, ATable.TableName]));
      end;
      Code.Add('');
      Code.Add('	data, err := config.QueryToMapList(config.DB, sqlQuery, args...)');
      Code.Add('	if err != nil {');
      Code.Add('		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": err.Error()})');
      Code.Add('	}');
      Code.Add('');
      Code.Add('	totalPages := int(math.Ceil(float64(total) / float64(limit)))');
      Code.Add('	return c.JSON(fiber.Map{');
      Code.Add('		"success": true,');
      Code.Add('		"pagination": fiber.Map{"page": page, "limit": limit, "total": total, "total_pages": totalPages},');
      Code.Add('		"data": data,');
      Code.Add('	})');
      Code.Add('}');
      Code.Add('');
    end;

    // 2. GET DETAIL BY PK
    if roDetail in ATable.AllowedOperations then
    begin
      Code.Add(Format('func Get%sDetail(c *fiber.Ctx) error {', [ATable.TableName]));
      Code.Add('	id := c.Params("id")');
      if IsPostgres then
        Code.Add(Format('	query := "SELECT %s FROM %s WHERE %s = $1"', [SelectCols, ATable.TableName, PK]))
      else
        Code.Add(Format('	query := "SELECT %s FROM %s WHERE %s = ?"', [SelectCols, ATable.TableName, PK]));
      Code.Add('	data, err := config.QueryToMapList(config.DB, query, id)');
      Code.Add('	if err != nil {');
      Code.Add('		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": err.Error()})');
      Code.Add('	}');
      Code.Add('	if len(data) == 0 {');
      Code.Add('		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"success": false, "message": "Data tidak ditemukan"})');
      Code.Add('	}');
      Code.Add('	return c.JSON(fiber.Map{"success": true, "data": data[0]})');
      Code.Add('}');
      Code.Add('');
    end;

    // 3. POST (CREATE)
    if (roCreate in ATable.AllowedOperations) and not ATable.IsView then
    begin
      Code.Add(Format('func Create%s(c *fiber.Ctx) error {', [ATable.TableName]));
      Code.Add('	var payload map[string]interface{}');
      Code.Add('	if err := c.BodyParser(&payload); err != nil || len(payload) == 0 {');
      Code.Add('		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"success": false, "message": "Payload body kosong atau format tidak valid"})');
      Code.Add('	}');
      Code.Add('');
      Code.Add('	var cols, placeholders []string');
      Code.Add('	var values []interface{}');
      Code.Add('	idx := 1');
      Code.Add('	for k, v := range payload {');
      Code.Add('		cols = append(cols, k)');
      if IsPostgres then
        Code.Add('		placeholders = append(placeholders, fmt.Sprintf("$%d", idx))')
      else
        Code.Add('		placeholders = append(placeholders, "?")');
      Code.Add('		values = append(values, v)');
      Code.Add('		idx++');
      Code.Add('	}');
      Code.Add('');
      Code.Add(Format('	sql := fmt.Sprintf("INSERT INTO %s (%%s) VALUES (%%s)", strings.Join(cols, ", "), strings.Join(placeholders, ", "))', [ATable.TableName]));
      Code.Add('	_, err := config.DB.Exec(sql, values...)');
      Code.Add('	if err != nil {');
      Code.Add('		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": err.Error()})');
      Code.Add('	}');
      Code.Add('	return c.Status(fiber.StatusCreated).JSON(fiber.Map{"success": true, "message": "Data berhasil ditambahkan"})');
      Code.Add('}');
      Code.Add('');
    end;

    // 4. PUT (UPDATE)
    if (roUpdate in ATable.AllowedOperations) and not ATable.IsView then
    begin
      Code.Add(Format('func Update%s(c *fiber.Ctx) error {', [ATable.TableName]));
      Code.Add('	id := c.Params("id")');
      Code.Add('	var payload map[string]interface{}');
      Code.Add('	if err := c.BodyParser(&payload); err != nil || len(payload) == 0 {');
      Code.Add('		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"success": false, "message": "Payload body pembaruan kosong"})');
      Code.Add('	}');
      Code.Add('');
      Code.Add('	var setClauses []string');
      Code.Add('	var values []interface{}');
      Code.Add('	idx := 1');
      Code.Add('	for k, v := range payload {');
      if IsPostgres then
        Code.Add('		setClauses = append(setClauses, fmt.Sprintf("%s = $%d", k, idx))')
      else
        Code.Add('		setClauses = append(setClauses, fmt.Sprintf("%s = ?", k))');
      Code.Add('		values = append(values, v)');
      Code.Add('		idx++');
      Code.Add('	}');
      Code.Add('	values = append(values, id)');
      Code.Add('');
      if IsPostgres then
        Code.Add(Format('	sql := fmt.Sprintf("UPDATE %s SET %%s WHERE %s = $%%d", strings.Join(setClauses, ", "), idx)', [ATable.TableName, PK]))
      else
        Code.Add(Format('	sql := fmt.Sprintf("UPDATE %s SET %%s WHERE %s = ?", strings.Join(setClauses, ", "))', [ATable.TableName, PK]));
      Code.Add('');
      Code.Add('	res, err := config.DB.Exec(sql, values...)');
      Code.Add('	if err != nil {');
      Code.Add('		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": err.Error()})');
      Code.Add('	}');
      Code.Add('	affected, _ := res.RowsAffected()');
      Code.Add('	return c.JSON(fiber.Map{"success": true, "affected_rows": affected, "message": "Data berhasil diperbarui"})');
      Code.Add('}');
      Code.Add('');
    end;

    // 5. DELETE
    if (roDelete in ATable.AllowedOperations) and not ATable.IsView then
    begin
      Code.Add(Format('func Delete%s(c *fiber.Ctx) error {', [ATable.TableName]));
      Code.Add('	id := c.Params("id")');
      if IsPostgres then
        Code.Add(Format('	sql := "DELETE FROM %s WHERE %s = $1"', [ATable.TableName, PK]))
      else
        Code.Add(Format('	sql := "DELETE FROM %s WHERE %s = ?"', [ATable.TableName, PK]));
      Code.Add('	res, err := config.DB.Exec(sql, id)');
      Code.Add('	if err != nil {');
      Code.Add('		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": err.Error()})');
      Code.Add('	}');
      Code.Add('	affected, _ := res.RowsAffected()');
      Code.Add('	return c.JSON(fiber.Map{"success": true, "affected_rows": affected, "message": "Data berhasil dihapus"})');
      Code.Add('}');
    end;

    Result := Code.Text;
  finally
    Code.Free;
  end;
end;

class function TRESTEngineGoFiber.GenerateMainGo(AConfig: TRestProjectConfig): string;
var
  I: Integer;
  Code: TStringList;
  Tbl: TRestTableConfig;
  ModName: string;
begin
  ModName := LowerCase(StringReplace(AConfig.DatabaseName, ' ', '-', [rfReplaceAll])) + '-api';
  Code := TStringList.Create;
  try
    Code.Add('package main');
    Code.Add('');
    Code.Add('import (');
    Code.Add('	"fmt"');
    Code.Add('	"log"');
    Code.Add('	"os"');
    Code.Add('	"github.com/gofiber/fiber/v2"');
    Code.Add('	"github.com/gofiber/fiber/v2/middleware/cors"');
    Code.Add('	"github.com/gofiber/fiber/v2/middleware/logger"');
    Code.Add('	"github.com/gofiber/fiber/v2/middleware/recover"');
    Code.Add('	"github.com/joho/godotenv"');
    Code.Add('	"' + ModName + '/config"');
    Code.Add('	"' + ModName + '/handlers"');
    Code.Add('	"' + ModName + '/middleware"');
    Code.Add(')');
    Code.Add('');
    Code.Add('func main() {');
    Code.Add('	_ = godotenv.Load()');
    Code.Add('	config.ConnectDB()');
    Code.Add('	defer config.DB.Close()');
    Code.Add('');
    Code.Add('	app := fiber.New(fiber.Config{');
    Code.Add(Format('		AppName: "%s REST API (siadmin Studio)",', [AConfig.DatabaseName]));
    Code.Add('	})');
    Code.Add('');
    Code.Add('	app.use(recover.New())');
    Code.Add('	app.use(cors.New())');
    Code.Add('	app.use(logger.New())');
    Code.Add('');
    Code.Add('	baseRoute := os.Getenv("BASE_ROUTE")');
    Code.Add('	if baseRoute == "" { baseRoute = "' + AConfig.BaseRoute + '" }');
    Code.Add('');
    Code.Add('	// Root Healthcheck');
    Code.Add('	app.Get("/", func(c *fiber.Ctx) error {');
    Code.Add('		return c.JSON(fiber.Map{');
    Code.Add('			"status": "online",');
    Code.Add('			"engine": "Go Fiber High-Performance REST Engine",');
    Code.Add('			"base_route": baseRoute,');
    Code.Add('		})');
    Code.Add('	})');
    Code.Add('');
    Code.Add('	api := app.Group(baseRoute, middleware.AuthKeyMiddleware())');
    Code.Add('');
    Code.Add('	// Registrasi Route Tabel');
    for I := 0 to AConfig.TableCount - 1 do
    begin
      Tbl := AConfig.Tables[I];
      Code.Add(Format('	handlers.Register%sRoutes(api)', [Tbl.TableName]));
    end;
    Code.Add('');
    Code.Add('	port := os.Getenv("PORT")');
    Code.Add(Format('	if port == "" { port = "%d" }', [AConfig.ServerPort]));
    Code.Add('	log.Printf("🚀 Server Go Fiber aktif di http://localhost:%s%s", port, baseRoute)');
    Code.Add('	log.Fatal(app.Listen(fmt.Sprintf(":%s", port)))');
    Code.Add('}');

    Result := Code.Text;
  finally
    Code.Free;
  end;
end;

class function TRESTEngineGoFiber.GenerateReadme(AConfig: TRestProjectConfig): string;
var
  I: Integer;
begin
  Result :=
    Format('# %s Go (Fiber) REST API Service', [AConfig.DatabaseName]) + LineEnding +
    'Dihasilkan secara otomatis oleh **siadmin Database Studio**.' + LineEnding + LineEnding +
    '## 🚀 Cara Menjalankan' + LineEnding +
    '1. Unduh modul dependensi:' + LineEnding +
    '   ```bash' + LineEnding +
    '   go mod tidy' + LineEnding +
    '   ```' + LineEnding +
    '2. Jalankan server langsung:' + LineEnding +
    '   ```bash' + LineEnding +
    '   go run main.go' + LineEnding +
    '   ```' + LineEnding +
    '3. Atau kompilasi menjadi executable mandiri (*single binary*):' + LineEnding +
    '   ```bash' + LineEnding +
    '   go build -o server' + LineEnding +
    '   ./server' + LineEnding +
    '   ```' + LineEnding + LineEnding +
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

class function TRESTEngineGoFiber.GenerateProject(AConfig: TRestProjectConfig; out AErrorMsg: string): Boolean;
var
  OutDir, CfgDir, HandlersDir, MidDir: string;
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
  HandlersDir := OutDir + 'handlers' + PathDelim;
  MidDir := OutDir + 'middleware' + PathDelim;

  try
    ForceDirectories(CfgDir);
    ForceDirectories(HandlersDir);
    ForceDirectories(MidDir);

    // 1. Root Files
    SaveTextFile(OutDir + 'go.mod', GenerateGoMod(AConfig));
    SaveTextFile(OutDir + '.env', GenerateEnvFile(AConfig));
    SaveTextFile(OutDir + '.gitignore', GenerateGitIgnore);
    SaveTextFile(OutDir + 'README.md', GenerateReadme(AConfig));
    SaveTextFile(OutDir + 'main.go', GenerateMainGo(AConfig));

    // 2. Packages
    SaveTextFile(CfgDir + 'database.go', GenerateDatabaseGo(AConfig));
    SaveTextFile(MidDir + 'auth.go', GenerateAuthMiddleware(AConfig));

    // 3. Handlers per Table
    for I := 0 to AConfig.TableCount - 1 do
    begin
      Tbl := AConfig.Tables[I];
      SaveTextFile(HandlersDir + LowerCase(Tbl.TableName) + '.go', GenerateTableHandler(AConfig, Tbl));
    end;

    Result := True;
  except
    on E: Exception do
      AErrorMsg := E.Message;
  end;
end;

end.
