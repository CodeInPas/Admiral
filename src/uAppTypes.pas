unit uAppTypes;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

type
  // Tipe DBMS Engine yang didukung
  TDBDriverType = (
    dtSQLite,
    dtMySQL,
    dtMariaDB,
    dtFirebird,
    dtPostgreSQL
  );

  // Klasifikasi Environment Profil Koneksi
  TEnvironmentTag = (
    envDevelopment,
    envTesting,
    envStaging,
    envProduction
  );

  // Mode Koneksi SSL/TLS
  TSSLMode = (
    sslDisable,
    sslRequire,
    sslVerifyCA,
    sslVerifyFull
  );

  // Metode Autentikasi SSH Tunnel
  TSSHAuthType = (
    sshPassword,
    sshKeyFile
  );

  // Tipe Data Value pada Penyimpanan Konfigurasi
  TSettingDataType = (
    sdtString,
    sdtInteger,
    sdtBoolean,
    sdtJSON
  );

  // Tipe Objek Metadata Struktur Database (Object Browser Tree)
  TSchemaObjectType = (
    sotServer,
    sotDatabase,
    sotSchema,
    sotTableGroup,
    sotViewGroup,
    sotProcGroup,
    sotFunctionGroup,
    sotTriggerGroup,
    sotSequenceGroup,
    sotTable,
    sotView,
    sotColumn,
    sotIndex,
    sotPrimaryKey,
    sotForeignKey,
    sotProcedure,
    sotFunction,
    sotTrigger,
    sotSequence
  );

  // Format Ekspor Data
  TExportFormat = (
    efCSV,
    efSQL,
    efJSON,
    efExcel
  );

  // Status Siklus Eksekusi Query
  TQueryExecutionState = (
    qesIdle,
    qesExecuting,
    qesFetching,
    qesSuccess,
    qesError,
    qesCancelled
  );

  // Event & Callback Signatures
  TLogProcedure = procedure(const AMessage: string) of object;
  TProgressProcedure = procedure(const ACurrent, AMax: Int64; const AMessage: string) of object;

implementation

end.

