unit uFrameDBTerminal;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Buttons, LCLType, Clipbrd, StrUtils,
  ZConnection, ZDataset, DB,
  uAppTypes, uDBTypes, uModelConnection, uDBDriverBase, uDBConnectionFactory,
  uModelSchemaObject;

type
  { TFrameDBTerminal }
  TFrameDBTerminal = class(TFrame)
    pnlMain: TPanel;
    pnlToolbar: TPanel;
    btnRun: TSpeedButton;
    btnClearScreen: TSpeedButton;
    btnCopyAll: TSpeedButton;
    lblConnStatus: TLabel;

    memTerminal: TMemo;
    pnlPrompt: TPanel;
    lblPrompt: TLabel;
    edtCommand: TEdit;

    procedure btnClearScreenClick(Sender: TObject);
    procedure btnCopyAllClick(Sender: TObject);
    procedure btnRunClick(Sender: TObject);
    procedure edtCommandKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    FProfile: TConnectionProfile;
    FDatabaseTarget: string;
    FCommandHistory: TStringList;
    FHistoryIndex: Integer;

    procedure PrintLine(const AText: string = '');
    procedure PrintWelcomeBanner;
    procedure UpdatePromptLabel;
    procedure ProcessCommand(const AInput: string);
    procedure ExecuteMetaCommand(const ACmd, AParam: string);
    procedure ExecuteSQLStatement(const ASQL: string);
    function RenderDataSetToAsciiTable(AQry: TZQuery): string;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure InitTerminal(AProfile: TConnectionProfile; const ADBTarget: string = '');
    procedure SetActiveDatabase(const ADBName: string);
  end;

implementation

{$R *.lfm}

{ TFrameDBTerminal }

constructor TFrameDBTerminal.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FProfile := TConnectionProfile.Create;
  FDatabaseTarget := '';
  FCommandHistory := TStringList.Create;
  FHistoryIndex := -1;

  memTerminal.Clear;
  PrintWelcomeBanner;
end;

destructor TFrameDBTerminal.Destroy;
begin
  FreeAndNil(FCommandHistory);
  FreeAndNil(FProfile);
  inherited Destroy;
end;

procedure TFrameDBTerminal.InitTerminal(AProfile: TConnectionProfile; const ADBTarget: string);
begin
  if Assigned(AProfile) then
    FProfile.Assign(AProfile);

  if ADBTarget <> '' then
    FDatabaseTarget := ADBTarget
  else if Assigned(AProfile) then
    FDatabaseTarget := AProfile.DatabaseName;

  UpdatePromptLabel;
  PrintLine(Format('[INFO] Terhubung ke sesi terminal: %s (%s)', [
    FProfile.ConnectionName, FProfile.GetDisplayName
  ]));
  PrintLine('Ketik "\?" atau "\help" untuk melihat daftar perintah internal.');
  PrintLine('');
end;

procedure TFrameDBTerminal.SetActiveDatabase(const ADBName: string);
begin
  FDatabaseTarget := ADBName;
  UpdatePromptLabel;
  PrintLine(Format('[INFO] Database aktif dialihkan ke: "%s"', [ADBName]));
end;

procedure TFrameDBTerminal.UpdatePromptLabel;
var
  DBName, DriverStr: string;
begin
  if FDatabaseTarget <> '' then
    DBName := FDatabaseTarget
  else
    DBName := 'default';

  case FProfile.DriverType of
    dtMySQL:      DriverStr := 'mysql';
    dtMariaDB:    DriverStr := 'mariadb';
    dtPostgreSQL: DriverStr := 'postgres';
    dtSQLite:     DriverStr := 'sqlite';
    dtFirebird:   DriverStr := 'firebird';
    else          DriverStr := 'db';
  end;

  lblPrompt.Caption := Format('%s@%s[%s]> ', [FProfile.Username, DriverStr, DBName]);
  lblConnStatus.Caption := Format('Sesi Aktif: %s | DB: %s', [FProfile.ConnectionName, DBName]);
end;

procedure TFrameDBTerminal.PrintLine(const AText: string);
begin
  memTerminal.Lines.Add(AText);
  memTerminal.SelStart := Length(memTerminal.Text);
end;

procedure TFrameDBTerminal.PrintWelcomeBanner;
begin
  PrintLine('========================================================================');
  PrintLine('              ADMIRAL INTERACTIVE DATABASE CLI TERMINAL                 ');
  PrintLine('========================================================================');
  PrintLine('Eksekusi perintah SQL atau meta-command CLI secara langsung.');
  PrintLine('Gunakan tombol Panah Atas / Bawah untuk menelusuri riwayat perintah.');
  PrintLine('');
end;

function TFrameDBTerminal.RenderDataSetToAsciiTable(AQry: TZQuery): string;
var
  ColCount, I: Integer;
  ColWidths: array of Integer;
  ColName, ValStr, LineBorder, LineHeader, LineRow: string;
begin
  ColCount := AQry.FieldCount;
  if ColCount = 0 then
  begin
    Result := '(Kueri selesai tanpa kolom hasil)';
    Exit;
  end;

  SetLength(ColWidths, ColCount);

  // 1. Hitung lebar kolom minimum dari nama kolom
  for I := 0 to ColCount - 1 do
  begin
    ColWidths[I] := Length(AQry.Fields[I].FieldName);
    if ColWidths[I] < 4 then ColWidths[I] := 4;
  end;

  // 2. Scan lebar konten baris (maksimal 100 baris pertama untuk efisiensi)
  AQry.DisableControls;
  try
    AQry.First;
    while not AQry.EOF and (AQry.RecNo <= 100) do
    begin
      for I := 0 to ColCount - 1 do
      begin
        ValStr := AQry.Fields[I].AsString;
        if Length(ValStr) > ColWidths[I] then
        begin
          if Length(ValStr) > 40 then
            ColWidths[I] := 40 // Truncate limit lebar kolom tabel
          else
            ColWidths[I] := Length(ValStr);
        end;
      end;
      AQry.Next;
    end;

    // 3. Bangun Garis Pembatas Header (+------+------+)
    LineBorder := '+';
    for I := 0 to ColCount - 1 do
      LineBorder := LineBorder + StringOfChar('-', ColWidths[I] + 2) + '+';

    // 4. Bangun Baris Header Kolom (| col1 | col2 |)
    LineHeader := '|';
    for I := 0 to ColCount - 1 do
    begin
      ColName := AQry.Fields[I].FieldName;
      LineHeader := LineHeader + ' ' + PadRight(ColName, ColWidths[I]) + ' |';
    end;

    Result := LineBorder + sLineBreak + LineHeader + sLineBreak + LineBorder + sLineBreak;

    // 5. Bangun Baris Data
    AQry.First;
    while not AQry.EOF do
    begin
      LineRow := '|';
      for I := 0 to ColCount - 1 do
      begin
        if AQry.Fields[I].IsNull then
          ValStr := 'NULL'
        else
          ValStr := AQry.Fields[I].AsString;

        if Length(ValStr) > ColWidths[I] then
          ValStr := Copy(ValStr, 1, ColWidths[I] - 3) + '...';

        LineRow := LineRow + ' ' + PadRight(ValStr, ColWidths[I]) + ' |';
      end;
      Result := Result + LineRow + sLineBreak;
      AQry.Next;
    end;

    Result := Result + LineBorder;
  finally
    AQry.EnableControls;
  end;
end;

procedure TFrameDBTerminal.ExecuteSQLStatement(const ASQL: string);
var
  Conn: TZConnection;
  Qry: TZQuery;
  StartTime: QWord;
  ElapsedMS: Int64;
begin
  Conn := TZConnection.Create(nil);
  Qry := TZQuery.Create(nil);
  try
    case FProfile.DriverType of
      dtMySQL:      Conn.Protocol := 'mysql';
      dtMariaDB:    Conn.Protocol := 'mariadb';
      dtPostgreSQL: Conn.Protocol := 'postgresql';
      dtSQLite:     Conn.Protocol := 'sqlite';
      dtFirebird:   Conn.Protocol := 'firebird';
    end;
    Conn.HostName := FProfile.Host;
    Conn.Port := FProfile.Port;
    if FDatabaseTarget <> '' then
      Conn.Database := FDatabaseTarget
    else
      Conn.Database := FProfile.DatabaseName;
    Conn.User := FProfile.Username;
    Conn.Password := FProfile.Password;
    Conn.AutoCommit := True;

    StartTime := GetTickCount64;
    try
      Conn.Connect;
      Qry.Connection := Conn;
      Qry.SQL.Text := ASQL;

      // Jika statement SELECT/SHOW/EXPLAIN
      if UpperCase(Copy(Trim(ASQL), 1, 6)) = 'SELECT' then
      begin
        Qry.Open;
        ElapsedMS := GetTickCount64 - StartTime;
        PrintLine(RenderDataSetToAsciiTable(Qry));
        PrintLine(Format('(%d baris data, Waktu: %d ms)', [Qry.RecordCount, ElapsedMS]));
      end
      else
      begin
        Qry.ExecSQL;
        ElapsedMS := GetTickCount64 - StartTime;
        PrintLine(Format('Query OK, %d baris terpengaruh (Waktu: %d ms).', [Qry.RowsAffected, ElapsedMS]));
      end;
    except
      on E: Exception do
      begin
        ElapsedMS := GetTickCount64 - StartTime;
        PrintLine(Format('ERROR (%d ms): %s', [ElapsedMS, E.Message]));
      end;
    end;
  finally
    Qry.Free;
    Conn.Free;
  end;
end;

procedure TFrameDBTerminal.ExecuteMetaCommand(const ACmd, AParam: string);
var
  Driver: TDBDriverBase;
  DBList: TStringList;
  Tables: TSchemaObjectList;
  Cols: TSchemaColumnList;
  I: Integer;
  ValStr: string;
begin
  if (ACmd = '\?') or (ACmd = '\help') or (ACmd = 'help') then
  begin
    PrintLine('Daftar Perintah Internal CLI:');
    PrintLine('  \l, \databases       : Menampilkan daftar seluruh database pada server');
    PrintLine('  \dt, \tables        : Menampilkan daftar tabel pada database aktif');
    PrintLine('  \d <nama_tabel>     : Menampilkan struktur kolom tabel');
    PrintLine('  \c <nama_db>        : Mengganti database aktif');
    PrintLine('  \status             : Menampilkan rincian informasi koneksi aktif');
    PrintLine('  \clear, \cls        : Membersihkan layar terminal');
    PrintLine('  <SQL Query>;        : Mengeksekusi query SQL standar (SELECT, INSERT, UPDATE, DDL)');
    Exit;
  end;

  if (ACmd = '\clear') or (ACmd = '\cls') or (ACmd = 'clear') or (ACmd = 'cls') then
  begin
    memTerminal.Clear;
    PrintWelcomeBanner;
    Exit;
  end;

  if ACmd = '\status' then
  begin
    PrintLine('Status Koneksi:');
    PrintLine('  Nama Profil : ' + FProfile.ConnectionName);
    PrintLine('  Host / Port : ' + FProfile.Host + ':' + IntToStr(FProfile.Port));
    PrintLine('  User        : ' + FProfile.Username);
    PrintLine('  Database    : ' + FDatabaseTarget);
    PrintLine('  Driver DBMS : ' + FProfile.GetDisplayName);
    Exit;
  end;

  if (ACmd = '\c') or (ACmd = '\use') or (ACmd = 'use') then
  begin
    if AParam = '' then
      PrintLine('Gunakan: \c <nama_database>')
    else
      SetActiveDatabase(AParam);
    Exit;
  end;

  Driver := nil;
  try
    Driver := TDBConnectionFactory.CreateDriver(FProfile);

    // Daftar Database
    if (ACmd = '\l') or (ACmd = '\databases') then
    begin
      DBList := TStringList.Create;
      try
        Driver.ExtractDatabases(DBList);
        PrintLine('+------------------------------------------+');
        PrintLine('| Daftar Database                          |');
        PrintLine('+------------------------------------------+');
        for I := 0 to DBList.Count - 1 do
          PrintLine('| ' + PadRight(DBList[I], 40) + ' |');
        PrintLine('+------------------------------------------+');
        PrintLine(Format('(%d database ditemukan)', [DBList.Count]));
      finally
        DBList.Free;
      end;
      Exit;
    end;

    // Daftar Tabel
    if (ACmd = '\dt') or (ACmd = '\tables') then
    begin
      Tables := TSchemaObjectList.Create(True);
      try
        Driver.ExtractTables(FDatabaseTarget, '', Tables);
        PrintLine('+------------------------------------------+');
        PrintLine('| Daftar Tabel                             |');
        PrintLine('+------------------------------------------+');
        for I := 0 to Tables.Count - 1 do
          PrintLine('| ' + PadRight(Tables[I].Name, 40) + ' |');
        PrintLine('+------------------------------------------+');
        PrintLine(Format('(%d tabel ditemukan di database "%s")', [Tables.Count, FDatabaseTarget]));
      finally
        Tables.Free;
      end;
      Exit;
    end;

    // Deskripsi Struktur Kolom Tabel
    if (ACmd = '\d') or (ACmd = '\desc') or (ACmd = 'desc') or (ACmd = 'describe') then
    begin
      if AParam = '' then
      begin
        PrintLine('Gunakan: \d <nama_tabel>');
        Exit;
      end;

      Cols := TSchemaColumnList.Create(True);
      try
        Driver.ExtractColumns(FDatabaseTarget, '', AParam, Cols);
        if Cols.Count = 0 then
        begin
          PrintLine(Format('Tabel "%s" tidak ditemukan atau tidak memiliki kolom.', [AParam]));
          Exit;
        end;

        PrintLine('+----------------------+----------------------+--------+');
        PrintLine('| Nama Kolom           | Tipe Data            | Key    |');
        PrintLine('+----------------------+----------------------+--------+');
        for I := 0 to Cols.Count - 1 do
        begin
          ValStr := '-';
          if Cols[I].IsPrimaryKey then ValStr := 'PK';
          PrintLine(Format('| %s | %s | %s |', [
            PadRight(Cols[I].Name, 20),
            PadRight(Cols[I].DataType, 20),
            PadRight(ValStr, 6)
          ]));
        end;
        PrintLine('+----------------------+----------------------+--------+');
      finally
        Cols.Free;
      end;
      Exit;
    end;

    PrintLine(Format('Perintah "%s" tidak dikenal. Ketik \? untuk bantuan.', [ACmd]));
  finally
    if Assigned(Driver) then Driver.Free;
  end;
end;

procedure TFrameDBTerminal.ProcessCommand(const AInput: string);
var
  CleanInput, Cmd, Param: string;
  SpacePos: Integer;
begin
  CleanInput := Trim(AInput);
  if CleanInput = '' then Exit;

  // Catat baris perintah di riwayat terminal
  PrintLine(lblPrompt.Caption + CleanInput);

  // Simpan ke command history buffer
  FCommandHistory.Add(CleanInput);
  FHistoryIndex := FCommandHistory.Count;

  // Cek apakah perintah internal atau kueri SQL
  if (CleanInput[1] = '\') or SameText(Copy(CleanInput, 1, 4), 'use ') or
     SameText(Copy(CleanInput, 1, 5), 'desc ') or SameText(CleanInput, 'clear') or
     SameText(CleanInput, 'cls') or SameText(CleanInput, 'help') then
  begin
    SpacePos := Pos(' ', CleanInput);
    if SpacePos > 0 then
    begin
      Cmd := Copy(CleanInput, 1, SpacePos - 1);
      Param := Trim(Copy(CleanInput, SpacePos + 1, Length(CleanInput)));
    end
    else
    begin
      Cmd := CleanInput;
      Param := '';
    end;
    ExecuteMetaCommand(LowerCase(Cmd), Param);
  end
  else
  begin
    ExecuteSQLStatement(CleanInput);
  end;

  PrintLine('');
  edtCommand.Clear;
end;

procedure TFrameDBTerminal.edtCommandKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  // Enter = Eksekusi
  if Key = VK_RETURN then
  begin
    ProcessCommand(edtCommand.Text);
    Key := 0;
  end
  // Panah Atas = Riwayat Sebelumnya
  else if Key = VK_UP then
  begin
    if (FCommandHistory.Count > 0) and (FHistoryIndex > 0) then
    begin
      Dec(FHistoryIndex);
      edtCommand.Text := FCommandHistory[FHistoryIndex];
      edtCommand.SelStart := Length(edtCommand.Text);
    end;
    Key := 0;
  end
  // Panah Bawah = Riwayat Berikutnya
  else if Key = VK_DOWN then
  begin
    if FHistoryIndex < FCommandHistory.Count - 1 then
    begin
      Inc(FHistoryIndex);
      edtCommand.Text := FCommandHistory[FHistoryIndex];
      edtCommand.SelStart := Length(edtCommand.Text);
    end
    else
    begin
      FHistoryIndex := FCommandHistory.Count;
      edtCommand.Clear;
    end;
    Key := 0;
  end;
end;

procedure TFrameDBTerminal.btnRunClick(Sender: TObject);
begin
  ProcessCommand(edtCommand.Text);
end;

procedure TFrameDBTerminal.btnClearScreenClick(Sender: TObject);
begin
  ExecuteMetaCommand('\clear', '');
end;

procedure TFrameDBTerminal.btnCopyAllClick(Sender: TObject);
begin
  Clipboard.AsText := memTerminal.Text;
  MessageDlg('Sukses', 'Seluruh teks log terminal disalin ke Clipboard.', mtInformation, [mbOK], 0);
end;

end.
