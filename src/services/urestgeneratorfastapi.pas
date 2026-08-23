unit uRESTGeneratorFastAPI;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  uAppTypes, uDBTypes, uModelConnection, uModelRESTConfig;

type
  { TRESTEngineFastAPI }
  TRESTEngineFastAPI = class
  private
    class procedure SaveTextFile(const AFilePath, AContent: string);
    class function GenerateRequirements(AConfig: TRestProjectConfig): string;
    class function GenerateEnvFile(AConfig: TRestProjectConfig): string;
    class function GenerateGitIgnore: string;
    class function GenerateDatabasePy(AConfig: TRestProjectConfig): string;
    class function GenerateDependenciesPy(AConfig: TRestProjectConfig): string;
    class function GenerateTableRouter(AConfig: TRestProjectConfig; ATable: TRestTableConfig): string;
    class function GenerateMainPy(AConfig: TRestProjectConfig): string;
    class function GenerateReadme(AConfig: TRestProjectConfig): string;
  public
    class function GenerateProject(AConfig: TRestProjectConfig; out AErrorMsg: string): Boolean;
  end;

implementation

class procedure TRESTEngineFastAPI.SaveTextFile(const AFilePath, AContent: string);
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

class function TRESTEngineFastAPI.GenerateRequirements(AConfig: TRestProjectConfig): string;
var
  DBDriverPkg: string;
begin
  case AConfig.Profile.DriverType of
    dtMySQL, dtMariaDB: DBDriverPkg := 'pymysql>=1.1.0' + LineEnding + 'cryptography>=42.0.0';
    dtPostgreSQL:       DBDriverPkg := 'psycopg2-binary>=2.9.9';
    dtSQLite:           DBDriverPkg := '# SQLite bawaan standar Python';
    dtFirebird:         DBDriverPkg := 'fdb>=2.0.2' + LineEnding + 'sqlalchemy-firebird>=2.0.0';
    else                DBDriverPkg := 'pymysql>=1.1.0';
  end;

  Result :=
    'fastapi>=0.110.0' + LineEnding +
    'uvicorn[standard]>=0.28.0' + LineEnding +
    'pydantic>=2.6.0' + LineEnding +
    'pydantic-settings>=2.2.0' + LineEnding +
    'sqlalchemy>=2.0.28' + LineEnding +
    'python-dotenv>=1.0.1' + LineEnding +
    DBDriverPkg;
end;

class function TRESTEngineFastAPI.GenerateEnvFile(AConfig: TRestProjectConfig): string;
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
    '# Keamanan API Key' + LineEnding +
    Format('API_KEY=%s', [AConfig.ApiKey]);
end;

class function TRESTEngineFastAPI.GenerateGitIgnore: string;
begin
  Result :=
    '__pycache__/' + LineEnding +
    '*.py[cod]' + LineEnding +
    '*$py.class' + LineEnding +
    '.venv/' + LineEnding +
    'venv/' + LineEnding +
    'ENV/' + LineEnding +
    '.env' + LineEnding +
    '*.db' + LineEnding +
    '*.sqlite3' + LineEnding +
    '.DS_Store';
end;

class function TRESTEngineFastAPI.GenerateDatabasePy(AConfig: TRestProjectConfig): string;
var
  DBUrlExpr: string;
begin
  case AConfig.Profile.DriverType of
    dtMySQL, dtMariaDB:
      DBUrlExpr := 'f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}?charset=utf8mb4"';
    dtPostgreSQL:
      DBUrlExpr := 'f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"';
    dtSQLite:
      DBUrlExpr := 'f"sqlite:///{DB_NAME}"';
    dtFirebird:
      DBUrlExpr := 'f"firebird+fdb://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"';
    else
      DBUrlExpr := 'f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"';
  end;

  Result :=
    'import os' + LineEnding +
    'from dotenv import load_dotenv' + LineEnding +
    'from sqlalchemy import create_engine' + LineEnding +
    'from sqlalchemy.orm import sessionmaker' + LineEnding +
    LineEnding +
    'load_dotenv()' + LineEnding +
    LineEnding +
    'DB_HOST = os.getenv("DB_HOST", "localhost")' + LineEnding +
    'DB_PORT = os.getenv("DB_PORT", "3306")' + LineEnding +
    'DB_NAME = os.getenv("DB_NAME", "database")' + LineEnding +
    'DB_USER = os.getenv("DB_USER", "root")' + LineEnding +
    'DB_PASSWORD = os.getenv("DB_PASSWORD", "")' + LineEnding +
    LineEnding +
    'DATABASE_URL = ' + DBUrlExpr + LineEnding +
    LineEnding +
    'engine = create_engine(' + LineEnding +
    '    DATABASE_URL,' + LineEnding +
    '    pool_pre_ping=True,' + LineEnding +
    '    pool_size=10,' + LineEnding +
    '    max_overflow=20' + LineEnding +
    ')' + LineEnding +
    LineEnding +
    'SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)' + LineEnding +
    LineEnding +
    'def get_db():' + LineEnding +
    '    """Dependency generator untuk sesi koneksi database."""' + LineEnding +
    '    db = SessionLocal()' + LineEnding +
    '    try:' + LineEnding +
    '        yield db' + LineEnding +
    '    finally:' + LineEnding +
    '        db.close()' + LineEnding;
end;

class function TRESTEngineFastAPI.GenerateDependenciesPy(AConfig: TRestProjectConfig): string;
begin
  if not AConfig.EnableAuth then
  begin
    Result :=
      'async def verify_api_key():' + LineEnding +
      '    """Autentikasi dinonaktifkan."""' + LineEnding +
      '    return True' + LineEnding;
    Exit;
  end;

  Result :=
    'import os' + LineEnding +
    'from fastapi import Security, HTTPException, status' + LineEnding +
    'from fastapi.security.api_key import APIKeyHeader' + LineEnding +
    'from dotenv import load_dotenv' + LineEnding +
    LineEnding +
    'load_dotenv()' + LineEnding +
    'API_KEY_NAME = "x-api-key"' + LineEnding +
    'api_key_header = APIKeyHeader(name=API_KEY_NAME, auto_error=False)' + LineEnding +
    LineEnding +
    'async def verify_api_key(api_key: str = Security(api_key_header)):' + LineEnding +
    '    valid_key = os.getenv("API_KEY")' + LineEnding +
    '    if not api_key or api_key != valid_key:' + LineEnding +
    '        raise HTTPException(' + LineEnding +
    '            status_code=status.HTTP_401_UNAUTHORIZED,' + LineEnding +
    '            detail="Akses Ditolak: Header x-api-key tidak valid atau tidak disertakan"' + LineEnding +
    '        )' + LineEnding +
    '    return api_key' + LineEnding;
end;

class function TRESTEngineFastAPI.GenerateTableRouter(AConfig: TRestProjectConfig; ATable: TRestTableConfig): string;
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
    Code.Add('from typing import Any, Dict, List, Optional');
    Code.Add('import math');
    Code.Add('from fastapi import APIRouter, Depends, HTTPException, Query, status');
    Code.Add('from sqlalchemy.orm import Session');
    Code.Add('from sqlalchemy import text');
    Code.Add('from app.database import get_db');
    Code.Add('from app.dependencies import verify_api_key');
    Code.Add('');
    Code.Add(Format('router = APIRouter(prefix="/%s", tags=["%s"], dependencies=[Depends(verify_api_key)])', [ATable.CustomRoute, ATable.TableName]));
    Code.Add('');

    // 1. GET ALL (LIST & SEARCH)
    if roList in ATable.AllowedOperations then
    begin
      Code.Add('@router.get("/", summary="Ambil Daftar Data")');
      Code.Add('def get_all(');
      Code.Add('    page: int = Query(1, ge=1, description="Nomor halaman"),');
      Code.Add('    limit: int = Query(20, ge=1, le=100, description="Jumlah data per halaman"),');
      Code.Add('    search: Optional[str] = Query(None, description="Kata kunci pencarian"),');
      Code.Add('    db: Session = Depends(get_db)');
      Code.Add('):');
      Code.Add('    offset = (page - 1) * limit');
      Code.Add('    where_clause = ""');
      Code.Add('    params = {"limit": limit, "offset": offset}');
      Code.Add('');
      if ATable.SearchableColumns.Count > 0 then
      begin
        Code.Add('    if search:');
        Code.Add(Format('        where_clause = " WHERE (%s LIKE :search)"', [ATable.SearchableColumns[0]]));
        Code.Add('        params["search"] = f"%{search}%"');
      end;
      Code.Add(Format('    sql = f"SELECT %s FROM %s{where_clause} LIMIT :limit OFFSET :offset"', [SelectCols, ATable.TableName]));
      Code.Add('    rows = db.execute(text(sql), params).mappings().all()');
      Code.Add('');
      Code.Add(Format('    count_sql = f"SELECT COUNT(*) as total FROM %s{where_clause}"', [ATable.TableName]));
      Code.Add('    total = db.execute(text(count_sql), params).scalar() or 0');
      Code.Add('');
      Code.Add('    return {');
      Code.Add('        "success": True,');
      Code.Add('        "pagination": {');
      Code.Add('            "page": page,');
      Code.Add('            "limit": limit,');
      Code.Add('            "total": total,');
      Code.Add('            "total_pages": math.ceil(total / limit)');
      Code.Add('        },');
      Code.Add('        "data": [dict(r) for r in rows]');
      Code.Add('    }');
      Code.Add('');
    end;

    // 2. GET DETAIL BY PK
    if roDetail in ATable.AllowedOperations then
    begin
      Code.Add('@router.get("/{item_id}", summary="Ambil Detail Data Berdasarkan Primary Key")');
      Code.Add('def get_one(item_id: Any, db: Session = Depends(get_db)):');
      Code.Add(Format('    sql = "SELECT %s FROM %s WHERE %s = :id"', [SelectCols, ATable.TableName, PK]));
      Code.Add('    row = db.execute(text(sql), {"id": item_id}).mappings().first()');
      Code.Add('    if not row:');
      Code.Add('        raise HTTPException(status_code=404, detail="Data tidak ditemukan")');
      Code.Add('    return {"success": True, "data": dict(row)}');
      Code.Add('');
    end;

    // 3. POST (CREATE)
    if (roCreate in ATable.AllowedOperations) and not ATable.IsView then
    begin
      Code.Add('@router.post("/", status_code=status.HTTP_201_CREATED, summary="Tambah Data Baru")');
      Code.Add('def create_item(payload: Dict[str, Any], db: Session = Depends(get_db)):');
      Code.Add('    if not payload:');
      Code.Add('        raise HTTPException(status_code=400, detail="Payload body tidak boleh kosong")');
      Code.Add('    keys = list(payload.keys())');
      Code.Add('    placeholders = [f":{k}" for k in keys]');
      Code.Add(Format('    sql = f"INSERT INTO %s ({'', ''.join(keys)}) VALUES ({'', ''.join(placeholders)})"', [ATable.TableName]));
      Code.Add('    try:');
      Code.Add('        db.execute(text(sql), payload)');
      Code.Add('        db.commit()');
      Code.Add('        return {"success": True, "message": "Data berhasil ditambahkan"}');
      Code.Add('    except Exception as e:');
      Code.Add('        db.rollback()');
      Code.Add('        raise HTTPException(status_code=500, detail=str(e))');
      Code.Add('');
    end;

    // 4. PUT (UPDATE)
    if (roUpdate in ATable.AllowedOperations) and not ATable.IsView then
    begin
      Code.Add('@router.put("/{item_id}", summary="Perbarui Data")');
      Code.Add('def update_item(item_id: Any, payload: Dict[str, Any], db: Session = Depends(get_db)):');
      Code.Add('    if not payload:');
      Code.Add('        raise HTTPException(status_code=400, detail="Payload pembaruan kosong")');
      Code.Add('    set_clauses = [f"{k} = :{k}" for k in payload.keys()]');
      Code.Add(Format('    sql = f"UPDATE %s SET {'', ''.join(set_clauses)} WHERE %s = :__pk_id"', [ATable.TableName, PK]));
      Code.Add('    params = {**payload, "__pk_id": item_id}');
      Code.Add('    try:');
      Code.Add('        result = db.execute(text(sql), params)');
      Code.Add('        db.commit()');
      Code.Add('        if result.rowcount == 0:');
      Code.Add('            raise HTTPException(status_code=404, detail="Data tidak ditemukan untuk diperbarui")');
      Code.Add('        return {"success": True, "affected_rows": result.rowcount, "message": "Data berhasil diperbarui"}');
      Code.Add('    except HTTPException:');
      Code.Add('        raise');
      Code.Add('    except Exception as e:');
      Code.Add('        db.rollback()');
      Code.Add('        raise HTTPException(status_code=500, detail=str(e))');
      Code.Add('');
    end;

    // 5. DELETE
    if (roDelete in ATable.AllowedOperations) and not ATable.IsView then
    begin
      Code.Add('@router.delete("/{item_id}", summary="Hapus Data")');
      Code.Add('def delete_item(item_id: Any, db: Session = Depends(get_db)):');
      Code.Add(Format('    sql = "DELETE FROM %s WHERE %s = :id"', [ATable.TableName, PK]));
      Code.Add('    try:');
      Code.Add('        result = db.execute(text(sql), {"id": item_id})');
      Code.Add('        db.commit()');
      Code.Add('        if result.rowcount == 0:');
      Code.Add('            raise HTTPException(status_code=404, detail="Data tidak ditemukan untuk dihapus")');
      Code.Add('        return {"success": True, "affected_rows": result.rowcount, "message": "Data berhasil dihapus"}');
      Code.Add('    except HTTPException:');
      Code.Add('        raise');
      Code.Add('    except Exception as e:');
      Code.Add('        db.rollback()');
      Code.Add('        raise HTTPException(status_code=500, detail=str(e))');
    end;

    Result := Code.Text;
  finally
    Code.Free;
  end;
end;

class function TRESTEngineFastAPI.GenerateMainPy(AConfig: TRestProjectConfig): string;
var
  I: Integer;
  Code: TStringList;
  Tbl: TRestTableConfig;
begin
  Code := TStringList.Create;
  try
    Code.Add('import os');
    Code.Add('from fastapi import FastAPI');
    Code.Add('from fastapi.middleware.cors import CORSMiddleware');
    Code.Add('from dotenv import load_dotenv');
    Code.Add('');
    Code.Add('load_dotenv()');
    Code.Add('');
    Code.Add('BASE_ROUTE = os.getenv("BASE_ROUTE", "' + AConfig.BaseRoute + '")');
    Code.Add('');
    Code.Add('app = FastAPI(');
    Code.Add(Format('    title="%s REST API Service",', [AConfig.DatabaseName]));
    Code.Add('    description="REST API Service yang dihasilkan secara otomatis oleh siadmin Database Studio.",');
    Code.Add('    version="1.0.0",');
    Code.Add('    docs_url=f"{BASE_ROUTE}/docs",');
    Code.Add('    redoc_url=f"{BASE_ROUTE}/redoc",');
    Code.Add('    openapi_url=f"{BASE_ROUTE}/openapi.json"');
    Code.Add(')');
    Code.Add('');
    Code.Add('app.add_middleware(');
    Code.Add('    CORSMiddleware,');
    Code.Add('    allow_origins=["*"],');
    Code.Add('    allow_credentials=True,');
    Code.Add('    allow_methods=["*"],');
    Code.Add('    allow_headers=["*"],');
    Code.Add(')');
    Code.Add('');
    Code.Add('// Root Healthcheck');
    Code.Add('@app.get("/", tags=["Healthcheck"])');
    Code.Add('def root_health():');
    Code.Add('    return {');
    Code.Add('        "status": "online",');
    Code.Add('        "service": "siadmin FastAPI REST Service",');
    Code.Add('        "docs": f"{BASE_ROUTE}/docs"');
    Code.Add('    }');
    Code.Add('');
    Code.Add('# Registrasi Routers');
    for I := 0 to AConfig.TableCount - 1 do
    begin
      Tbl := AConfig.Tables[I];
      Code.Add(Format('from app.routers.%s import router as %s_router', [Tbl.TableName, Tbl.TableName]));
      Code.Add(Format('app.include_router(%s_router, prefix=BASE_ROUTE)', [Tbl.TableName]));
    end;
    Code.Add('');
    Code.Add('if __name__ == "__main__":');
    Code.Add('    import uvicorn');
    Code.Add(Format('    port = int(os.getenv("PORT", %d))', [AConfig.ServerPort]));
    Code.Add('    uvicorn.run("app.main:app", host="0.0.0.0", port=port, reload=True)');

    Result := Code.Text;
  finally
    Code.Free;
  end;
end;

class function TRESTEngineFastAPI.GenerateReadme(AConfig: TRestProjectConfig): string;
var
  I: Integer;
begin
  Result :=
    Format('# %s FastAPI REST API', [AConfig.DatabaseName]) + LineEnding +
    'Dihasilkan secara otomatis oleh **siadmin Database Studio**.' + LineEnding + LineEnding +
    '## 🚀 Cara Menjalankan' + LineEnding +
    '1. Buat dan aktifkan Virtual Environment:' + LineEnding +
    '   ```bash' + LineEnding +
    '   python -m venv venv' + LineEnding +
    '   # Windows:' + LineEnding +
    '   venv\Scripts\activate' + LineEnding +
    '   # Linux / macOS:' + LineEnding +
    '   source venv/bin/activate' + LineEnding +
    '   ```' + LineEnding +
    '2. Pasang dependensi:' + LineEnding +
    '   ```bash' + LineEnding +
    '   pip install -r requirements.txt' + LineEnding +
    '   ```' + LineEnding +
    '3. Jalankan server Uvicorn:' + LineEnding +
    '   ```bash' + LineEnding +
    Format('   uvicorn app.main:app --reload --port %d', [AConfig.ServerPort]) + LineEnding +
    '   ```' + LineEnding + LineEnding +
    '## 📖 Dokumentasi Interaktif (Swagger UI)' + LineEnding +
    Format('* **Swagger UI** : `http://localhost:%d%s/docs`' + LineEnding, [AConfig.ServerPort, AConfig.BaseRoute]) +
    Format('* **ReDoc**      : `http://localhost:%d%s/redoc`' + LineEnding, [AConfig.ServerPort, AConfig.BaseRoute]) + LineEnding +
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

class function TRESTEngineFastAPI.GenerateProject(AConfig: TRestProjectConfig; out AErrorMsg: string): Boolean;
var
  OutDir, AppDir, RoutersDir: string;
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
  AppDir := OutDir + 'app' + PathDelim;
  RoutersDir := AppDir + 'routers' + PathDelim;

  try
    ForceDirectories(RoutersDir);

    // 1. Root Files
    SaveTextFile(OutDir + 'requirements.txt', GenerateRequirements(AConfig));
    SaveTextFile(OutDir + '.env', GenerateEnvFile(AConfig));
    SaveTextFile(OutDir + '.gitignore', GenerateGitIgnore);
    SaveTextFile(OutDir + 'README.md', GenerateReadme(AConfig));

    // 2. App Package Files
    SaveTextFile(AppDir + '__init__.py', '');
    SaveTextFile(RoutersDir + '__init__.py', '');
    SaveTextFile(AppDir + 'database.py', GenerateDatabasePy(AConfig));
    SaveTextFile(AppDir + 'dependencies.py', GenerateDependenciesPy(AConfig));
    SaveTextFile(AppDir + 'main.py', GenerateMainPy(AConfig));

    // 3. Routers per Table
    for I := 0 to AConfig.TableCount - 1 do
    begin
      Tbl := AConfig.Tables[I];
      SaveTextFile(RoutersDir + Tbl.TableName + '.py', GenerateTableRouter(AConfig, Tbl));
    end;

    Result := True;
  except
    on E: Exception do
      AErrorMsg := E.Message;
  end;
end;

end.
