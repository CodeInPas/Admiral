unit uAppSettings;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, IniFiles, Forms, Graphics,
  uThemeManager;

type
  { TGridDensity }
  TGridDensity = (gdCompact, gdNormal, gdRelaxed);

  { TAIProviderType }
  TAIProviderType = (aiGemini, aiOpenAI, aiDeepSeek, aiOllama);

  { TAppSettings }
  TAppSettings = class
  private
    FConfigFile: string;

    // 1. Umum & Startup
    FRestoreSession: Boolean;
    FAutoConnectLastProfile: Boolean;
    FHistoryRetentionDays: Integer;
    FConfirmOnExit: Boolean;

    // 2. Tampilan & Editor SQL
    FAppTheme: TAppTheme;
    FEditorFontName: string;
    FEditorFontSize: Integer;
    FEditorShowLineNumbers: Boolean;
    FEditorHighlightActiveLine: Boolean;
    FEditorTabWidth: Integer;
    FEditorWordWrap: Boolean;
    FIntelliSenseAutoTrigger: Boolean;
    FIntelliSenseCaseSensitive: Boolean;

    // 3. Tampilan & Format Data Grid
    FGridZebraStriping: Boolean;
    FGridShowNullLabel: Boolean;
    FGridDensity: TGridDensity;
    FGridAutoFitColumns: Boolean;
    FGridDateTimeFormat: string;
    FGridDateFormat: string;
    FGridCopyIncludeHeaders: Boolean;

    // 4. Eksekusi Database & Guardrails
    FDefaultSelectLimit: Integer;
    FQueryTimeoutSeconds: Integer;
    FSafeModeEnabled: Boolean;
    FRequireWhereConfirmation: Boolean;

    // 5. Integrasi AI
    FAIProvider: TAIProviderType;
    FAIApiKey: string;
    FAIModelName: string;
    FAITemperature: Double;
    FAIMaxTokens: Integer;
    FAILanguage: string;

    // 6. Jaringan & SSH
    FSSHExecutablePath: string;
    FSSHTimeoutSeconds: Integer;

    // 7. Ekspor & Data Tools
    FExportDefaultDelimiter: string;
    FMockDataBatchSize: Integer;

    procedure SetDefaults;
  public
    constructor Create;
    destructor Destroy; override;

    procedure LoadSettings;
    procedure SaveSettings;

    // Properties
    property RestoreSession: Boolean read FRestoreSession write FRestoreSession;
    property AutoConnectLastProfile: Boolean read FAutoConnectLastProfile write FAutoConnectLastProfile;
    property HistoryRetentionDays: Integer read FHistoryRetentionDays write FHistoryRetentionDays;
    property ConfirmOnExit: Boolean read FConfirmOnExit write FConfirmOnExit;

    property AppTheme: TAppTheme read FAppTheme write FAppTheme;
    property EditorFontName: string read FEditorFontName write FEditorFontName;
    property EditorFontSize: Integer read FEditorFontSize write FEditorFontSize;
    property EditorShowLineNumbers: Boolean read FEditorShowLineNumbers write FEditorShowLineNumbers;
    property EditorHighlightActiveLine: Boolean read FEditorHighlightActiveLine write FEditorHighlightActiveLine;
    property EditorTabWidth: Integer read FEditorTabWidth write FEditorTabWidth;
    property EditorWordWrap: Boolean read FEditorWordWrap write FEditorWordWrap;
    property IntelliSenseAutoTrigger: Boolean read FIntelliSenseAutoTrigger write FIntelliSenseAutoTrigger;
    property IntelliSenseCaseSensitive: Boolean read FIntelliSenseCaseSensitive write FIntelliSenseCaseSensitive;

    property GridZebraStriping: Boolean read FGridZebraStriping write FGridZebraStriping;
    property GridShowNullLabel: Boolean read FGridShowNullLabel write FGridShowNullLabel;
    property GridDensity: TGridDensity read FGridDensity write FGridDensity;
    property GridAutoFitColumns: Boolean read FGridAutoFitColumns write FGridAutoFitColumns;
    property GridDateTimeFormat: string read FGridDateTimeFormat write FGridDateTimeFormat;
    property GridDateFormat: string read FGridDateFormat write FGridDateFormat;
    property GridCopyIncludeHeaders: Boolean read FGridCopyIncludeHeaders write FGridCopyIncludeHeaders;

    property DefaultSelectLimit: Integer read FDefaultSelectLimit write FDefaultSelectLimit;
    property QueryTimeoutSeconds: Integer read FQueryTimeoutSeconds write FQueryTimeoutSeconds;
    property SafeModeEnabled: Boolean read FSafeModeEnabled write FSafeModeEnabled;
    property RequireWhereConfirmation: Boolean read FRequireWhereConfirmation write FRequireWhereConfirmation;

    property AIProvider: TAIProviderType read FAIProvider write FAIProvider;
    property AIApiKey: string read FAIApiKey write FAIApiKey;
    property AIModelName: string read FAIModelName write FAIModelName;
    property AITemperature: Double read FAITemperature write FAITemperature;
    property AIMaxTokens: Integer read FAIMaxTokens write FAIMaxTokens;
    property AILanguage: string read FAILanguage write FAILanguage;

    property SSHExecutablePath: string read FSSHExecutablePath write FSSHExecutablePath;
    property SSHTimeoutSeconds: Integer read FSSHTimeoutSeconds write FSSHTimeoutSeconds;

    property ExportDefaultDelimiter: string read FExportDefaultDelimiter write FExportDefaultDelimiter;
    property MockDataBatchSize: Integer read FMockDataBatchSize write FMockDataBatchSize;
  end;

var
  Settings: TAppSettings;

implementation

{ TAppSettings }

constructor TAppSettings.Create;
var
  AppDir: string;
begin
  inherited Create;
  AppDir := ExtractFilePath(Application.ExeName);
  FConfigFile := IncludeTrailingPathDelimiter(AppDir) + 'admiral_settings.ini';
  SetDefaults;
  LoadSettings;
end;

destructor TAppSettings.Destroy;
begin
  inherited Destroy;
end;

procedure TAppSettings.SetDefaults;
begin
  FRestoreSession := True;
  FAutoConnectLastProfile := False;
  FHistoryRetentionDays := 30;
  FConfirmOnExit := True;

  FAppTheme := thLight;
  FEditorFontName := 'Consolas';
  FEditorFontSize := 11;
  FEditorShowLineNumbers := True;
  FEditorHighlightActiveLine := True;
  FEditorTabWidth := 2;
  FEditorWordWrap := False;
  FIntelliSenseAutoTrigger := True;
  FIntelliSenseCaseSensitive := False;

  FGridZebraStriping := True;
  FGridShowNullLabel := True;
  FGridDensity := gdNormal;
  FGridAutoFitColumns := True;
  FGridDateTimeFormat := 'YYYY-MM-DD hh:nn:ss';
  FGridDateFormat := 'YYYY-MM-DD';
  FGridCopyIncludeHeaders := True;

  FDefaultSelectLimit := 1000;
  FQueryTimeoutSeconds := 60;
  FSafeModeEnabled := True;
  FRequireWhereConfirmation := True;

  FAIProvider := aiGemini;
  FAIApiKey := '';
  FAIModelName := 'gemini-1.5-flash';
  FAITemperature := 0.2;
  FAIMaxTokens := 2048;
  FAILanguage := 'Indonesian';

  FSSHExecutablePath := 'ssh';
  FSSHTimeoutSeconds := 10;

  FExportDefaultDelimiter := ',';
  FMockDataBatchSize := 100;
end;

procedure TAppSettings.LoadSettings;
var
  Ini: TIniFile;
begin
  if not FileExists(FConfigFile) then Exit;

  Ini := TIniFile.Create(FConfigFile);
  try
    // Umum
    FRestoreSession := Ini.ReadBool('General', 'RestoreSession', FRestoreSession);
    FAutoConnectLastProfile := Ini.ReadBool('General', 'AutoConnectLastProfile', FAutoConnectLastProfile);
    FHistoryRetentionDays := Ini.ReadInteger('General', 'HistoryRetentionDays', FHistoryRetentionDays);
    FConfirmOnExit := Ini.ReadBool('General', 'ConfirmOnExit', FConfirmOnExit);

    // Editor
    FAppTheme := TAppTheme(Ini.ReadInteger('Appearance', 'Theme', Integer(FAppTheme)));
    FEditorFontName := Ini.ReadString('Editor', 'FontName', FEditorFontName);
    FEditorFontSize := Ini.ReadInteger('Editor', 'FontSize', FEditorFontSize);
    FEditorShowLineNumbers := Ini.ReadBool('Editor', 'ShowLineNumbers', FEditorShowLineNumbers);
    FEditorHighlightActiveLine := Ini.ReadBool('Editor', 'HighlightActiveLine', FEditorHighlightActiveLine);
    FEditorTabWidth := Ini.ReadInteger('Editor', 'TabWidth', FEditorTabWidth);
    FEditorWordWrap := Ini.ReadBool('Editor', 'WordWrap', FEditorWordWrap);
    FIntelliSenseAutoTrigger := Ini.ReadBool('Editor', 'IntelliSenseAutoTrigger', FIntelliSenseAutoTrigger);
    FIntelliSenseCaseSensitive := Ini.ReadBool('Editor', 'IntelliSenseCaseSensitive', FIntelliSenseCaseSensitive);

    // Grid
    FGridZebraStriping := Ini.ReadBool('DataGrid', 'ZebraStriping', FGridZebraStriping);
    FGridShowNullLabel := Ini.ReadBool('DataGrid', 'ShowNullLabel', FGridShowNullLabel);
    FGridDensity := TGridDensity(Ini.ReadInteger('DataGrid', 'Density', Integer(FGridDensity)));
    FGridAutoFitColumns := Ini.ReadBool('DataGrid', 'AutoFitColumns', FGridAutoFitColumns);
    FGridDateTimeFormat := Ini.ReadString('DataGrid', 'DateTimeFormat', FGridDateTimeFormat);
    FGridDateFormat := Ini.ReadString('DataGrid', 'DateFormat', FGridDateFormat);
    FGridCopyIncludeHeaders := Ini.ReadBool('DataGrid', 'CopyIncludeHeaders', FGridCopyIncludeHeaders);

    // Database & Safety
    FDefaultSelectLimit := Ini.ReadInteger('Database', 'DefaultSelectLimit', FDefaultSelectLimit);
    FQueryTimeoutSeconds := Ini.ReadInteger('Database', 'QueryTimeoutSeconds', FQueryTimeoutSeconds);
    FSafeModeEnabled := Ini.ReadBool('Database', 'SafeModeEnabled', FSafeModeEnabled);
    FRequireWhereConfirmation := Ini.ReadBool('Database', 'RequireWhereConfirmation', FRequireWhereConfirmation);

    // AI
    FAIProvider := TAIProviderType(Ini.ReadInteger('AI', 'Provider', Integer(FAIProvider)));
    FAIApiKey := Ini.ReadString('AI', 'ApiKey', FAIApiKey);
    FAIModelName := Ini.ReadString('AI', 'ModelName', FAIModelName);
    FAITemperature := Ini.ReadFloat('AI', 'Temperature', FAITemperature);
    FAIMaxTokens := Ini.ReadInteger('AI', 'MaxTokens', FAIMaxTokens);
    FAILanguage := Ini.ReadString('AI', 'Language', FAILanguage);

    // SSH & Tools
    FSSHExecutablePath := Ini.ReadString('Network', 'SSHExecutablePath', FSSHExecutablePath);
    FSSHTimeoutSeconds := Ini.ReadInteger('Network', 'SSHTimeoutSeconds', FSSHTimeoutSeconds);
    FExportDefaultDelimiter := Ini.ReadString('DataTools', 'ExportDefaultDelimiter', FExportDefaultDelimiter);
    FMockDataBatchSize := Ini.ReadInteger('DataTools', 'MockDataBatchSize', FMockDataBatchSize);
  finally
    Ini.Free;
  end;
end;

procedure TAppSettings.SaveSettings;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(FConfigFile);
  try
    // Umum
    Ini.WriteBool('General', 'RestoreSession', FRestoreSession);
    Ini.WriteBool('General', 'AutoConnectLastProfile', FAutoConnectLastProfile);
    Ini.WriteInteger('General', 'HistoryRetentionDays', FHistoryRetentionDays);
    Ini.WriteBool('General', 'ConfirmOnExit', FConfirmOnExit);

    // Editor
    Ini.WriteInteger('Appearance', 'Theme', Integer(FAppTheme));
    Ini.WriteString('Editor', 'FontName', FEditorFontName);
    Ini.WriteInteger('Editor', 'FontSize', FEditorFontSize);
    Ini.WriteBool('Editor', 'ShowLineNumbers', FEditorShowLineNumbers);
    Ini.WriteBool('Editor', 'HighlightActiveLine', FEditorHighlightActiveLine);
    Ini.WriteInteger('Editor', 'TabWidth', FEditorTabWidth);
    Ini.WriteBool('Editor', 'WordWrap', FEditorWordWrap);
    Ini.WriteBool('Editor', 'IntelliSenseAutoTrigger', FIntelliSenseAutoTrigger);
    Ini.WriteBool('Editor', 'IntelliSenseCaseSensitive', FIntelliSenseCaseSensitive);

    // Grid
    Ini.WriteBool('DataGrid', 'ZebraStriping', FGridZebraStriping);
    Ini.WriteBool('DataGrid', 'ShowNullLabel', FGridShowNullLabel);
    Ini.WriteInteger('DataGrid', 'Density', Integer(FGridDensity));
    Ini.WriteBool('DataGrid', 'AutoFitColumns', FGridAutoFitColumns);
    Ini.WriteString('DataGrid', 'DateTimeFormat', FGridDateTimeFormat);
    Ini.WriteString('DataGrid', 'DateFormat', FGridDateFormat);
    Ini.WriteBool('DataGrid', 'CopyIncludeHeaders', FGridCopyIncludeHeaders);

    // Database & Safety
    Ini.WriteInteger('Database', 'DefaultSelectLimit', FDefaultSelectLimit);
    Ini.WriteInteger('Database', 'QueryTimeoutSeconds', FQueryTimeoutSeconds);
    Ini.WriteBool('Database', 'SafeModeEnabled', FSafeModeEnabled);
    Ini.WriteBool('Database', 'RequireWhereConfirmation', FRequireWhereConfirmation);

    // AI
    Ini.WriteInteger('AI', 'Provider', Integer(FAIProvider));
    Ini.WriteString('AI', 'ApiKey', FAIApiKey);
    Ini.WriteString('AI', 'ModelName', FAIModelName);
    Ini.WriteFloat('AI', 'Temperature', FAITemperature);
    Ini.WriteInteger('AI', 'MaxTokens', FAIMaxTokens);
    Ini.WriteString('AI', 'Language', FAILanguage);

    // SSH & Tools
    Ini.WriteString('Network', 'SSHExecutablePath', FSSHExecutablePath);
    Ini.WriteInteger('Network', 'SSHTimeoutSeconds', FSSHTimeoutSeconds);
    Ini.WriteString('DataTools', 'ExportDefaultDelimiter', FExportDefaultDelimiter);
    Ini.WriteInteger('DataTools', 'MockDataBatchSize', FMockDataBatchSize);
  finally
    Ini.Free;
  end;
end;

initialization
  Settings := TAppSettings.Create;

finalization
  FreeAndNil(Settings);

end.
