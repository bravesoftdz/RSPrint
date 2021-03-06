unit RSPrint.FastMode;

interface

uses
  Classes, RSPrint.Types.CommonTypes, RSPrint.Types.Document, RSPrint.Types.Page, RSPrint.FastMode.FastDevice;

type
  TFastMode = class
  private const
    SINGLE_LINE = #196;
    DOUBLE_LINE = #205;

  private
    FDocument: TDocument;
    FFastDevice: IFastDevice;

    procedure PageContinuosJump;

    procedure PrintControlCodes(codeSequence: string);
    procedure PrintHorizontalLines(currentLine: Integer; page: TPage; var lineToPrint: string);
    procedure PrintVerticalLines(page: TPage; var lineToPrint: string; currentLine: Integer);
    procedure PrintCurrentLine(page: TPage; var ultimaEscritura: Integer; font: TFastFont; var lineToPrint: string; const currentLine: Integer);

    procedure PrintJob(pageNumber: Byte);
    function PrintPage(pageNumber: integer): Boolean;

    procedure PrintFontCodes(font: TFastFont);

  public const
    ALL_PAGES = 0;

  public
    constructor Create;

    procedure Print(document: TDocument; pageNumber: Byte);
  end;

implementation

uses
  SysUtils, Windows, Printers, RSPrint.Utils, RSPrint.FastMode.FastDeviceFile, RSPrint.FastMode.FastDeviceSpool,
  Dialogs;

constructor TFastMode.Create;
begin
  FFastDevice := TFastDeviceSpool.Create;
  //FFastDevice := TFastDeviceFile.Create;
end;

procedure TFastMode.Print(document: TDocument; pageNumber: Byte);
begin
  FDocument := document;
  PrintJob(pageNumber);
end;

procedure TFastMode.PrintJob(pageNumber: Byte);
var
  PagePrintedRight: Boolean;
  Copias: Integer;
  I: Integer;
begin
  PagePrintedRight := True;
  for Copias := 1 to FDocument.Copies do
  begin
    FFastDevice.BeginDoc(FDocument.Title);

    if pageNumber = ALL_PAGES then
    begin
      for I := 1 to FDocument.Pages.Count do
        if PagePrintedRight then
          PagePrintedRight := PrintPage(I);
    end
    else
      PrintPage(pageNumber);

    FFastDevice.EndDoc;
  end;
end;

function TFastMode.PrintPage(pageNumber: integer): boolean;
var
  CurrentLine: Integer;
  LineToPrint: string;
  Page: TPage;
  Font: TFastFont;
  UltimaEscritura: Integer;
begin
  try
    Result := True;
    FFastDevice.BeginPage;

    PrintControlCodes(FDocument.ControlCodes.Reset);
    PrintControlCodes(FDocument.ControlCodes.Setup);

    PrintControlCodes(FDocument.ControlCodes.SelLength);
    FFastDevice.Write(#84);

    Font := FDocument.DefaultFont;
    PrintFontCodes(Font);

    UltimaEscritura := 0;
    Page := FDocument.Pages.Items[pageNumber-1];
    CurrentLine := 1;
    while (CurrentLine < TUtils.Min(Page.PrintedLines, FDocument.LinesPerPage)) do
    begin
      LineToPrint := '';

      PrintHorizontalLines(CurrentLine, Page, LineToPrint);
      PrintVerticalLines(Page, LineToPrint, CurrentLine);

      PrintCurrentLine(Page, UltimaEscritura, Font, LineToPrint, CurrentLine);
      Inc(CurrentLine);
    end;

    if (FDocument.PageSize = pzContinuous) and (FDocument.PageLength = 0) then
      PageContinuosJump
    else
      FFastDevice.Write(#12);

    FFastDevice.EndPage;
  except
    on e: exception do
    begin
      ShowMessage(e.Message);
      Result := False;
    end;
  end;
end;

procedure TFastMode.PrintFontCodes(font: TFastFont);
begin
  PrintControlCodes(FDocument.ControlCodes.Normal);

  if Bold in Font then
    PrintControlCodes(FDocument.ControlCodes.Bold);

  if Italic in Font then
    PrintControlCodes(FDocument.ControlCodes.Italic);

  if DobleWide in Font then
    PrintControlCodes(FDocument.ControlCodes.Wide)
  else if Compress in Font then
    PrintControlCodes(FDocument.ControlCodes.CondensedON)
  else
    PrintControlCodes(FDocument.ControlCodes.CondensedOFF);

  if Underline in Font then
    PrintControlCodes(FDocument.ControlCodes.UnderlineON)
  else
    PrintControlCodes(FDocument.ControlCodes.UnderlineOFF);
end;

procedure TFastMode.PrintVerticalLines(page: TPage; var lineToPrint: string; currentLine: Integer);
var
  VerticalLine: TVerticalLine;
  Contador: Integer;
begin
  // AHORA SE ANALIZAN LAS LINEAS VERTICALES
  for Contador := 0 to page.VerticalLines.Count - 1 do
  begin
    VerticalLine := page.VerticalLines.Items[Contador];
    if (VerticalLine.Line1 <= currentLine) and (VerticalLine.Line2 >= currentLine) then
    begin
      // LA LINEA PASA POR ESTA LINEA
      TUtils.InflateLineWithSpaces(lineToPrint, VerticalLine.Col);
      if VerticalLine.Line1 = currentLine then
      begin
        // ES LA PRIMER LINEA
        if lineToPrint[VerticalLine.Col] = SINGLE_LINE then
        // LINEA HORIZONTAL SIMPLE
        begin
          if (VerticalLine.Col > 0) and (ord(lineToPrint[VerticalLine.Col - 1]) in [192, 193, 194, 195, 196, 197, 199, 208, 210, 211, 214, 215, 218]) then
          begin
            // VIENE DE LA IZQUIERDA
            if (VerticalLine.Col < Length(lineToPrint)) and (ord(lineToPrint[VerticalLine.Col + 1]) in [180, 182, 183, 189, 191, 193, 194, 196, 197, 208, 210, 215, 217]) then
            begin
              // SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
                lineToPrint[VerticalLine.Col] := '�'
              else
                lineToPrint[VerticalLine.Col] := '�';
            end
            else
            begin
              // NO SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
                lineToPrint[VerticalLine.Col] := '�'
              else
                lineToPrint[VerticalLine.Col] := '�';
            end;
          end
          else
          begin
            // NO VA PARA LA IZQUIERDA
            if (VerticalLine.Col < Length(lineToPrint)) and (ord(lineToPrint[VerticalLine.Col + 1]) in [180, 182, 183, 189, 191, 193, 194, 196, 197, 208, 210, 215, 217]) then
            begin
              // SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
                lineToPrint[VerticalLine.Col] := '�'
              else
                lineToPrint[VerticalLine.Col] := '�';
            end
            else
            begin
              // NO SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
                lineToPrint[VerticalLine.Col] := '�'
              else
                lineToPrint[VerticalLine.Col] := '�';
            end;
          end;
        end
        else if lineToPrint[VerticalLine.Col] = '�' then
        // LINEA HORIZONTAL DOBLE
        begin
          if (VerticalLine.Col > 0) and (ord(lineToPrint[VerticalLine.Col - 1]) in [198, 200, 201, 202, 203, 204, 205, 206, 207, 209, 212, 213]) then
          begin
            // VIENE DE LA IZQUIERDA
            if (VerticalLine.Col < Length(lineToPrint)) and (ord(lineToPrint[VerticalLine.Col + 1]) in [181, 184, 185, 187, 188, 190, 202, 203, 205, 206, 207, 209, 216]) then
            begin
              // SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
                lineToPrint[VerticalLine.Col] := '�'
              else
                lineToPrint[VerticalLine.Col] := '�';
            end
            else
            begin
              // NO SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
                lineToPrint[VerticalLine.Col] := '�'
              else
                lineToPrint[VerticalLine.Col] := '�';
            end;
          end
          else
          begin
            // NO VA PARA LA IZQUIERDA
            if (VerticalLine.Col < Length(lineToPrint)) and (ord(lineToPrint[VerticalLine.Col + 1]) in [181, 184, 185, 187, 188, 190, 202, 203, 205, 206, 207, 209, 216]) then
            begin
              // SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
                lineToPrint[VerticalLine.Col] := '�'
              else
                lineToPrint[VerticalLine.Col] := '�';
            end
            else
            begin
              // NO SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
                lineToPrint[VerticalLine.Col] := '�'
              else
                lineToPrint[VerticalLine.Col] := '�';
            end;
          end;
        end
        else
        // HAY OTRO CODIGO
        begin
          if VerticalLine.Kind = ltSingle then
            lineToPrint[VerticalLine.Col] := '�'
          else
            // Doble
            lineToPrint[VerticalLine.Col] := '�';
        end;
      end
      else if VerticalLine.Line2 = currentLine then
      begin
        // ES LA ULTIMA LINEA
        if lineToPrint[VerticalLine.Col] = SINGLE_LINE then
        // LINEA HORIZONTAL SIMPLE
        begin
          if (VerticalLine.Col > 0) and (ord(lineToPrint[VerticalLine.Col - 1]) in [192, 193, 194, 195, 196, 197, 199, 208, 210, 211, 214, 215, 218]) then
          begin
            // VIENE DE LA IZQUIERDA
            if (VerticalLine.Col < Length(lineToPrint)) and (ord(lineToPrint[VerticalLine.Col + 1]) in [180, 182, 183, 189, 191, 193, 194, 196, 197, 208, 210, 215, 217]) then
            begin
              // SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
                lineToPrint[VerticalLine.Col] := '�'
              else
                lineToPrint[VerticalLine.Col] := '�';
            end
            else
            begin
              // NO SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
                lineToPrint[VerticalLine.Col] := '�'
              else
                lineToPrint[VerticalLine.Col] := '�';
            end;
          end
          else
          begin
            // NO VA PARA LA IZQUIERDA
            if (VerticalLine.Col < Length(lineToPrint)) and (ord(lineToPrint[VerticalLine.Col + 1]) in [180, 182, 183, 189, 191, 193, 194, 196, 197, 208, 210, 215, 217]) then
            begin
              // SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
                lineToPrint[VerticalLine.Col] := '�'
              else
                lineToPrint[VerticalLine.Col] := '�';
            end
            else
            begin
              // NO SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
              else
                lineToPrint[VerticalLine.Col] := '�';
            end;
          end;
        end
        else if lineToPrint[VerticalLine.Col] = '�' then
        // LINEA HORIZONTAL DOBLE
        begin
          if (VerticalLine.Col > 0) and (ord(lineToPrint[VerticalLine.Col - 1]) in [181, 184, 185, 187, 188, 190, 202, 203, 205, 206, 207, 209, 216]) then
          begin
            // VIENE DE LA IZQUIERDA
            if (VerticalLine.Col < Length(lineToPrint)) and (ord(lineToPrint[VerticalLine.Col + 1]) in [198, 200, 201, 202, 203, 204, 205, 206, 207, 209, 212, 213]) then
            begin
              // SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
                lineToPrint[VerticalLine.Col] := '�'
              else
                lineToPrint[VerticalLine.Col] := '�';
            end
            else
            begin
              // NO SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
                lineToPrint[VerticalLine.Col] := '�'
              else
                lineToPrint[VerticalLine.Col] := '�';
            end;
          end
          else
          begin
            // NO VA PARA LA IZQUIERDA
            if (VerticalLine.Col < Length(lineToPrint)) and (ord(lineToPrint[VerticalLine.Col + 1]) in [198, 200, 201, 202, 203, 204, 205, 206, 207, 209, 212, 213]) then
            begin
              // SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
                lineToPrint[VerticalLine.Col] := '�'
              else
                lineToPrint[VerticalLine.Col] := '�';
            end
            else
            begin
              // NO SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
                lineToPrint[VerticalLine.Col] := '�'
              else
                lineToPrint[VerticalLine.Col] := '�';
            end;
          end;
        end
        else
        // HAY OTRO CODIGO
        begin
          if VerticalLine.Kind = ltSingle then
            lineToPrint[VerticalLine.Col] := '�'
          else
            // Doble
            lineToPrint[VerticalLine.Col] := '�';
        end;
      end
      else
      begin
        // ES UNA LINEA DEL MEDIO

        if lineToPrint[VerticalLine.Col] = '�' then
        // LINEA HORIZONTAL SIMPLE

        begin
          if (VerticalLine.Col > 0) and (ord(lineToPrint[VerticalLine.Col - 1]) in [192, 193, 194, 195, 196, 197, 199, 208, 210, 211, 214, 215, 218]) then
          begin
            // VIENE DE LA IZQUIERDA
            if (VerticalLine.Col < Length(lineToPrint)) and (ord(lineToPrint[VerticalLine.Col + 1]) in [180, 182, 183, 189, 191, 193, 194, 196, 197, 208, 210, 215, 217]) then
            begin
              // SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
                lineToPrint[VerticalLine.Col] := '�'
              else
                lineToPrint[VerticalLine.Col] := '�';
            end
            else
            begin
              // NO SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
                lineToPrint[VerticalLine.Col] := '�'
              else
                lineToPrint[VerticalLine.Col] := '�';
            end;
          end
          else
          begin
            // NO VA PARA LA IZQUIERDA
            if (VerticalLine.Col < Length(lineToPrint)) and (ord(lineToPrint[VerticalLine.Col + 1]) in [180, 182, 183, 189, 191, 193, 194, 196, 197, 208, 210, 215, 217]) then
            begin
              // SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
                lineToPrint[VerticalLine.Col] := '�'
              else
                lineToPrint[VerticalLine.Col] := '�';
            end
            else
            begin
              // NO SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
                lineToPrint[VerticalLine.Col] := '�'
              else
                lineToPrint[VerticalLine.Col] := '�';
            end;
          end;
        end
        else if lineToPrint[VerticalLine.Col] = '�' then
        // LINEA HORIZONTAL DOBLE
        begin
          if (VerticalLine.Col > 0) and (ord(lineToPrint[VerticalLine.Col - 1]) in [198, 200, 201, 202, 203, 204, 205, 206, 207, 209, 212, 213]) then
          begin
            // VIENE DE LA IZQUIERDA
            if (VerticalLine.Col < Length(lineToPrint)) and (ord(lineToPrint[VerticalLine.Col + 1]) in [181, 184, 185, 187, 188, 190, 202, 203, 205, 206, 207, 209, 216]) then
            begin
              // SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
                lineToPrint[VerticalLine.Col] := '�'
              else
                lineToPrint[VerticalLine.Col] := '�';
            end
            else
            begin
              // NO SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
                lineToPrint[VerticalLine.Col] := '�'
              else
                lineToPrint[VerticalLine.Col] := '�';
            end;
          end
          else
          begin
            // NO VA PARA LA IZQUIERDA
            if (VerticalLine.Col < Length(lineToPrint)) and (ord(lineToPrint[VerticalLine.Col + 1]) in [181, 184, 185, 187, 188, 190, 202, 203, 205, 206, 207, 209, 216]) then
            begin
              // SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
                lineToPrint[VerticalLine.Col] := '�'
              else
                lineToPrint[VerticalLine.Col] := '�';
            end
            else
            begin
              // NO SIGUE A LA DERECHA
              if VerticalLine.Kind = ltSingle then
                lineToPrint[VerticalLine.Col] := '�'
              else
                lineToPrint[VerticalLine.Col] := '�';
            end;
          end;
        end
        else
        begin
          if VerticalLine.Kind = ltSingle then
            lineToPrint[VerticalLine.Col] := '�'
          else
            // Doble
            lineToPrint[VerticalLine.Col] := '�';
        end;
      end;
    end;
  end;
end;

procedure TFastMode.PrintHorizontalLines(currentLine: Integer; page: TPage; var lineToPrint: string);
var
  HorizontalLine: THorizontalLine;
  I: Integer;
  Contador: Integer;
begin
  // ANALIZO PRIMERO LAS LINEAS HORIZONTALES
  for Contador := 0 to page.HorizontalLines.Count - 1 do
  begin
    HorizontalLine := page.HorizontalLines.Items[Contador];
    // ES EN ESTA LINEA
    if HorizontalLine.Line = currentLine then
    begin
      TUtils.InflateLineWithSpaces(lineToPrint, HorizontalLine.Col2);
      if HorizontalLine.Kind = ltSingle then
      begin
        for I := HorizontalLine.Col1 to HorizontalLine.Col2 do
          lineToPrint[I] := SINGLE_LINE;
      end
      else
      begin
        for I := HorizontalLine.Col1 to HorizontalLine.Col2 do
          lineToPrint[I] := DOUBLE_LINE;
      end;
    end;
  end;
end;

procedure TFastMode.PrintControlCodes(codeSequence: string);
var
  CodesToPrint: TStringList;
  CodeToPrint: Byte;
  NextCode: Byte;
begin
  if Trim(codeSequence) = '' then
    exit;

  CodesToPrint := TStringList.Create;
  try
    CodesToPrint.Delimiter := ' ';
    CodesToPrint.DelimitedText := Trim(codeSequence);

    for NextCode := 0 to CodesToPrint.Count-1 do
    begin
      CodeToPrint := StrToInt(CodesToPrint[NextCode]);
      FFastDevice.Write(Chr(CodeToPrint));
    end;
  finally
    CodesToPrint.Free;
  end;
end;

procedure TFastMode.PageContinuosJump;
var
  LinesToJump: Integer;
begin
  for LinesToJump := 1 to FDocument.PageContinuousJump do
    FFastDevice.WriteLn('');
end;

procedure TFastMode.PrintCurrentLine(page: TPage; var ultimaEscritura: Integer; font: TFastFont; var lineToPrint: string; const currentLine: Integer);
var
  Escritura: TWrittenText;
  i: Integer;
  Contador: Integer;
  Columna: Byte;
  LineWasPrinted: Boolean;
  Txt : string;
begin
  if page.WrittenText.Count = UltimaEscritura then
  begin
    if font <> FDocument.DefaultFont then
    begin // PONEMOS LA FUENTE POR DEFAULT
      font := FDocument.DefaultFont;
      PrintFontCodes(font);
    end;

    if FDocument.Transliterate and (lineToPrint <> '') then
      CharToOemBuff(PChar(@lineToPrint[1]), PansiChar(@lineToPrint[1]),Length(lineToPrint));
    FFastDevice.WriteLn(lineToPrint);
  end
  else
  begin
    LineWasPrinted := False;
    Contador := UltimaEscritura;
    Columna := 1;
    Escritura := page.WrittenText.Items[Contador];
    while (Contador < page.WrittenText.Count) and (Escritura.Line <= currentLine) do
    begin
      if Escritura.Line = currentLine then
      begin
        LineWasPrinted := True;
        UltimaEscritura := Contador;
        TUtils.InflateLineWithSpaces(lineToPrint, Escritura.Col+Length(Escritura.Text));
        while Columna < Escritura.Col do
        begin
          if (lineToPrint[Columna] <> #32) and (font <> FDocument.DefaultFont) then
          begin // PONEMOS LA FUENTE POR DEFAULT
            font := FDocument.DefaultFont;
            PrintFontCodes(font);
          end;

          FFastDevice.Write(lineToPrint[Columna]);
          Inc(Columna);
        end;

        if Escritura.Font <> font then
        begin // PONEMOS LA FUENTE DEL TEXTO
          font := Escritura.Font;
          PrintFontCodes(font);
        end;

        Txt := Escritura.Text;
        if FDocument.Transliterate and (Txt<>'') then
          CharToOemBuff(PChar(@Txt[1]), PansiChar(@Txt[1]),Length(Txt));
        FFastDevice.Write(Txt);
        if (Compress in font) and not(Compress in FDocument.DefaultFont) then
        begin
          for i := 1 to Length(Escritura.Text) do
            FFastDevice.Write(#8);
          if (Length(Escritura.Text)*6) mod 10 = 0 then
            i := Columna + (Length(Escritura.Text) *6) div 10
          else
            i := Columna + (Length(Escritura.Text) *6) div 10;

          font := font - [Compress];
          PrintFontCodes(font);

          while Columna <= i do
          begin
            FFastDevice.Write(#32);
            Inc(Columna);
          end;
        end
        else
          Columna := Columna + Length(Escritura.Text);
      end;
      Inc(Contador);
      if Contador < page.WrittenText.Count then
        Escritura := page.WrittenText.Items[Contador];
    end;

    if LineWasPrinted then
    begin
      if font <> FDocument.DefaultFont then
      begin // PONEMOS LA FUENTE POR DEFAULT
        font := FDocument.DefaultFont;
        PrintFontCodes(font);
      end;

      while Columna <= Length(lineToPrint) do
      begin
        FFastDevice.Write(lineToPrint[Columna]);
        Inc(Columna);
      end;

      FFastDevice.WriteLn('');
    end
    else
    begin
      if font <> FDocument.DefaultFont then
      begin // PONEMOS LA FUENTE POR DEFAULT
        font := FDocument.DefaultFont;
        PrintFontCodes(font);
      end;

      if FDocument.Transliterate and (lineToPrint <> '') then
        AnsiToOemBuff(PansiChar(lineToPrint[1]), PansiChar(lineToPrint[1]), Length(lineToPrint));

      FFastDevice.WriteLn(lineToPrint);
    end;
  end;
end;

end.
