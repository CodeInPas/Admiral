unit uAIService;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils, SyncObjs,
  fphttpclient, opensslsockets,
  fpjson, jsonparser;

type
  { Provider AI yang Didukung }
  TAIProviderType = (aipGemini, aipLlamaCpp);

  { Konfigurasi Layanan AI }
  TAIConfig = class
  public
    Provider: TAIProviderType;
    GeminiApiKey: string;
    GeminiModel: string;
    LlamaEndpoint: string;
    LlamaModel: string;
    LlamaApiKey: string;
    Temperature: Double;
    MaxTokens: Integer;
    TimeoutSec: Integer;

    constructor Create;
    procedure Assign(ASource: TAIConfig);
    procedure LoadFromFile(const AFileName: string);
    procedure SaveToFile(const AFileName: string);
  end;

  { Event Callback Asinkron }
  TAISuccessEvent = procedure(Sender: TObject; const AResponseText: string; const AElapsedMS: Int64) of object;
  TAIErrorEvent = procedure(Sender: TObject; const AErrorMessage: string) of object;

  { Thread Pekerja Eksekusi AI Latar Belakang (Non-Blocking) }
  TAIWorkerThread = class(TThread)
  private
    FConfig: TAIConfig;
    FPrompt: string;
    FSystemPrompt: string;
    FResponseText: string;
    FErrorMessage: string;
    FElapsedMS: Int64;
    FOnSuccess: TAISuccessEvent;
    FOnError: TAIErrorEvent;

    procedure DoSuccess;
    procedure DoError;
    function CallGeminiAPI: string;
    function CallLlamaCppAPI: string;
    procedure SetupHttpClient(AHTTP: TFPHTTPClient);
  protected
    procedure Execute; override;
  public
    constructor Create(
      AConfig: TAIConfig;
      const APrompt: string;
      const ASystemPrompt: string = '';
      AOnSuccess: TAISuccessEvent = nil;
      AOnError: TAIErrorEvent = nil
    );
    destructor Destroy; override;
    procedure Cancel;
  end;

  { Singleton Service Manager AI }
  TAIService = class
  private
    FLock: TCriticalSection;
    FConfig: TAIConfig;
    FConfigFile: string;
    FActiveWorkers: TList;
    procedure HandleWorkerTerminated(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;

    function ExecutePromptAsync(
      const APrompt: string;
      const ASystemPrompt: string;
      AOnSuccess: TAISuccessEvent;
      AOnError: TAIErrorEvent
    ): TAIWorkerThread;

    procedure CancelWorker(AWorker: TAIWorkerThread);
    procedure CancelAllRequests;

    property Config: TAIConfig read FConfig;
    property ConfigFile: string read FConfigFile write FConfigFile;
  end;

function AIService: TAIService;

implementation

var
  GAIService: TAIService = nil;

function AIService: TAIService;
begin
  if not Assigned(GAIService) then
    GAIService := TAIService.Create;
  Result := GAIService;
end;

{ TAIConfig }

constructor TAIConfig.Create;
begin
  inherited Create;
  Provider := aipGemini;
  GeminiApiKey := '';
  GeminiModel := 'gemini-1.5-flash';
  LlamaEndpoint := 'http://127.0.0.1:8080/v1/chat/completions';
  LlamaModel := 'local-model';
  LlamaApiKey := '';
  Temperature := 0.2;
  MaxTokens := 2048;
  TimeoutSec := 30;
end;

procedure TAIConfig.Assign(ASource: TAIConfig);
begin
  if not Assigned(ASource) then Exit;
  Provider := ASource.Provider;
  GeminiApiKey := ASource.GeminiApiKey;
  GeminiModel := ASource.GeminiModel;
  LlamaEndpoint := ASource.LlamaEndpoint;
  LlamaModel := ASource.LlamaModel;
  LlamaApiKey := ASource.LlamaApiKey;
  Temperature := ASource.Temperature;
  MaxTokens := ASource.MaxTokens;
  TimeoutSec := ASource.TimeoutSec;
end;

procedure TAIConfig.LoadFromFile(const AFileName: string);
var
  FileStream: TFileStream;
  Parser: TJSONParser;
  JSONData: TJSONData;
  Obj: TJSONObject;
begin
  if not FileExists(AFileName) then Exit;
  FileStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    Parser := TJSONParser.Create(FileStream);
    try
      JSONData := Parser.Parse;
      try
        if JSONData is TJSONObject then
        begin
          Obj := TJSONObject(JSONData);
          Provider := TAIProviderType(Obj.Get('provider', Integer(aipGemini)));
          GeminiApiKey := Obj.Get('gemini_api_key', '');
          GeminiModel := Obj.Get('gemini_model', 'gemini-1.5-flash');
          LlamaEndpoint := Obj.Get('llama_endpoint', 'http://127.0.0.1:8080/v1/chat/completions');
          LlamaModel := Obj.Get('llama_model', 'local-model');
          LlamaApiKey := Obj.Get('llama_api_key', '');
          Temperature := Obj.Get('temperature', 0.2);
          MaxTokens := Obj.Get('max_tokens', 2048);
          TimeoutSec := Obj.Get('timeout_sec', 30);
        end;
      finally
        JSONData.Free;
      end;
    finally
      Parser.Free;
    end;
  finally
    FileStream.Free;
  end;
end;

procedure TAIConfig.SaveToFile(const AFileName: string);
var
  Obj: TJSONObject;
  SL: TStringList;
begin
  Obj := TJSONObject.Create;
  SL := TStringList.Create;
  try
    Obj.Add('provider', Integer(Provider));
    Obj.Add('gemini_api_key', GeminiApiKey);
    Obj.Add('gemini_model', GeminiModel);
    Obj.Add('llama_endpoint', LlamaEndpoint);
    Obj.Add('llama_model', LlamaModel);
    Obj.Add('llama_api_key', LlamaApiKey);
    Obj.Add('temperature', Temperature);
    Obj.Add('max_tokens', MaxTokens);
    Obj.Add('timeout_sec', TimeoutSec);

    SL.Text := Obj.FormatJSON;
    SL.SaveToFile(AFileName);
  finally
    Obj.Free;
    SL.Free;
  end;
end;

{ TAIWorkerThread }

constructor TAIWorkerThread.Create(
  AConfig: TAIConfig;
  const APrompt: string;
  const ASystemPrompt: string;
  AOnSuccess: TAISuccessEvent;
  AOnError: TAIErrorEvent
);
begin
  inherited Create(True);
  FreeOnTerminate := False; // Dikontrol aman oleh TAIService
  FConfig := TAIConfig.Create;
  FConfig.Assign(AConfig);
  FPrompt := APrompt;
  FSystemPrompt := ASystemPrompt;
  FOnSuccess := AOnSuccess;
  FOnError := AOnError;
  FResponseText := '';
  FErrorMessage := '';
  FElapsedMS := 0;
end;

destructor TAIWorkerThread.Destroy;
begin
  FConfig.Free;
  inherited Destroy;
end;

procedure TAIWorkerThread.Cancel;
begin
  FOnSuccess := nil;
  FOnError := nil;
  Terminate;
end;

procedure TAIWorkerThread.DoSuccess;
begin
  if not Terminated and Assigned(FOnSuccess) then
    FOnSuccess(Self, FResponseText, FElapsedMS);
end;

procedure TAIWorkerThread.DoError;
begin
  if not Terminated and Assigned(FOnError) then
    FOnError(Self, FErrorMessage);
end;

procedure TAIWorkerThread.SetupHttpClient(AHTTP: TFPHTTPClient);
begin
  AHTTP.AddHeader('Content-Type', 'application/json');
  AHTTP.AddHeader('User-Agent', 'SiAdmin-DB-Studio/1.0');
  AHTTP.AllowRedirect := True;
  // Timeout non-blocking (dalam milidetik)
  AHTTP.IOTimeout := FConfig.TimeoutSec * 1000;
  AHTTP.ConnectTimeout := 10000; // 10 detik batas maksimal negosiasi koneksi
end;

function TAIWorkerThread.CallGeminiAPI: string;
var
  HTTP: TFPHTTPClient;
  URL, RawResponse: string;
  PayloadObj, ContentObj, PartObj, GenConfigObj, SysObj, SysPartObj: TJSONObject;
  ContentsArr, PartsArr, SysPartsArr: TJSONArray;
  Parser: TJSONParser;
  ResData: TJSONData;
  CandidatesArr: TJSONArray;
  CandObj, CandContentObj: TJSONObject;
  ResPartsArr: TJSONArray;
  I: Integer;
  ResultText: string;
  ReqStream: TStringStream;
begin
  if Trim(FConfig.GeminiApiKey) = '' then
    raise Exception.Create('API Key Google Gemini belum dikonfigurasi di Pengaturan AI.');

  URL := Format('https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s', [
    FConfig.GeminiModel,
    FConfig.GeminiApiKey
  ]);

  PayloadObj := TJSONObject.Create;
  try
    if Trim(FSystemPrompt) <> '' then
    begin
      SysObj := TJSONObject.Create;
      SysPartsArr := TJSONArray.Create;
      SysPartObj := TJSONObject.Create;
      SysPartObj.Add('text', FSystemPrompt);
      SysPartsArr.Add(SysPartObj);
      SysObj.Add('parts', SysPartsArr);
      PayloadObj.Add('system_instruction', SysObj);
    end;

    ContentsArr := TJSONArray.Create;
    ContentObj := TJSONObject.Create;
    PartsArr := TJSONArray.Create;
    PartObj := TJSONObject.Create;
    PartObj.Add('text', FPrompt);
    PartsArr.Add(PartObj);
    ContentObj.Add('parts', PartsArr);
    ContentsArr.Add(ContentObj);
    PayloadObj.Add('contents', ContentsArr);

    GenConfigObj := TJSONObject.Create;
    GenConfigObj.Add('temperature', FConfig.Temperature);
    GenConfigObj.Add('maxOutputTokens', FConfig.MaxTokens);
    PayloadObj.Add('generationConfig', GenConfigObj);

    if Terminated then Exit('');

    HTTP := TFPHTTPClient.Create(nil);
    try
      SetupHttpClient(HTTP);
      ReqStream := TStringStream.Create(PayloadObj.AsJSON, TEncoding.UTF8);
      try
        HTTP.RequestBody := ReqStream;
        RawResponse := HTTP.Post(URL);
      finally
        ReqStream.Free;
        HTTP.RequestBody := nil;
      end;
    finally
      HTTP.Free;
    end;

    if Terminated then Exit('');

    Parser := TJSONParser.Create(RawResponse);
    try
      ResData := Parser.Parse;
      try
        if ResData is TJSONObject then
        begin
          if TJSONObject(ResData).IndexOfName('error') >= 0 then
            raise Exception.Create('Gemini API Error: ' + TJSONObject(ResData).Objects['error'].Get('message', 'Unknown error'));

          CandidatesArr := TJSONObject(ResData).Arrays['candidates'];
          if (CandidatesArr <> nil) and (CandidatesArr.Count > 0) then
          begin
            CandObj := TJSONObject(CandidatesArr[0]);
            CandContentObj := CandObj.Objects['content'];
            if CandContentObj <> nil then
            begin
              ResPartsArr := CandContentObj.Arrays['parts'];
              ResultText := '';
              for I := 0 to ResPartsArr.Count - 1 do
                ResultText := ResultText + TJSONObject(ResPartsArr[I]).Get('text', '');
              Result := ResultText;
            end;
          end;
        end;
      finally
        ResData.Free;
      end;
    finally
      Parser.Free;
    end;

  finally
    PayloadObj.Free;
  end;
end;

function TAIWorkerThread.CallLlamaCppAPI: string;
var
  HTTP: TFPHTTPClient;
  URL, RawResponse: string;
  PayloadObj, MsgObj: TJSONObject;
  MessagesArr, ChoicesArr: TJSONArray;
  Parser: TJSONParser;
  ResData: TJSONData;
  ChoiceObj, ResMsgObj: TJSONObject;
  ReqStream: TStringStream;
begin
  URL := Trim(FConfig.LlamaEndpoint);
  if URL = '' then
    raise Exception.Create('Endpoint URL llama.cpp belum diatur di Pengaturan AI.');

  PayloadObj := TJSONObject.Create;
  try
    PayloadObj.Add('model', FConfig.LlamaModel);
    PayloadObj.Add('temperature', FConfig.Temperature);
    PayloadObj.Add('max_tokens', FConfig.MaxTokens);

    MessagesArr := TJSONArray.Create;

    if Trim(FSystemPrompt) <> '' then
    begin
      MsgObj := TJSONObject.Create;
      MsgObj.Add('role', 'system');
      MsgObj.Add('content', FSystemPrompt);
      MessagesArr.Add(MsgObj);
    end;

    MsgObj := TJSONObject.Create;
    MsgObj.Add('role', 'user');
    MsgObj.Add('content', FPrompt);
    MessagesArr.Add(MsgObj);

    PayloadObj.Add('messages', MessagesArr);

    if Terminated then Exit('');

    HTTP := TFPHTTPClient.Create(nil);
    try
      SetupHttpClient(HTTP);
      if Trim(FConfig.LlamaApiKey) <> '' then
        HTTP.AddHeader('Authorization', 'Bearer ' + FConfig.LlamaApiKey);

      ReqStream := TStringStream.Create(PayloadObj.AsJSON, TEncoding.UTF8);
      try
        HTTP.RequestBody := ReqStream;
        RawResponse := HTTP.Post(URL);
      finally
        ReqStream.Free;
        HTTP.RequestBody := nil;
      end;
    finally
      HTTP.Free;
    end;

    if Terminated then Exit('');

    Parser := TJSONParser.Create(RawResponse);
    try
      ResData := Parser.Parse;
      try
        if ResData is TJSONObject then
        begin
          if TJSONObject(ResData).IndexOfName('error') >= 0 then
            raise Exception.Create('llama.cpp Error: ' + TJSONObject(ResData).Get('error', ''));

          ChoicesArr := TJSONObject(ResData).Arrays['choices'];
          if (ChoicesArr <> nil) and (ChoicesArr.Count > 0) then
          begin
            ChoiceObj := TJSONObject(ChoicesArr[0]);
            ResMsgObj := ChoiceObj.Objects['message'];
            if ResMsgObj <> nil then
              Result := ResMsgObj.Get('content', '')
            else
              Result := ChoiceObj.Get('text', '');
          end;
        end;
      finally
        ResData.Free;
      end;
    finally
      Parser.Free;
    end;

  finally
    PayloadObj.Free;
  end;
end;

procedure TAIWorkerThread.Execute;
var
  StartTime: QWord;
begin
  StartTime := GetTickCount64;
  try
    if Terminated then Exit;

    case FConfig.Provider of
      aipGemini:   FResponseText := CallGeminiAPI;
      aipLlamaCpp: FResponseText := CallLlamaCppAPI;
    end;

    FElapsedMS := GetTickCount64 - StartTime;

    if not Terminated then
      Synchronize(@DoSuccess);
  except
    on E: Exception do
    begin
      FErrorMessage := E.Message;
      if not Terminated then
        Synchronize(@DoError);
    end;
  end;
end;

{ TAIService }

constructor TAIService.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FConfig := TAIConfig.Create;
  FActiveWorkers := TList.Create;
  FConfigFile := ExtractFilePath(ParamStr(0)) + 'ai_settings.json';
  FConfig.LoadFromFile(FConfigFile);
end;

destructor TAIService.Destroy;
begin
  CancelAllRequests;
  FConfig.SaveToFile(FConfigFile);
  FreeAndNil(FConfig);
  FreeAndNil(FActiveWorkers);
  FreeAndNil(FLock);
  inherited Destroy;
end;

procedure TAIService.HandleWorkerTerminated(Sender: TObject);
var
  Worker: TAIWorkerThread;
begin
  if not Assigned(FActiveWorkers) or not Assigned(FLock) then Exit;

  FLock.Enter;
  try
    if Sender is TAIWorkerThread then
    begin
      Worker := TAIWorkerThread(Sender);
      FActiveWorkers.Remove(Worker);
      Worker.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

function TAIService.ExecutePromptAsync(
  const APrompt: string;
  const ASystemPrompt: string;
  AOnSuccess: TAISuccessEvent;
  AOnError: TAIErrorEvent
): TAIWorkerThread;
var
  Worker: TAIWorkerThread;
begin
  Worker := TAIWorkerThread.Create(FConfig, APrompt, ASystemPrompt, AOnSuccess, AOnError);
  Worker.OnTerminate := @HandleWorkerTerminated;

  FLock.Enter;
  try
    FActiveWorkers.Add(Worker);
  finally
    FLock.Leave;
  end;

  Worker.Start;
  Result := Worker;
end;

procedure TAIService.CancelWorker(AWorker: TAIWorkerThread);
begin
  if not Assigned(AWorker) then Exit;
  AWorker.Cancel;
end;

procedure TAIService.CancelAllRequests;
var
  I: Integer;
  Worker: TAIWorkerThread;
  TempList: TList;
begin
  if not Assigned(FActiveWorkers) then Exit;

  TempList := TList.Create;
  try
    FLock.Enter;
    try
      for I := 0 to FActiveWorkers.Count - 1 do
        TempList.Add(FActiveWorkers[I]);
      FActiveWorkers.Clear;
    finally
      FLock.Leave;
    end;

    for I := 0 to TempList.Count - 1 do
    begin
      Worker := TAIWorkerThread(TempList[I]);
      if Assigned(Worker) then
      begin
        Worker.OnTerminate := nil;
        Worker.Cancel;
        Worker.WaitFor;
        Worker.Free;
      end;
    end;
  finally
    TempList.Free;
  end;
end;

initialization
  GAIService := nil;

finalization
  if Assigned(GAIService) then
    FreeAndNil(GAIService);

end.
