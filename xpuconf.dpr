program xpuconf;

uses Windows, Messages, Commdlg, utils;

var
  Wnd: TWndClass;
  Msg: TMsg;
  SmallFont, BigFont: THandle;
  tempColor, fontColor, backColor: Cardinal;
  setfile: PChar;
  Buffer, BufDisk: array[0..255] of Char;
  fontName, descName: array[0..31] of Char;
  P: array[1..10] of Char;
  S: array[1..10] of Integer;
  CustomColors: array[1..16] of integer;

  E3 : THandle;
  E1, E2,  E5, E6, E7, E8, E9, E10, E11, O1, O2, O3, O4, O5, C1, C2, C3, C4, C5, U1, U2, U4,
  T1, T2, T4, A1, A2, A4, F,  i, nmax, part, fontHeight, fontWeight, descHeight, descWeight: Integer;
  FontLog1: TLogFont;

function NewChooseFont1: Boolean;
var
  ChooseFont1: TChooseFont;
begin
  with ChooseFont1 do
  begin
    lStructSize := SizeOf(ChooseFont1);
    hWndOwner := F;
    hDC := 0;
    lpLogFont := @FontLog1;
    nSizeMax := 10;
    nSizeMin := 1;
    Flags := CF_INITTOLOGFONTSTRUCT or CF_FORCEFONTEXIST or CF_LIMITSIZE or CF_SCREENFONTS or CF_SCRIPTSONLY;
    lpfnHook := nil;
  end;

  Result := ChooseFont(ChooseFont1);
end;

function NewColorDialog1: Boolean;
var
  ChooseColor1: TChooseColor;
begin
  with ChooseColor1 do
  begin
    lStructSize := Sizeof(ChooseColor1);
    hWndOwner := 0;
    rgbResult := tempColor;
    lpCustColors := @CustomColors[1];
    Flags := CC_RGBINIT or CC_FULLOPEN;
  end;

  Result := ChooseColor(ChooseColor1);
  if Result then tempColor := ChooseColor1.rgbResult;
end;

function WndProc(Wnd: HWND; uMsg: UINT; wPar: WPARAM; lPar: LPARAM): LRESULT; stdcall;
var
  d: char;
  n: integer;
  paintDC, DC: HDC;
  paintBMP: HBITMAP;
  PaintS: TPaintStruct;
  pDrawItem: PDrawItemStruct;
begin
  Result := 0;
  case uMsg of
    WM_CREATE:
    begin
      CreateWindow('BUTTON', 'SAVE', WS_CHILD or WS_VISIBLE or BS_OWNERDRAW, 200, 460, 115, 33, Wnd, 14, hInstance, nil);
      CreateWindow('BUTTON', 'CANCEL', WS_CHILD or WS_VISIBLE or BS_OWNERDRAW, 400, 460, 115, 33, Wnd, 15, hInstance, nil);
      CreateWindow('BUTTON', 'Main Text', WS_CHILD or WS_VISIBLE or BS_OWNERDRAW, 220, 295, 125, 25, Wnd, 16, hInstance, nil);
      CreateWindow('BUTTON', 'Description', WS_CHILD or WS_VISIBLE or BS_OWNERDRAW, 220, 325, 125, 25, Wnd, 17, hInstance, nil);
      CreateWindow('BUTTON', 'Color', WS_CHILD or WS_VISIBLE or BS_OWNERDRAW, 220, 355, 125, 25, Wnd, 18, hInstance, nil);
      CreateWindow('BUTTON', 'Background', WS_CHILD or WS_VISIBLE or BS_OWNERDRAW, 400, 355, 105, 25, Wnd, 19, hInstance, nil);

      C1 := CreateWindow('BUTTON', 'Memory', WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX or BS_TEXT, 50, 50, 100, 21, Wnd, 0, hInstance, nil);
      C2 := CreateWindow('BUTTON', 'Pagefile', WS_CHILD or WS_VISIBLE  or BS_AUTOCHECKBOX or BS_TEXT, 50, 90, 100, 21, Wnd, 0, hInstance, nil);
      C3 := CreateWindow('BUTTON', 'CPU', WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX or BS_TEXT, 50, 170, 100, 21, Wnd, 0, hInstance, nil);
      C4 := CreateWindow('BUTTON', 'Disk', WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX or BS_TEXT, 50, 130, 100, 21, Wnd, 0, hInstance, nil);
      C5 := CreateWindow('BUTTON', 'Trash', WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX or BS_TEXT, 50, 210, 100, 21, Wnd, 0, hInstance, nil);
      U1 := CreateWindow('BUTTON', 'Show', WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX or BS_TEXT, 350, 50, 100, 21, Wnd, 0, hInstance, nil);
      U2 := CreateWindow('BUTTON', 'Show', WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX or BS_TEXT, 350, 90, 100, 21, Wnd, 0, hInstance, nil);
      U4 := CreateWindow('BUTTON', 'Show', WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX or BS_TEXT, 350, 130, 100, 21, Wnd, 0, hInstance, nil);
      T1 := CreateWindow('BUTTON', 'Show', WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX or BS_TEXT, 450, 50, 100, 21, Wnd, 0, hInstance, nil);
      T2 := CreateWindow('BUTTON', 'Show', WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX or BS_TEXT, 450, 90, 100, 21, Wnd, 0, hInstance, nil);
      T4 := CreateWindow('BUTTON', 'Show', WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX or BS_TEXT, 450, 130, 100, 21, Wnd, 0, hInstance, nil);
      A1 := CreateWindow('BUTTON', 'Show', WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX or BS_TEXT, 550, 50, 100, 21, Wnd, 0, hInstance, nil);
      A2 := CreateWindow('BUTTON', 'Show', WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX or BS_TEXT, 550, 90, 100, 21, Wnd, 0, hInstance, nil);
      A4 := CreateWindow('BUTTON', 'Show', WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX or BS_TEXT, 550, 130, 100, 21, Wnd, 0, hInstance, nil);
      O1 := CreateWindow('BUTTON', 'Show icons      (', WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX or BS_TEXT, 400, 300, 120, 21, Wnd, 0, hInstance, nil);
      O2 := CreateWindow('BUTTON', 'User icons)', WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX or BS_TEXT, 525, 300, 100, 21, Wnd, 0, hInstance, nil);
      O3 := CreateWindow('BUTTON', 'Show bars       (', WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX or BS_TEXT, 400, 330, 120, 21, Wnd, 0, hInstance, nil);
      O4 := CreateWindow('BUTTON', 'Rounded )', WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX or BS_TEXT, 525, 330, 85, 21, Wnd, 0, hInstance, nil);
      O5 := CreateWindow('BUTTON', 'Transparent )', WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX or BS_TEXT, 525, 360, 110, 21, Wnd, 0, hInstance, nil);

      GetPrivateProfileString('Base', 'enableMemory', nil, Buffer, SizeOf(Buffer), setfile);
      if Buffer[0] = '1' then SendMessage(C1, BM_SETCHECK, 1, 0);
      GetPrivateProfileString('Base', 'enablePagefile', nil, Buffer, SizeOf(Buffer), setfile);
      if Buffer[0] = '1' then SendMessage(C2, BM_SETCHECK, 1, 0);
      GetPrivateProfileString('Base', 'enableCPU', nil, Buffer, SizeOf(Buffer), setfile);
      if Buffer[0] = '1' then SendMessage(C3, BM_SETCHECK, 1, 0);
      GetPrivateProfileString('Base', 'enableDisk', nil, Buffer, SizeOf(Buffer), setfile);
      if Buffer[0] = '1' then SendMessage(C4, BM_SETCHECK, 1, 0);
      GetPrivateProfileString('Base', 'enableTrash', nil, Buffer, SizeOf(Buffer), setfile);
      if Buffer[0] = '1' then SendMessage(C5, BM_SETCHECK, 1, 0);
      GetPrivateProfileString('Base', 'usageMemory', nil, Buffer, SizeOf(Buffer), setfile);
      if Buffer[0] = '1' then SendMessage(U1, BM_SETCHECK, 1, 0);
      GetPrivateProfileString('Base', 'usagePagefile', nil, Buffer, SizeOf(Buffer), setfile);
      if Buffer[0] = '1' then SendMessage(U2, BM_SETCHECK, 1, 0);
      GetPrivateProfileString('Base', 'usageDisk', nil, Buffer, SizeOf(Buffer), setfile);
      if Buffer[0] = '1' then SendMessage(U4, BM_SETCHECK, 1, 0);
      GetPrivateProfileString('Base', 'totalMemory', nil, Buffer, SizeOf(Buffer), setfile);
      if Buffer[0] = '1' then SendMessage(T1, BM_SETCHECK, 1, 0);
      GetPrivateProfileString('Base', 'totalPagefile', nil, Buffer, SizeOf(Buffer), setfile);
      if Buffer[0] = '1' then SendMessage(T2, BM_SETCHECK, 1, 0);
      GetPrivateProfileString('Base', 'totalDisk', nil, Buffer, SizeOf(Buffer), setfile);
      if Buffer[0] = '1' then SendMessage(T4, BM_SETCHECK, 1, 0);
      GetPrivateProfileString('Base', 'availableMemory', nil, Buffer, SizeOf(Buffer), setfile);
      if Buffer[0] = '1' then SendMessage(A1, BM_SETCHECK, 1, 0);
      GetPrivateProfileString('Base', 'availablePagefile', nil, Buffer, SizeOf(Buffer), setfile);
      if Buffer[0] = '1' then SendMessage(A2, BM_SETCHECK, 1, 0);
      GetPrivateProfileString('Base', 'availableDisk', nil, Buffer, SizeOf(Buffer), setfile);
      if Buffer[0] = '1' then SendMessage(A4, BM_SETCHECK, 1, 0);
      GetPrivateProfileString('Base', 'showIcons', nil, Buffer, SizeOf(Buffer), setfile);
      if Buffer[0] = '1' then SendMessage(O1, BM_SETCHECK, 1, 0);
      GetPrivateProfileString('Base', 'showUserIcons', nil, Buffer, SizeOf(Buffer), setfile);
      if Buffer[0] = '1' then SendMessage(O2, BM_SETCHECK, 1, 0);
      GetPrivateProfileString('Base', 'showBars', nil, Buffer, SizeOf(Buffer), setfile);
      if Buffer[0] = '1' then SendMessage(O3, BM_SETCHECK, 1, 0);
      GetPrivateProfileString('Base', 'showRounded', nil, Buffer, SizeOf(Buffer), setfile);
      if Buffer[0] = '1' then SendMessage(O4, BM_SETCHECK, 1, 0);
      GetPrivateProfileString('Base', 'showTransparent', nil, Buffer, SizeOf(Buffer), setfile);
      if Buffer[0] = '1' then SendMessage(O5, BM_SETCHECK, 1, 0);

      GetPrivateProfileString('Base', 'labelMemory', 'Memory', Buffer, SizeOf(Buffer), setfile);
      E1 := CreateWindow('EDIT', Buffer, WS_CHILD or WS_VISIBLE or WS_BORDER, 200, 50, 105, 25, Wnd, 0, hInstance, nil);
      GetPrivateProfileString('Base', 'labelPagefile', 'Pagefile', Buffer, SizeOf(Buffer), setfile);
      E2 := CreateWindow('EDIT', Buffer, WS_CHILD or WS_VISIBLE or WS_BORDER, 200, 90, 105, 25, Wnd, 0, hInstance, nil);
      GetPrivateProfileString('Base', 'labelCPU', 'CPU', Buffer, SizeOf(Buffer), setfile);
      E3 := CreateWindow('EDIT', Buffer, WS_CHILD or WS_VISIBLE or WS_BORDER, 200, 170, 105, 25, Wnd, 0, hInstance, nil);
      GetPrivateProfileString('Base', 'labelTrash', 'Trash', Buffer, SizeOf(Buffer), setfile);
      E5 := CreateWindow('EDIT', Buffer, WS_CHILD or WS_VISIBLE or WS_BORDER, 200, 210, 105, 25, Wnd, 0, hInstance, nil);
      GetPrivateProfileString('Base', 'timeInterval', '1000', Buffer, SizeOf(Buffer), setfile);
      E6 := CreateWindow('EDIT', Buffer, WS_CHILD or WS_VISIBLE or WS_BORDER or ES_NUMBER, 110, 360, 45, 20, Wnd, 0, hInstance, nil);
      GetPrivateProfileString('Base', 'posX', PChar(Int2Str(GetSystemMetrics(SM_CXSCREEN)-400)), Buffer, SizeOf(Buffer), setfile);
      E7 := CreateWindow('EDIT', Buffer, WS_CHILD or WS_VISIBLE or WS_BORDER or ES_NUMBER, 110, 300, 45, 20, Wnd, 0, hInstance, nil);
      GetPrivateProfileString('Base', 'posY', '200', Buffer, SizeOf(Buffer), setfile);
      E8 := CreateWindow('EDIT', Buffer, WS_CHILD or WS_VISIBLE or WS_BORDER or ES_NUMBER, 110, 330, 45, 20, Wnd, 0, hInstance, nil);
      GetPrivateProfileString('Base', 'labelUsage', 'Usage: ', Buffer, SizeOf(Buffer), setfile);
      E9 := CreateWindow('EDIT', Buffer, WS_CHILD or WS_VISIBLE or WS_BORDER, 350, 20, 80, 20, Wnd, 0, hInstance, nil);
      GetPrivateProfileString('Base', 'labelTotal', 'Total: ', Buffer, SizeOf(Buffer), setfile);
      E10 := CreateWindow('EDIT', Buffer, WS_CHILD or WS_VISIBLE or WS_BORDER, 450, 20, 80, 20, Wnd, 0, hInstance, nil);
      GetPrivateProfileString('Base', 'labelAvailable', 'Available: ', Buffer, SizeOf(Buffer), setfile);
      E11 := CreateWindow('EDIT', Buffer, WS_CHILD or WS_VISIBLE or WS_BORDER, 550, 20, 80, 20, Wnd, 0, hInstance, nil);

      GetPrivateProfileString('Base', 'showPart', nil, Buffer, SizeOf(Buffer), setfile);
      i := 1;
      for d := 'A' to 'Z' do
        case GetDriveType(PChar(d + ':\')) of DRIVE_FIXED, DRIVE_REMOVABLE: begin
        S[i] := CreateWindow('BUTTON', PChar(d + ''), WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX or BS_TEXT, 160+(40*i), 410, 32, 21, Wnd, 0, hInstance, nil);
        if StrScan(Buffer, d) <> nil then SendMessage(S[i], BM_SETCHECK, 1, 0);
        P[i] := d;
        Inc(i);
        end;
      end;
      nmax := i-1;

      GetPrivateProfileString('Base', 'fontColor', nil, Buffer, SizeOf(Buffer), setfile);
      fontColor := S2Int(Buffer);
      GetPrivateProfileString('Base', 'backColor', nil, Buffer, SizeOf(Buffer), setfile);
      backColor := S2Int(Buffer);

      GetPrivateProfileString('Base', 'fontHeight', nil, Buffer, SizeOf(Buffer), setfile);
      fontHeight := S2Int(Buffer);
      GetPrivateProfileString('Base', 'fontWeight', nil, Buffer, SizeOf(Buffer), setfile);
      fontWeight := S2Int(Buffer);
      GetPrivateProfileString('Base', 'fontName', nil, Buffer, SizeOf(Buffer), setfile);
      lstrcpy(fontName,Buffer);
      GetPrivateProfileString('Base', 'descHeight', nil, Buffer, SizeOf(Buffer), setfile);
      descHeight := S2Int(Buffer);
      GetPrivateProfileString('Base', 'descWeight', nil, Buffer, SizeOf(Buffer), setfile);
      descWeight := S2Int(Buffer);
      GetPrivateProfileString('Base', 'descName', nil, Buffer, SizeOf(Buffer), setfile);
      lstrcpy(descName,Buffer);
    end;

    WM_PAINT:
    begin
      DC := BeginPaint(Wnd, PaintS);
      paintDC := CreateCompatibleDC(DC);
      paintBMP := CreateCompatibleBitmap(DC, 700, 540);
      SelectObject(paintDC, paintBMP);
      FloodFill(paintDC, 0, 0, GetStockObject(WHITE_BRUSH));

      SelectObject(paintDC, BigFont);
      TextOut(paintDC, 50, 20, 'Components', 10);
      TextOut(paintDC, 200, 20, 'Label', 5);
      TextOut(paintDC, 50, 270, 'Window', 6);
      TextOut(paintDC, 220, 270, 'Font', 4);
      TextOut(paintDC, 400, 270, 'Visual', 6);

      SelectObject(paintDC, SmallFont);
      TextOut(paintDC, 50, 300, 'Pos.X', 5);
      TextOut(paintDC, 50, 330, 'Pos.Y', 5);
      TextOut(paintDC, 50, 360, 'Refresh', 7);
      TextOut(paintDC, 160, 360, 'ms', 2);
      TextOut(paintDC, 512, 360, '(', 1);
      TextOut(paintDC, 50, 410, 'Selected partitions:', 20);
      BitBlt(DC, 0, 0, 700, 540, paintDC, 0, 0, SRCCOPY);
      EndPaint(Wnd,PaintS);

      DeleteObject(BigFont);
      DeleteObject(SmallFont);
      DeleteObject(paintBMP);
      DeleteDC(paintDC);
    end;

    WM_CTLCOLORSTATIC:
    begin
      if (lPar = O1) or (lPar = O2) or (lPar = O3) or (lPar = O4) or (lPar = O5) or (lPar = C1) or (lPar = C2) or (lPar = C3) or (lPar = C4) or (lPar = C5) or
         (lPar = U1) or (lPar = U2) or (lPar = U4) or (lPar = T1) or (lPar = T2) or (lPar = T4) or (lPar = A1) or (lPar = A2) or
         (lPar = A4) or (lPar = S[1]) or (lPar = S[2]) or (lPar = S[3]) or (lPar = S[4]) or (lPar = S[5]) or (lPar = S[6]) or
         (lPar = S[7]) or (lPar = S[8]) or (lPar = S[9]) or (lPar = S[10]) then
      begin
        SelectObject(wPar, SmallFont);
        Result := GetStockObject(WHITE_BRUSH);
        Exit;
      end;
    end;

    WM_DRAWITEM:
    begin
      pDrawItem := Pointer(lPar);

      if (wPar = 14) or (wPar = 15) or (wPar = 16) or (wPar = 17) or (wPar = 18) or (wPar = 19) then
      begin
        SelectObject(pDrawItem.hDC, BigFont);

        if pDrawItem.itemAction = ODA_SELECT then
        begin
          FillRect(pDrawItem.hDC, pDrawItem.rcItem, GetStockObject(LTGRAY_BRUSH));
          FrameRect(pDrawItem.hDC, pDrawItem.rcItem, GetStockObject(LTGRAY_BRUSH));
          SetBkMode(pDrawItem.hDC,TRANSPARENT);
          SetTextColor(pDrawItem.hDC,$FFFFFF);
        end else

        begin
          FillRect(pDrawItem.hDC, pDrawItem.rcItem, GetStockObject(WHITE_BRUSH));
          FrameRect(pDrawItem.hDC, pDrawItem.rcItem, GetStockObject(BLACK_BRUSH));
          SetBkMode(pDrawItem.hDC,TRANSPARENT);
          SetTextColor(pDrawItem.hDC,$000000);
        end;

        if wPar = 14 then TextOut(pDrawItem.hDC,36,6,'SAVE',4);
        if wPar = 15 then TextOut(pDrawItem.hDC,28,6,'CANCEL',6);
        if wPar = 16 then TextOut(pDrawItem.hDC,28,4,'Main Text',9);
        if wPar = 17 then TextOut(pDrawItem.hDC,25,4,'Description',11);
        if wPar = 18 then TextOut(pDrawItem.hDC,42,4,'Color',5);
        if wPar = 19 then TextOut(pDrawItem.hDC,10,4,'Background',10);
        Result := 1;
        Exit;
      end;
    end;

    WM_COMMAND:
    begin
      case wPar of
      14: begin
        GetWindowText(E1, @Buffer, SizeOf(Buffer));
        WritePrivateProfileString('Base', 'labelMemory', Buffer, setfile);
        GetWindowText(E2, @Buffer, SizeOf(Buffer));
        WritePrivateProfileString('Base', 'labelPagefile', Buffer, setfile);
        GetWindowText(E3, @Buffer, SizeOf(Buffer));
        WritePrivateProfileString('Base', 'labelCPU', Buffer, setfile);
        GetWindowText(E5, @Buffer, SizeOf(Buffer));
        WritePrivateProfileString('Base', 'labelTrash', Buffer, setfile);
        GetWindowText(E6, @Buffer, SizeOf(Buffer));
        WritePrivateProfileString('Base', 'timeInterval', Buffer, setfile);
        GetWindowText(E7, @Buffer, SizeOf(Buffer));
        WritePrivateProfileString('Base', 'posX', Buffer, setfile);
        GetWindowText(E8, @Buffer, SizeOf(Buffer));
        WritePrivateProfileString('Base', 'posY', Buffer, setfile);
        GetWindowText(E9, @Buffer, SizeOf(Buffer));
        WritePrivateProfileString('Base', 'labelUsage', Buffer, setfile);
        GetWindowText(E10, @Buffer, SizeOf(Buffer));
        WritePrivateProfileString('Base', 'labelTotal', Buffer, setfile);
        GetWindowText(E11, @Buffer, SizeOf(Buffer));
        WritePrivateProfileString('Base', 'labelAvailable', Buffer, setfile);

        WritePrivateProfileString('Base', 'enableMemory', PChar(Int2Str(SendMessage(C1, BM_GETCHECK, 0, 0))), setfile);
        WritePrivateProfileString('Base', 'enablePagefile', PChar(Int2Str(SendMessage(C2, BM_GETCHECK, 0, 0))), setfile);
        WritePrivateProfileString('Base', 'enableCPU', PChar(Int2Str(SendMessage(C3, BM_GETCHECK, 0, 0))), setfile);
        WritePrivateProfileString('Base', 'enableDisk', PChar(Int2Str(SendMessage(C4, BM_GETCHECK, 0, 0))), setfile);
        WritePrivateProfileString('Base', 'enableTrash', PChar(Int2Str(SendMessage(C5, BM_GETCHECK, 0, 0))), setfile);
        WritePrivateProfileString('Base', 'usageMemory', PChar(Int2Str(SendMessage(U1, BM_GETCHECK, 0, 0))), setfile);
        WritePrivateProfileString('Base', 'usagePagefile', PChar(Int2Str(SendMessage(U2, BM_GETCHECK, 0, 0))), setfile);
        WritePrivateProfileString('Base', 'usageDisk', PChar(Int2Str(SendMessage(U4, BM_GETCHECK, 0, 0))), setfile);
        WritePrivateProfileString('Base', 'totalMemory', PChar(Int2Str(SendMessage(T1, BM_GETCHECK, 0, 0))), setfile);
        WritePrivateProfileString('Base', 'totalPagefile', PChar(Int2Str(SendMessage(T2, BM_GETCHECK, 0, 0))), setfile);
        WritePrivateProfileString('Base', 'totalDisk', PChar(Int2Str(SendMessage(T4, BM_GETCHECK, 0, 0))), setfile);
        WritePrivateProfileString('Base', 'availableMemory', PChar(Int2Str(SendMessage(A1, BM_GETCHECK, 0, 0))), setfile);
        WritePrivateProfileString('Base', 'availablePagefile', PChar(Int2Str(SendMessage(A2, BM_GETCHECK, 0, 0))), setfile);
        WritePrivateProfileString('Base', 'availableDisk', PChar(Int2Str(SendMessage(A4, BM_GETCHECK, 0, 0))), setfile);
        WritePrivateProfileString('Base', 'showIcons', PChar(Int2Str(SendMessage(O1, BM_GETCHECK, 0, 0))), setfile);
        WritePrivateProfileString('Base', 'showUserIcons', PChar(Int2Str(SendMessage(O2, BM_GETCHECK, 0, 0))), setfile);
        WritePrivateProfileString('Base', 'showBars', PChar(Int2Str(SendMessage(O3, BM_GETCHECK, 0, 0))), setfile);
        WritePrivateProfileString('Base', 'showRounded', PChar(Int2Str(SendMessage(O4, BM_GETCHECK, 0, 0))), setfile);
        WritePrivateProfileString('Base', 'showTransparent', PChar(Int2Str(SendMessage(O5, BM_GETCHECK, 0, 0))), setfile);

        part := 0;
        for n := 1 to nmax do
          if SendMessage(S[n], BM_GETCHECK, 0, 0) = BST_CHECKED then
          begin
            BufDisk[part] := P[n];
            Inc(part);
          end;
        lstrcpyn(Buffer, BufDisk, part+1);

        WritePrivateProfileString('Base', 'showPart', Buffer, setfile);
        WritePrivateProfileString('Base', 'fontColor', PChar(Int2Str(fontcolor)), setfile);
        WritePrivateProfileString('Base', 'backColor', PChar(Int2Str(backcolor)), setfile);

        WritePrivateProfileString('Base', 'fontHeight', PChar(Int2Str(fontHeight)), setfile);
        WritePrivateProfileString('Base', 'fontWeight', PChar(Int2Str(fontWeight)), setfile);
        WritePrivateProfileString('Base', 'fontName', fontName, setfile);
        WritePrivateProfileString('Base', 'descHeight', PChar(Int2Str(descHeight)), setfile);
        WritePrivateProfileString('Base', 'descWeight', PChar(Int2Str(descWeight)), setfile);
        WritePrivateProfileString('Base', 'descName', descName, setfile);

        MessageBox(Wnd, 'Options saved to settings.ini', 'Saved', MB_OK + MB_ICONINFORMATION);
        PostQuitMessage(0);
      end;

      15: PostQuitMessage(0);

      16: begin
        with FontLog1 do
        begin
          if fontHeight <> 0 then lfHeight := fontHeight else lfHeight := -13;
          lfWidth := 0;
          lfItalic := 0;
          if fontWeight <> 0 then lfWeight := fontWeight else lfWeight := 700;
          lfCharSet := DEFAULT_CHARSET;
          lfOutPrecision := OUT_TT_PRECIS;
          lfClipPrecision := CLIP_DEFAULT_PRECIS;
          lfQuality := ANTIALIASED_QUALITY;
          lfPitchAndFamily := VARIABLE_PITCH or FF_ROMAN;
          if fontName <> '' then lstrcpy(lfFaceName, fontName) else lfFaceName := 'Tahoma';
        end;

        if NewChooseFont1 then
        begin
          fontHeight := FontLog1.lfHeight;
          fontWeight := FontLog1.lfWeight;
          lstrcpy(fontName, FontLog1.lfFaceName);
        end;
      end;

      17: begin
        with FontLog1 do
        begin
          if descHeight <> 0 then lfHeight := descHeight else lfHeight := -11;  
          lfWidth := 0;
          lfItalic := 0;
          if descWeight <> 0 then lfWeight := descWeight else lfWeight := 400;
          lfCharSet := DEFAULT_CHARSET;
          lfOutPrecision := OUT_TT_PRECIS;
          lfClipPrecision := CLIP_DEFAULT_PRECIS;
          lfQuality := ANTIALIASED_QUALITY;
          lfPitchAndFamily := VARIABLE_PITCH or FF_ROMAN;
          if descName <> '' then lstrcpy(lfFaceName, descName) else lfFaceName := 'Tahoma';
        end;

        if NewChooseFont1 then
        begin
          descHeight := FontLog1.lfHeight;
          descWeight := FontLog1.lfWeight;
          lstrcpy(descName, FontLog1.lfFaceName);
        end;
      end;

      18: begin
        tempColor := fontColor;
        NewColorDialog1;
        fontColor := tempColor;
      end;

      19: begin
        tempColor := backColor;
        NewColorDialog1;
        backColor := tempColor;
      end;

      end;
    end;

    WM_DESTROY: PostQuitMessage(0);

    else Result := DefWindowProc(Wnd, uMsg, wPar, lPar);
  end;
end;

begin
  with Wnd do
  begin
    style := CS_PARENTDC;
    lpfnWndProc := @WndProc;
    hInstance := hInstance;
    lpszClassName := 'XPUConf';
    hbrBackground := 0;
    hIcon := LoadIcon(0, IDI_APPLICATION);
    hCursor := LoadCursor(0, IDC_ARROW);
  end;
  RegisterClass(Wnd);

  setfile := PChar(GetStartDir + 'settings.ini');
  F := CreateWindow('XPUConf', '[XP Usage] Configuration', WS_VISIBLE,
        (GetSystemMetrics(SM_CXSCREEN) div 2)-276, (GetSystemMetrics(SM_CYSCREEN) div 2)-222, 700, 540, 0, 0, hInstance, NIL);

  BigFont := CreateFont(17,0,0,0, FW_BOLD, 0, 0, 0, ANSI_CHARSET, OUT_DEFAULT_PRECIS,
             CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, VARIABLE_PITCH or FF_SWISS, 'Tahoma');
  SmallFont := CreateFont(14,0,0,0,FW_BOLD,0,0,0,ANSI_CHARSET,OUT_DEFAULT_PRECIS,
             CLIP_DEFAULT_PRECIS,DEFAULT_QUALITY,VARIABLE_PITCH or FF_SWISS, 'Tahoma');

  while GetMessage(msg, 0, 0, 0) do
  begin
    TranslateMessage(msg);
    DispatchMessage(msg);
  end;
end.