unit uFormCrosstabBuilder;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Buttons,
  uAppTypes, uDBTypes, uModelConnection, uDBDriverBase, uDBConnectionFactory,
  uModelSchemaObject, uCrosstabQueryEngine;

type
  { TFormCrosstabBuilder }
  TFormCrosstabBuilder = class(TForm)
    pnlTop: TPanel;
    lblTitle: TLabel;
    lblSubtitle: TLabel;

    pnlBody: TPanel;
    lblTable: TLabel;
    cboTable: TComboBox;

    lblRowHeading: TLabel;
    cboRowHeading: TComboBox;

    lblColHeading: TLabel;
    cboColHeading: TComboBox;

    lblValueField: TLabel;
    cboValueField: TComboBox;

    lblAggFunc: TLabel;
    cboAggFunc: TComboBox;

    chkRowTotal: TCheckBox;

    pnlBottom: TPanel;
    btnGenerate: TBitBtn;
    btnCancel: TBitBtn;

    procedure FormShow(Sender: TObject);
    procedure cboTableChange(Sender: TObject);
    procedure btnGenerateClick(Sender: TObject);
  private
    FProfile: TConnectionProfile;
    FDatabaseName: string;
    FGeneratedSQL: string;

    procedure LoadTables;
    procedure LoadColumns(const ATableName: string);
  public
    class function Execute(
      AOwner: TComponent;
      AProfile: TConnectionProfile;
      const ADBName: string;
      out AResultSQL: string
    ): Boolean;
  end;

implementation

{$R *.lfm}

{ TFormCrosstabBuilder }

class function TFormCrosstabBuilder.Execute(
  AOwner: TComponent;
  AProfile: TConnectionProfile;
  const ADBName: string;
  out AResultSQL: string
): Boolean;
var
  Frm: TFormCrosstabBuilder;
begin
  Result := False;
  AResultSQL := '';

  Frm := TFormCrosstabBuilder.Create(AOwner);
  try
    Frm.FProfile := AProfile;
    Frm.FDatabaseName := ADBName;

    if Frm.ShowModal = mrOk then
    begin
      AResultSQL := Frm.FGeneratedSQL;
      Result := (Trim(AResultSQL) <> '');
    end;
  finally
    Frm.Free;
  end;
end;

procedure TFormCrosstabBuilder.FormShow(Sender: TObject);
begin
  cboAggFunc.Items.CommaText := 'SUM,COUNT,AVG,MIN,MAX';
  cboAggFunc.ItemIndex := 0;
  LoadTables;
end;

procedure TFormCrosstabBuilder.LoadTables;
var
  Driver: TDBDriverBase;
  Tables: TSchemaObjectList;
  I: Integer;
begin
  cboTable.Items.Clear;
  if not Assigned(FProfile) then Exit;

  Driver := nil;
  Tables := TSchemaObjectList.Create(True);
  try
    Driver := TDBConnectionFactory.CreateDriver(FProfile);
    Driver.ExtractTables(FDatabaseName, '', Tables);

    for I := 0 to Tables.Count - 1 do
      cboTable.Items.Add(Tables[I].Name);

    if cboTable.Items.Count > 0 then
    begin
      cboTable.ItemIndex := 0;
      cboTableChange(Self);
    end;
  finally
    Tables.Free;
    if Assigned(Driver) then Driver.Free;
  end;
end;

procedure TFormCrosstabBuilder.LoadColumns(const ATableName: string);
var
  Driver: TDBDriverBase;
  Cols: TSchemaColumnList;
  I: Integer;
begin
  cboRowHeading.Items.Clear;
  cboColHeading.Items.Clear;
  cboValueField.Items.Clear;

  if (ATableName = '') or not Assigned(FProfile) then Exit;

  Driver := nil;
  Cols := TSchemaColumnList.Create(True);
  try
    Driver := TDBConnectionFactory.CreateDriver(FProfile);
    Driver.ExtractColumns(FDatabaseName, '', ATableName, Cols);

    for I := 0 to Cols.Count - 1 do
    begin
      cboRowHeading.Items.Add(Cols[I].Name);
      cboColHeading.Items.Add(Cols[I].Name);
      cboValueField.Items.Add(Cols[I].Name);
    end;

    if cboRowHeading.Items.Count > 0 then cboRowHeading.ItemIndex := 0;
    if cboColHeading.Items.Count > 1 then cboColHeading.ItemIndex := 1 else cboColHeading.ItemIndex := 0;
    if cboValueField.Items.Count > 2 then cboValueField.ItemIndex := 2 else cboValueField.ItemIndex := 0;
  finally
    Cols.Free;
    if Assigned(Driver) then Driver.Free;
  end;
end;

procedure TFormCrosstabBuilder.cboTableChange(Sender: TObject);
begin
  LoadColumns(cboTable.Text);
end;

procedure TFormCrosstabBuilder.btnGenerateClick(Sender: TObject);
var
  SQLOut: string;
begin
  if (cboTable.Text = '') or (cboRowHeading.Text = '') or (cboColHeading.Text = '') or (cboValueField.Text = '') then
  begin
    MessageDlg('Peringatan', 'Lengkapi seluruh pilihan kolom sebelum membuat Crosstab Query.', mtWarning, [mbOK], 0);
    Exit;
  end;

  if cboRowHeading.Text = cboColHeading.Text then
  begin
    MessageDlg('Peringatan', 'Kolom Baris (Row Heading) dan Kolom Kolom (Column Heading) tidak boleh sama.', mtWarning, [mbOK], 0);
    Exit;
  end;

  Screen.Cursor := crHourGlass;
  try
    if TCrosstabQueryEngine.GenerateCrosstabSQL(
      FProfile,
      FDatabaseName,
      cboTable.Text,
      cboRowHeading.Text,
      cboColHeading.Text,
      cboValueField.Text,
      cboAggFunc.Text,
      chkRowTotal.Checked,
      SQLOut
    ) then
    begin
      FGeneratedSQL := SQLOut;
      ModalResult := mrOk;
    end
    else
      MessageDlg('Gagal', 'Tidak ada data kategori yang ditemukan pada kolom pivot terpilih.', mtError, [mbOK], 0);
  finally
    Screen.Cursor := crDefault;
  end;
end;

end.
