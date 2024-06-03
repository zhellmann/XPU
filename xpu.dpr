program xpu;

uses
  Windows, Messages, KOL, ShellAPI, utils;

type
  TRGBArray = array[0..32767] of TRGBTriple;
  PRGBArray = ^TRGBArray;

type
  PSHQueryRBInfo = ^TSHQueryRBInfo;
  TSHQueryRBInfo = packed record
    cbSize: DWORD;
    i64Size: I64;
    i64NumItems: I64;
  end;

const
 WM_TRAYICONCLICKED = WM_USER + 1776;
 WS_EX_LAYERED = $80000;

var
  Wnd: TWndClass;
  Msg: TMsg;
  F: HWND;
  IconData: TNotifyIconData;
  SmallFont, BigFont: THandle;

  D, MainDC: HDC;
  newBMP: HBITMAP;
  cBrush, tBrush: HBRUSH;
  hIco: HICON;
  
  MemoryStatus: TMemoryStatus;
  disk_f, disk_t: I64;

  bmi : BITMAPINFO;
  pvBits: Pointer;

  Bmp: PBitmap;

  setfile, desc: PChar;
  Buffer, showPart, labelUsage, labelTotal, labelAvailable: array[0..255] of Char;
  fontName, descName: array[0..31] of Char;
  L: array[0..15, 0..4] of AnsiString;

  timeInterval, posX, posY, fontColor, backColor, fontHeight, fontWeight, descHeight, descWeight, indexCPU, indexDisk, indexMemory,
  indexPagefile, indexTrash, TempX, TempY, h, idx, FHeight: Integer;

  enableMemory, enablePagefile, enableCPU, enableDisk, enableTrash, usageMemory, usagePagefile, usageDisk,
  totalMemory, totalPagefile, totalDisk, availableMemory, availablePagefile, availableDisk,
  showIcons, showUserIcons, showBars, showRounded, showTransparent: Boolean;


function SetLayeredWindowAttributes(Wnd: hwnd; crKey: ColorRef; Alpha: Byte; dwFlags: DWORD): Boolean; stdcall; external 'user32.dll';
function SHQueryRecycleBin(szRootPath: PChar; SHQueryRBInfo: PSHQueryRBInfo): HResult; stdcall; external 'shell32.dll' Name 'SHQueryRecycleBinA';
function StrFormatByteSize(dw: DWORD; szBuf: PChar; uiBufSize: UINT): PChar; stdcall; external 'shlwapi.dll' name 'StrFormatByteSizeA';
function StrFormatByteSize64(dw: I64; szBuf: PChar; uiBufSize: UINT): PChar; stdcall; external 'shlwapi.dll' name 'StrFormatByteSize64A';

function GetDllVersion(FileName: PChar): Integer;
var
  InfoSize, Wnd: DWORD;
  VerBuf: Pointer;
  FI: PVSFixedFileInfo;
  VerSize: DWORD;
begin
  Result   := 0;
  InfoSize := GetFileVersionInfoSize(FileName, Wnd);
  if InfoSize <> 0 then
  begin
    GetMem(VerBuf, InfoSize);
    try
      if GetFileVersionInfo(FileName, Wnd, InfoSize, VerBuf) then
        if VerQueryValue(VerBuf, '\', Pointer(FI), VerSize) then Result := FI.dwFileVersionMS;
    finally
      FreeMem(VerBuf);
    end;
  end;
end;


function WndProc(Wnd: HWND; uMsg: UINT; wPar: WPARAM; lPar: LPARAM): LRESULT; stdcall;
var
  DllVersion, j, k, StartX, X, Y: Integer;
  SHQueryRBInfo: TSHQueryRBInfo;
  Excl, FRegion: HRGN;
  Row: PRGBArray;
  TransparentColor: TRGBTriple;
begin
  Result := 0;
  case uMsg of
    WM_TRAYICONCLICKED: if (lpar = WM_LBUTTONDBLCLK) or (lpar = WM_RBUTTONDBLCLK) then PostMessage(Wnd, WM_DESTROY, 0, 0);

    WM_NCHITTEST:
    begin
      ReleaseCapture;
      SendMessage(Wnd, WM_SYSCOMMAND, 61458, 0);
    end;

    WM_TIMER:
    begin
      TempX := 2;
      TempY := 2;

      if enableCPU then L[indexCPU,2] := PChar(String(labelUsage) + ' ' + Int2Str(GetProcessorTimePct) + ' %');

      if (enableMemory) or (enablePagefile) then
      begin
        MemoryStatus.dwLength := SizeOf(MemoryStatus);
        GlobalMemoryStatus(MemoryStatus);
        if enableMemory then L[indexMemory,3] := Int2Str(MemoryStatus.dwMemoryLoad);
        if enablePagefile then L[indexPagefile,3] := Int2Str(Round(((MemoryStatus.dwTotalPageFile - MemoryStatus.dwAvailPageFile)/MemoryStatus.dwTotalPageFile)*100));

        desc := '';
        if usageMemory then desc := PChar(desc + String(labelUsage) + ' ' + L[indexMemory,3] + '%  ');
        if availableMemory then
        begin
          StrFormatByteSize(MemoryStatus.dwAvailPhys, Buffer, SizeOf(Buffer));
          desc := PChar(desc + String(labelAvailable) + ' ' + Buffer + '  ');
        end;
        if totalMemory then desc := PChar(desc + String(labelTotal) + ' ' + L[indexMemory,4] + '  ');
        L[indexMemory,2] := PChar(desc);

        desc := '';
        if usagePagefile then desc := PChar(desc + String(labelUsage) + ' ' + L[indexPagefile,3] + '%  ');
        if availablePagefile then
        begin
          StrFormatByteSize(MemoryStatus.dwAvailPageFile, Buffer, SizeOf(Buffer));
          desc := PChar(desc + String(labelAvailable) + ' ' + Buffer + '  ');
        end;
        if totalPagefile then desc := PChar(desc + String(labelTotal) + ' ' + L[indexPagefile,4] + '  ');
        L[indexPagefile,2] := PChar(desc);
      end;

      if enableDisk then
        for j := 0 to lstrlen(showPart)-1 do
        begin
          desc := '';
          disk_f := DiskFreeSpace(PChar(showPart[j] + ':\'));
          disk_t := Str2Int64(L[indexDisk+j,4]);
          L[indexDisk+j,3] := Int2Str(Round(((Int64_2Double(disk_t)-Int64_2Double(disk_f))/Int64_2Double(disk_t))*100));

          if usageDisk then desc := PChar(desc + String(labelUsage) + ' ' + L[indexDisk+j,3] + '%  ');
          if availableDisk then
          begin
            StrFormatByteSize64(disk_f, Buffer, SizeOf(Buffer));
            desc := PChar(desc + String(labelAvailable) + ' ' + Buffer + '  ');
          end;
          if totalDisk then
          begin
            StrFormatByteSize64(Str2Int64(L[indexDisk+j,4]), Buffer, SizeOf(Buffer));
            desc := PChar(desc + String(labelTotal) + ' ' + Buffer + '  ');
          end;

          L[indexDisk+j,2] := PChar(desc);
        end;
      
      if enableTrash then
      begin
        DllVersion := GetDllVersion(PChar('shell32.dll'));
        if DllVersion >= $00040048 then
        begin
          FillChar(SHQueryRBInfo, SizeOf(TSHQueryRBInfo), #0);
          SHQueryRBInfo.cbSize := SizeOf(TSHQueryRBInfo);
          SHQueryRecycleBin(nil, @SHQueryRBInfo);
          StrFormatByteSize64(SHQueryRBInfo.i64Size, Buffer, 255);
          L[indexTrash,2] := PChar(String(labelTotal) + ' ' + Buffer);
        end;
      end;

      D := GetDC(Wnd);
      MainDC := CreateCompatibleDC(D);
      newBMP := CreateDIBSection(MainDC, bmi, DIB_RGB_COLORS, pvBits, 0, 0);
      SelectObject(MainDC, newBMP);

      SelectObject(MainDC, tBrush);
      ExtFloodFill(MainDC, 0, 0, 1, FLOODFILLBORDER);
      SelectObject(MainDC, cBrush);

      for k:=0 to idx-1 do begin

      if showIcons then
      begin
        if showUserIcons then hIco := ExtractIcon(Wnd, PChar('xpu' + Int2Str(k) + '.ico'), 0)
          else hIco := ExtractIcon(Wnd, 'shell32.dll', S2Int(PChar(L[k,1])));
        DrawIcon(MainDC, TempX+4, TempY+4, hIco);
        DestroyIcon(hIco);
      end;

      SetTextColor(MainDC, fontColor);
      SetBkMode(MainDC, TRANSPARENT);

      SelectObject(MainDC, BigFont);
      TextOut(MainDC, TempX+42, TempY+6, PChar(L[k,0]), Length(L[k,0]));

      SelectObject(MainDC, SmallFont);
      TextOut(MainDC, TempX+42, TempY+22, PChar(L[k,2]), Length(L[k,2]));
      TempY := TempY + 15;

      if (showBars) and (L[k,3] <> '') then
      begin
        if showRounded then RoundRect(MainDC, TempX+42, TempY+22, TempX+42+(2*S2Int(PChar(L[k,3]))), TempY+30, 10, 10)
        else Rectangle(MainDC, TempX+42, TempY+22, TempX+42+(2*S2Int(PChar(L[k,3]))), TempY+30);
        TextOut(MainDC, TempX+250, TempY+22, PChar(L[k,3]+'%'), Length(L[k,3])+1);
      end;

      TempY := TempY + 40;
      end;
        
      if showTransparent then
      begin
        Bmp.Handle := newBMP;
        Bmp.Dormant;
        FRegion := CreateRectRGN(0, 0, 300, Fheight);

        for Y := 0 to FHeight do
        begin
          Row := Bmp.Scanline[Y];
          StartX := -1;
          if Y = 0 then TransparentColor := Row[0];

          for X := 0 to 300 do
          begin
            if  (Row[X].rgbtRed = TransparentColor.rgbtRed) and
                (Row[X].rgbtGreen = TransparentColor.rgbtGreen) and
                (Row[X].rgbtBlue = TransparentColor.rgbtBlue) then
            begin
              if StartX = -1 then StartX := X;
            end else

            begin
              if StartX > -1 then
              begin
                Excl := CreateRectRGN(StartX, Y, X, Y+1);
                CombineRGN(FRegion, FRegion, Excl, RGN_DIFF);
                StartX := -1;
                DeleteObject(Excl);
              end;
            end;
          end;

          if StartX > -1 then
          begin
            Excl := CreateRectRGN(StartX, Y, Bmp.Width, Y+1);
            CombineRGN(FRegion, FRegion, Excl, RGN_DIFF);
            DeleteObject(Excl);
          end;
        end;

        SetWindowRGN(Wnd, FRegion, True);
        DeleteObject(FRegion);
        Bmp.Draw(D, 0, 0);
    //    Bmp.ReleaseHandle;       // This will actually lose the bitmap;
      end;

      if not showTransparent then
      begin
        BitBlt(D, 0, 0, 300, FHeight, MainDC, 0, 0, SRCCOPY);
      end;

      DeleteDC(MainDC);
      ReleaseDC(Wnd, D);
    end;

  //  WM_ERASEBKGND: Result := -1;

    WM_DESTROY: begin
      KillTimer(F,1);
      DeleteObject(BigFont);
      DeleteObject(SmallFont);
      DeleteObject(cbrush);
      DeleteObject(tbrush);
      Bmp.Free;
      Shell_NotifyIcon(NIM_DELETE, @IconData);
      PostQuitMessage(0);
    end;

    else Result := DefWindowProc(Wnd, uMsg, wPar, lPar);
  end;
end;

begin
  with Wnd do
  begin
    style := CS_PARENTDC;
    lpfnWndProc := @WndProc;
    hInstance := hInstance;
    lpszClassName := 'XPU';
    hbrBackground := 0;  // GetStockObject(WHITE_BRUSH)
    hIcon := LoadIcon(0, IDI_APPLICATION);
    hCursor := LoadCursor(0, IDC_ARROW);
  end;
  RegisterClass(Wnd);

  idx := 0;
  setfile := PChar(GetStartDir + 'settings.ini');
  GetPrivateProfileString('Base', 'posX', nil, Buffer, SizeOf(Buffer), setfile);
  posX := S2Int(Buffer);
  GetPrivateProfileString('Base', 'posY', nil, Buffer, SizeOf(Buffer), setfile);
  posY := S2Int(Buffer);
  GetPrivateProfileString('Base', 'timeInterval', nil, Buffer, SizeOf(Buffer), setfile);
  timeInterval := S2Int(Buffer);
  GetPrivateProfileString('Base', 'fontColor', nil, Buffer, SizeOf(Buffer), setfile);
  fontColor := S2Int(Buffer);
  GetPrivateProfileString('Base', 'backColor', nil, Buffer, SizeOf(Buffer), setfile);
  backColor := S2Int(Buffer);
  GetPrivateProfileString('Base', 'fontHeight', nil, Buffer, SizeOf(Buffer), setfile);
  fontHeight := S2Int(Buffer);
  GetPrivateProfileString('Base', 'fontWeight', nil, Buffer, SizeOf(Buffer), setfile);
  fontWeight := S2Int(Buffer);
  GetPrivateProfileString('Base', 'fontName', nil, fontName, SizeOf(fontName), setfile);
  GetPrivateProfileString('Base', 'descHeight', nil, Buffer, SizeOf(Buffer), setfile);
  descHeight := S2Int(Buffer);
  GetPrivateProfileString('Base', 'descWeight', nil, Buffer, SizeOf(Buffer), setfile);
  descWeight := S2Int(Buffer);
  GetPrivateProfileString('Base', 'descName', nil, descName, SizeOf(descName), setfile);
  GetPrivateProfileString('Base', 'labelUsage', nil, labelUsage, SizeOf(labelUsage), setfile);
  GetPrivateProfileString('Base', 'labelTotal', nil, labelTotal, SizeOf(labelTotal), setfile);
  GetPrivateProfileString('Base', 'labelAvailable', nil, labelAvailable, SizeOf(labelAvailable), setfile);
  GetPrivateProfileString('Base', 'showIcons', nil, Buffer, SizeOf(Buffer), setfile);
  if Buffer[0] = '1' then showIcons := True;
  GetPrivateProfileString('Base', 'showUserIcons', nil, Buffer, SizeOf(Buffer), setfile);
  if Buffer[0] = '1' then showUserIcons := True;
  GetPrivateProfileString('Base', 'showBars', nil, Buffer, SizeOf(Buffer), setfile);
  if Buffer[0] = '1' then showBars := True;
  GetPrivateProfileString('Base', 'showRounded', nil, Buffer, SizeOf(Buffer), setfile);
  if Buffer[0] = '1' then showRounded := True;
  GetPrivateProfileString('Base', 'showTransparent', nil, Buffer, SizeOf(Buffer), setfile);
  if Buffer[0] = '1' then showTransparent := True;

  GetPrivateProfileString('Base', 'enableCPU', nil, Buffer, SizeOf(Buffer), setfile);
  if Buffer[0] = '1' then
  begin
    enableCPU := True;
    GetPrivateProfileString('Base', 'labelCPU', nil, Buffer, SizeOf(Buffer), setfile);
    L[idx][0] := Buffer;
    L[idx][1] := '165';
    indexCPU := idx;
    Inc(idx);
  end;

  MemoryStatus.dwLength := SizeOf(MemoryStatus);
  GlobalMemoryStatus(MemoryStatus);

  GetPrivateProfileString('Base', 'enableMemory', nil, Buffer, SizeOf(Buffer), setfile);
  if Buffer[0] = '1' then
  begin
    enableMemory := True;
    GetPrivateProfileString('Base', 'usageMemory', nil, Buffer, SizeOf(Buffer), setfile);
    if Buffer[0] = '1' then usageMemory := True;
    GetPrivateProfileString('Base', 'totalMemory', nil, Buffer, SizeOf(Buffer), setfile);
    if Buffer[0] = '1' then totalMemory := True;
    GetPrivateProfileString('Base', 'availableMemory', nil, Buffer, SizeOf(Buffer), setfile);
    if Buffer[0] = '1' then availableMemory := True;
    GetPrivateProfileString('Base', 'labelMemory', nil, Buffer, SizeOf(Buffer), setfile);
    L[idx][0] := Buffer;
    L[idx][1] := '12';
    StrFormatByteSize(MemoryStatus.dwTotalPhys, Buffer, SizeOf(Buffer));
    L[idx,4] := Buffer;
    indexMemory := idx;
    Inc(idx);
  end;

  GetPrivateProfileString('Base', 'enablePagefile', nil, Buffer, SizeOf(Buffer), setfile);
  if Buffer[0] = '1' then
  begin
    enablePagefile := True;
    GetPrivateProfileString('Base', 'usagePagefile', nil, Buffer, SizeOf(Buffer), setfile);
    if Buffer[0] = '1' then usagePagefile := True;
    GetPrivateProfileString('Base', 'totalPagefile', nil, Buffer, SizeOf(Buffer), setfile);
    if Buffer[0] = '1' then totalPagefile := True;
    GetPrivateProfileString('Base', 'availablePagefile', nil, Buffer, SizeOf(Buffer), setfile);
    if Buffer[0] = '1' then availablePagefile := True;
    GetPrivateProfileString('Base', 'labelPagefile', nil, Buffer, SizeOf(Buffer), setfile);
    L[idx][0] := Buffer;
    L[idx][1] := '21';
    StrFormatByteSize(MemoryStatus.dwTotalPageFile, Buffer, SizeOf(Buffer));
    L[idx,4] := Buffer;
    indexPagefile := idx;
    Inc(idx);
  end;

  GetPrivateProfileString('Base', 'enableDisk', nil, Buffer, SizeOf(Buffer), setfile);
  if Buffer[0] = '1' then
  begin
    indexDisk := idx;
    enableDisk := True;
    GetPrivateProfileString('Base', 'usageDisk', nil, Buffer, SizeOf(Buffer), setfile);
    if Buffer[0] = '1' then usageDisk := True;
    GetPrivateProfileString('Base', 'totalDisk', nil, Buffer, SizeOf(Buffer), setfile);
    if Buffer[0] = '1' then totalDisk := True;
    GetPrivateProfileString('Base', 'availablePagefile', nil, Buffer, SizeOf(Buffer), setfile);
    if Buffer[0] = '1' then availableDisk := True;
    GetPrivateProfileString('Base', 'showPart', nil, Buffer, SizeOf(Buffer), setfile);
    lstrcpy(showPart, Buffer);
    for h := 0 to lstrlen(showPart)-1 do
    begin
      L[idx][0] := PChar('(' + showPart[h] + ':) ' + GetLabelDisk(showPart[h]));
      L[idx][1] := '8';
      L[idx][4] := Int64_2Str(DiskTotalSpace(PChar(showPart[h] + ':\')));
      Inc(idx);
    end;
  end;

  GetPrivateProfileString('Base', 'enableTrash', nil, Buffer, SizeOf(Buffer), setfile);
  if Buffer[0] = '1' then
  begin
    enableTrash := True;
    GetPrivateProfileString('Base', 'labelTrash', nil, Buffer, SizeOf(Buffer), setfile);
    L[idx][0] := Buffer;
    L[idx][1] := '143';
    indexTrash := idx;
    Inc(idx);
  end;

  Fheight := idx * 63;
  F := CreateWindow('XPU', '[XP Usage]', WS_POPUP or WS_CLIPCHILDREN, posX, posY, 300, FHeight, 0, 0, hInstance, NIL);

  ShowWindow(F, SW_HIDE);
  SetWindowLong(F, GWL_EXSTYLE, GetWindowLong(F, GWL_EXSTYLE) or WS_EX_TOOLWINDOW);
  ShowWindow(F, SW_SHOW);

  hIco := ExtractIcon(F, 'shell32.dll', 166);
  IconData.cbSize := SizeOf(TNotifyIconData);
  IconData.Wnd := F;
  IconData.uID := 8;
  IconData.uFlags := NIF_ICON or NIF_MESSAGE or NIF_TIP;
  IconData.uCallbackMessage := WM_TRAYICONCLICKED;
  IconData.hIcon := hIco;
  IconData.szTip := 'Double click to close XPU';
  Shell_NotifyIcon(NIM_ADD, @IconData);
  DestroyIcon(hIco);

  BigFont := CreateFont(fontHeight, 0, 0, 0, fontWeight, 0, 0, 0, ANSI_CHARSET, OUT_DEFAULT_PRECIS,
             CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, VARIABLE_PITCH or FF_SWISS, fontName);
  SmallFont := CreateFont(descHeight, 0, 0, 0, descWeight, 0, 0, 0, ANSI_CHARSET, OUT_DEFAULT_PRECIS,
             CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, VARIABLE_PITCH or FF_SWISS, descName);
  cBrush := CreateSolidBrush(fontColor);
  tBrush := CreateSolidBrush(backColor);

  ZeroMemory(@bmi, sizeof(BITMAPINFO));
  bmi.bmiHeader.biSize := Sizeof(BITMAPINFOHEADER);
  bmi.bmiHeader.biWidth := 300;
  bmi.bmiHeader.biHeight := FHeight;
  bmi.bmiHeader.biPlanes := 1;
  bmi.bmiHeader.biBitCount := 24;     // lub 32
  bmi.bmiHeader.biCompression := BI_RGB;
  bmi.bmiHeader.biSizeImage := 0;
  Bmp := NewDIBBitmap(300, FHeight, pf24Bit);

  SetTimer(F, 1, timeInterval, nil);

  while GetMessage(msg, 0, 0, 0) do
  begin
    TranslateMessage(msg);
    DispatchMessage(msg);
  end;
end.