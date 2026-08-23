unit uSSHTunnelService;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Process, Sockets,
  uAppTypes, uDBTypes, uModelConnection;

type
  { TSSHTunnel }
  TSSHTunnel = class
  private
    FProcess: TProcess;
    FLocalPort: Integer;
    FIsActive: Boolean;
    function FindFreeLocalPort: Integer;
    function IsPortReady(APort: Integer; ATimeoutMS: Integer = 3000): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    function StartTunnel(AProfile: TConnectionProfile; out AErrorMsg: string): Boolean;
    procedure StopTunnel;

    property LocalPort: Integer read FLocalPort;
    property IsActive: Boolean read FIsActive;
  end;

  { TSSHTunnelManager }
  TSSHTunnelManager = class
  private
    class var FTunnels: TFPList;
  public
    class procedure Initialize;
    class procedure Finalize;
    class function OpenTunnel(AProfile: TConnectionProfile; out AErrorMsg: string): TSSHTunnel;
    class procedure CloseTunnel(ATunnel: TSSHTunnel);
  end;

implementation

{ TSSHTunnel }

constructor TSSHTunnel.Create;
begin
  inherited Create;
  FProcess := nil;
  FLocalPort := 0;
  FIsActive := False;
end;

destructor TSSHTunnel.Destroy;
begin
  StopTunnel;
  inherited Destroy;
end;

function TSSHTunnel.FindFreeLocalPort: Integer;
var
  S: TSocket;
  Addr: TInetSockAddr;
  Size: Integer;
begin
  Result := 0;
  S := fpsocket(AF_INET, SOCK_STREAM, 0);
  if S = -1 then Exit;
  try
    FillChar(Addr, SizeOf(Addr), 0);
    Addr.sin_family := AF_INET;
    Addr.sin_addr.s_addr := StrToNetAddr('127.0.0.1').s_addr;
    Addr.sin_port := 0; // OS memilih port kosong secara otomatis

    if fpbind(S, @Addr, SizeOf(Addr)) = 0 then
    begin
      Size := SizeOf(Addr);
      if fpgetsockname(S, @Addr, @Size) = 0 then
        Result := NToHs(Addr.sin_port);
    end;
  finally
    CloseSocket(S);
  end;
end;

function TSSHTunnel.IsPortReady(APort: Integer; ATimeoutMS: Integer): Boolean;
var
  S: TSocket;
  Addr: TInetSockAddr;
  Elapsed: Integer;
begin
  Result := False;
  Elapsed := 0;

  while Elapsed < ATimeoutMS do
  begin
    S := fpsocket(AF_INET, SOCK_STREAM, 0);
    if S <> -1 then
    begin
      try
        FillChar(Addr, SizeOf(Addr), 0);
        Addr.sin_family := AF_INET;
        Addr.sin_addr.s_addr := StrToNetAddr('127.0.0.1').s_addr;
        Addr.sin_port := HToNs(APort);

        if fpconnect(S, @Addr, SizeOf(Addr)) = 0 then
        begin
          Result := True;
          Exit;
        end;
      finally
        CloseSocket(S);
      end;
    end;
    Sleep(100);
    Inc(Elapsed, 100);
  end;
end;

function TSSHTunnel.StartTunnel(AProfile: TConnectionProfile; out AErrorMsg: string): Boolean;
var
  DBRemoteHost: string;
  DBRemotePort: Integer;
begin
  Result := False;
  AErrorMsg := '';
  StopTunnel;

  FLocalPort := FindFreeLocalPort;
  if FLocalPort = 0 then
  begin
    AErrorMsg := 'Gagal menemukan port lokal yang tersedia untuk SSH Tunnel.';
    Exit;
  end;

  DBRemoteHost := AProfile.Host;
  if DBRemoteHost = '' then DBRemoteHost := '127.0.0.1';
  DBRemotePort := AProfile.Port;

  FProcess := TProcess.Create(nil);
  try
    FProcess.Executable := 'ssh';
    FProcess.Options := [poNoConsole];

    // Parameter SSH:
    // -N : Tidak menjalankan command shell remote
    // -L : Forwarding local_port:remote_db_host:remote_db_port
    // -p : Port SSH remote
    FProcess.Parameters.Add('-N');
    FProcess.Parameters.Add('-L');
    FProcess.Parameters.Add(Format('%d:%s:%d', [FLocalPort, DBRemoteHost, DBRemotePort]));
    FProcess.Parameters.Add('-p');
    FProcess.Parameters.Add(IntToStr(AProfile.SSHPort));

    // Konfigurasi bypass prompt verifikasi host key
    FProcess.Parameters.Add('-o');
    FProcess.Parameters.Add('StrictHostKeyChecking=no');
    FProcess.Parameters.Add('-o');
    FProcess.Parameters.Add('UserKnownHostsFile=/dev/null');
    FProcess.Parameters.Add('-o');
    FProcess.Parameters.Add('ExitOnForwardFailure=yes');

    // Identifikasi berkas Private Key
    if Trim(AProfile.SSHKeyPath) <> '' then
    begin
      FProcess.Parameters.Add('-i');
      FProcess.Parameters.Add(Trim(AProfile.SSHKeyPath));
    end;

    FProcess.Parameters.Add(Format('%s@%s', [AProfile.SSHUser, AProfile.SSHHost]));
    FProcess.Execute;

    // Monitor kesiapan port forward
    if IsPortReady(FLocalPort, 4000) then
    begin
      FIsActive := True;
      AProfile.ActiveLocalPort := FLocalPort;
      Result := True;
    end
    else
    begin
      AErrorMsg := 'Timeout: SSH Tunnel gagal merespons atau autentikasi ditolak server.';
      StopTunnel;
    end;
  except
    on E: Exception do
    begin
      AErrorMsg := 'Kesalahan eksekusi SSH CLI: ' + E.Message;
      StopTunnel;
    end;
  end;
end;

procedure TSSHTunnel.StopTunnel;
begin
  if Assigned(FProcess) then
  begin
    try
      if FProcess.Running then
        FProcess.Terminate(0);
    except
    end;
    FreeAndNil(FProcess);
  end;
  FIsActive := False;
  FLocalPort := 0;
end;

{ TSSHTunnelManager }

class procedure TSSHTunnelManager.Initialize;
begin
  FTunnels := TFPList.Create;
end;

class procedure TSSHTunnelManager.Finalize;
var
  I: Integer;
begin
  if Assigned(FTunnels) then
  begin
    for I := 0 to FTunnels.Count - 1 do
      TSSHTunnel(FTunnels[I]).Free;
    FreeAndNil(FTunnels);
  end;
end;

class function TSSHTunnelManager.OpenTunnel(AProfile: TConnectionProfile; out AErrorMsg: string): TSSHTunnel;
begin
  Result := TSSHTunnel.Create;
  if Result.StartTunnel(AProfile, AErrorMsg) then
  begin
    FTunnels.Add(Result);
  end
  else
  begin
    Result.Free;
    Result := nil;
  end;
end;

class procedure TSSHTunnelManager.CloseTunnel(ATunnel: TSSHTunnel);
begin
  if not Assigned(ATunnel) then Exit;
  if Assigned(FTunnels) then
    FTunnels.Remove(ATunnel);
  ATunnel.Free;
end;

initialization
  TSSHTunnelManager.Initialize;

finalization
  TSSHTunnelManager.Finalize;

end.
