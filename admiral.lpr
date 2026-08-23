program admiral;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, Controls, tachartlazaruspkg, uFormMain, zcomponent,
  uDBUserManagerService, uFormUserManager, uDBServerVariablesService,
  uFormServerVariables, uERDModel, uERDService, uFormERDViewer,
  uModelVisualQuery, uFormQueryBuilder, uFormRecordView, uImportWorkerThread,
  uFormImportData, uModelTableBuilder, uFormTableBuilder, uSchemaDiffEngine,
  uFormSchemaDiff, uFormAISettings, uAIDiagnosticsEngine, uFormAIDiagnostic,
  uFormAIOptimizer, uAIExplainerEngine, uFormAIExplainer, uDataTransferEngine,
  uFormDataTransfer, uFrameVisualChart, uSQLLoggerService, uFormBackupRestore,
  uSafeModeGuardrails, uServerMetricsCollector, uModelRESTConfig,
  uRESTGeneratorNodeJS, uFormRESTGeneratorWizard, uRESTGeneratorFastAPI,
  uRESTGeneratorGoFiber, uRESTGeneratorPHP, uFormSplash, uFormAbout,
  uFormExtensionManager, uSSHTunnelService, uThemeManager, uAppSettings,
  uFormAppSettings, uERDForwardEngine, uFrameDBTerminal;


{$R *.res}

begin

    RequireDerivedFormResource:=True;
    Application.Scaled:=True;
    {$PUSH}{$WARN 5044 OFF}
    Application.MainFormOnTaskbar:=True;
    {$POP}
    Application.Initialize;

   if TFormSplash.ExecuteSplash = mrOk then
    begin
      Application.CreateForm(TFormMain, FormMain);
      Application.Run();
    end;

end.

