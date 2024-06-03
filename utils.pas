unit utils;

interface

uses Windows;

type
  I64 = record Lo, Hi: DWORD;
  end;

type
  TWindowsVersion = ( wv31, wv95, wv98, wvME, wvNT, wvY2K, wvXP, wvServer2003, wvVista );
  TWindowsVersions = Set of TWindowsVersion;

function WinVer : TWindowsVersion;
function AnsiCompareStrNoCase(const S1, S2: String): Integer;
function AnsiCompareText( const S1, S2: AnsiString ): Integer;
function Sgn64( const X: I64 ): Integer;

function MakeInt64(Lo, Hi: DWORD): I64;
function Div64i( const X: I64; D: Integer ): I64;
function Mul64i(const X: I64; Mul: Integer): I64;
function Neg64(const X: I64): I64;

function DiskFreeSpace(const Path: String): I64;
function DiskTotalSpace(const Path: String): I64;
function GetProcessorTimePct: Integer;
function GetLabelDisk(Ch: Char): PAnsiChar;
function GetStartDir: PAnsiChar;
function Int2Str(Value: Integer): AnsiString;
function Int64_2Double(const X: I64): Double;
function Int64_2Str( X: I64 ): AnsiString;
function Str2Int64( const S: AnsiString ): I64;
function S2Int(S: PAnsiChar): Integer;
function StrScan(Str: PAnsiChar; Chr: AnsiChar): PAnsiChar;
function Sub64(const X, Y: I64): I64;

implementation

type
  PPerfDataBlock = ^TPerfDataBlock;
  TPerfDataBlock = record
    Signature: array[0..3] of WCHAR;
    LittleEndian: DWORD;
    Version: DWORD;
    Revision: DWORD;
    TotalByteLength: DWORD;
    HeaderLength: DWORD;
    NumObjectTypes: DWORD;
    DefaultObject: Longint;
    SystemTime: TSystemTime;
    PerfTime: TLargeInteger;
    PerfFreq: TLargeInteger;
    PerfTime100nSec: TLargeInteger;
    SystemNameLength: DWORD;
    SystemNameOffset: DWORD;
  end;

  PPerfObjectType = ^TPerfObjectType;
  TPerfObjectType = record
    TotalByteLength: DWORD;
    DefinitionLength: DWORD;
    HeaderLength: DWORD;
    ObjectNameTitleIndex: DWORD;
    ObjectNameTitle: LPWSTR;
    ObjectHelpTitleIndex: DWORD;
    ObjectHelpTitle: LPWSTR;
    DetailLevel: DWORD;
    NumCounters: DWORD;
    DefaultCounter: Longint;
    NumInstances: Longint;
    CodePage: DWORD;
    PerfTime: TLargeInteger;
    PerfFreq: TLargeInteger;
  end;

  PPerfCounterDefinition = ^TPerfCounterDefinition;
  TPerfCounterDefinition = record
    ByteLength: DWORD;
    CounterNameTitleIndex: DWORD;
    CounterNameTitle: LPWSTR;
    CounterHelpTitleIndex: DWORD;
    CounterHelpTitle: LPWSTR;
    DefaultScale: Longint;
    DetailLevel: DWORD;
    CounterType: DWORD;
    CounterSize: DWORD;
    CounterOffset: DWORD;
  end;

  PPerfInstanceDefinition = ^TPerfInstanceDefinition;
  TPerfInstanceDefinition = record
    ByteLength: DWORD;
    ParentObjectTitleIndex: DWORD;
    ParentObjectInstance: DWORD;
    UniqueID: Longint;
    NameOffset: DWORD;
    NameLength: DWORD;
  end;

  PPerfCounterBlock = ^TPerfCounterBlock;
  TPerfCounterBlock = record
    ByteLength: DWORD;
  end;

var
  SaveWinVer: Byte = $FF;

function AnsiCompareStrNoCase(const S1, S2: String): Integer;
begin
  Result := CompareString(LOCALE_USER_DEFAULT, NORM_IGNORECASE, PChar(S1), -1,
    PChar(S2), -1 ) - 2;
end;


function AnsiCompareText( const S1, S2: AnsiString ): Integer;
begin
  Result := AnsiCompareStrNoCase( S1, S2 );
end;

function WinVer : TWindowsVersion;
var MajorVersion, MinorVersion: Byte;
    dwVersion: Integer;
begin
  if SaveWinVer <> $FF then Result := TWindowsVersion( SaveWinVer )
  else
  begin
    dwVersion := GetVersion;
    MajorVersion := LoByte( dwVersion );
    MinorVersion := HiByte( LoWord( dwVersion ) );
    if dwVersion >= 0 then
    begin
      Result := wvNT;
      if MajorVersion >= 6 then
        Result := wvVista
      else begin
             if MajorVersion >= 5 then
                if MinorVersion >= 1 then
                begin
                     Result := wvXP;
                     if MinorVersion >= 2 then
                       Result := wvServer2003;
                end
                else Result := wvY2K;
           end;
    end
      else
    begin
      Result := wv95;
      if (MajorVersion > 4) or
         (MajorVersion = 4) and (MinorVersion >= 10)  then
      begin
        Result := wv98;
        if (MajorVersion = 4) and (MinorVersion >= $5A) then
          Result := wvME;
      end
        else
      if MajorVersion <= 3 then
        Result := wv31;
    end;
    SaveWinVer := Ord( Result );
  end;
end;

function GetProcessorTimeCounter(var CurValue,
  PerfTime100nSec: TLargeInteger): Boolean;
var
  PerfData: PPerfDataBlock;
  PerfObj: PPerfObjectType;
  PerfInst: PPerfInstanceDefinition;
  PerfCntr, CurCntr: PPerfCounterDefinition;
  PtrToCntr: PPerfCounterBlock;
  BufferSize: Integer;
  i, j, k: Integer;
  s: string;
  pData: PLargeInteger;

  { Navigation helpers }
  function FirstObject(PerfData: PPerfDataBlock): PPerfObjectType;
  begin
    Result := PPerfObjectType(DWORD(PerfData) + PerfData.HeaderLength);
  end;

  function NextObject(PerfObj: PPerfObjectType): PPerfObjectType;
  begin
    Result := PPerfObjectType(DWORD(PerfObj) + PerfObj.TotalByteLength);
  end;

  function FirstInstance(PerfObj: PPerfObjectType): PPerfInstanceDefinition;
  begin
    Result := PPerfInstanceDefinition(DWORD(PerfObj) + PerfObj.DefinitionLength);
  end;

  function NextInstance(PerfInst: PPerfInstanceDefinition): PPerfInstanceDefinition;
  var
    PerfCntrBlk: PPerfCounterBlock;
  begin
    PerfCntrBlk := PPerfCounterBlock(DWORD(PerfInst) + PerfInst.ByteLength);
    Result := PPerfInstanceDefinition(DWORD(PerfCntrBlk) + PerfCntrBlk.ByteLength);
  end;

  function FirstCounter(PerfObj: PPerfObjectType): PPerfCounterDefinition;
  begin
    Result := PPerfCounterDefinition(DWORD(PerfObj) + PerfObj.HeaderLength);
  end;

  function NextCounter(PerfCntr: PPerfCounterDefinition): PPerfCounterDefinition;
  begin
    Result := PPerfCounterDefinition(DWORD(PerfCntr) + PerfCntr.ByteLength);
  end;

begin
  Result := False;

  // Allocate initial buffer for object information
  BufferSize := 65536;
  GetMem(PerfData, BufferSize);

  // retrieve data
  while RegQueryValueEx(HKEY_PERFORMANCE_DATA,
    '238',  // Processor object
    nil, nil, Pointer(PerfData), @BufferSize) = ERROR_MORE_DATA do
  begin
    // buffer is too small
    Inc(BufferSize, 1024);
    ReallocMem(PerfData, BufferSize);
  end;
  RegCloseKey(HKEY_PERFORMANCE_DATA);

  // Get the first object type
  PerfObj := FirstObject(PerfData);

  // Process all objects
  for i := 0 to PerfData.NumObjectTypes-1 do
  begin
    // Check for Processor object
    if PerfObj.ObjectNameTitleIndex = 238 then
    begin
      // Get the first counter
      PerfCntr := FirstCounter(PerfObj);
      if PerfObj.NumInstances > 0  then
      begin
        // Get the first instance
        PerfInst := FirstInstance(PerfObj);
        // Retrieve all instances
        for k := 0 to PerfObj.NumInstances-1 do
        begin
          CurCntr := PerfCntr;
          // Check instance name for "_Total"
          s := WideCharToString(PWideChar(DWORD(PerfInst) +
            PerfInst.NameOffset));
          if (AnsiCompareText(s, '_Total') = 0) then
            // Retrieve all counters
            for j := 0 to PerfObj.NumCounters-1 do
            begin
              PtrToCntr := PPerfCounterBlock(DWORD(PerfInst) + PerfInst.ByteLength);
              // Check for % Process Time counter
              if CurCntr.CounterNameTitleIndex = 6 then
              begin
                pData := Pointer(DWORD(PtrToCntr) + CurCntr.CounterOffset);
                CurValue := pData^;
                PerfTime100nSec := PerfData.PerfTime100nSec;
                Result := True;
              end;
              // Get the next counter
              CurCntr := NextCounter(CurCntr);
            end;
          // Get the next instance.
          PerfInst := NextInstance(PerfInst);
        end;
      end;
    end;
    // Get the next object type
    PerfObj := NextObject(PerfObj);
  end;
  // Release buffer
  FreeMem(PerfData);
end;

var
  LastProcessorTimeCounter: TLargeInteger = 0;
  LastPerfTime100nSec: TLargeInteger = 0;

function GetProcessorTimePct: Integer;
var
  CurValue, PerfTime100nSec: TLargeInteger;
  p: Extended;
begin
  Result := 0;
  if Winver < WvNT then Exit;

  if GetProcessorTimeCounter(CurValue, PerfTime100nSec) then
  begin
    if LastProcessorTimeCounter <> 0 then
    begin
      p := (CurValue - LastProcessorTimeCounter) /
           (PerfTime100nSec - LastPerfTime100nSec);
      Result := Trunc(100 * (1 - p));
    end;
    LastProcessorTimeCounter := CurValue;
    LastPerfTime100nSec := PerfTime100nSec;
  end;
end;

function Sgn64( const X: I64 ): Integer;
asm
  XOR  EDX, EDX
  CMP  [EAX+4], EDX
  XCHG EAX, EDX
  JG   @@ret_1
  JL   @@ret_neg
  CMP  [EDX], EAX
  JZ   @@exit
@@ret_1:
  INC  EAX
  RET
@@ret_neg:
  DEC  EAX
@@exit:
end;

function MakeInt64( Lo, Hi: DWORD ): I64;
begin
  Result.Lo := Lo;
  Result.Hi := Hi;
end;

function Mul64EDX( const X: I64; M: Integer ): I64;
asm
  PUSH  ESI
  PUSH  EDI
  XCHG  ESI, EAX
  MOV   EDI, ECX
  MOV   ECX, EDX
  LODSD
  MUL   ECX
  STOSD
  XCHG  EDX, ECX
  LODSD
  MUL  EDX
  ADD   EAX, ECX
  STOSD
  POP   EDI
  POP   ESI
end;

function Div64EDX( const X: I64; D: Integer ): I64;
asm
  PUSH  ESI
  PUSH  EDI
  XCHG  ESI, EAX
  MOV   EDI, ECX
  MOV   ECX, EDX
  MOV   EAX, [ESI+4]
  CDQ
  DIV  ECX
  MOV   [EDI+4], EAX
  LODSD
  DIV  ECX
  STOSD
  POP   EDI
  POP   ESI
end;

function Div64i( const X: I64; D: Integer ): I64;
var Minus: Boolean;
begin
  Minus := FALSE;
  if D < 0 then
  begin
    D := -D;
    Minus := TRUE;
  end;
  Result := X;
  if Sgn64( Result ) < 0 then
  begin
    Result := Neg64( Result );
    Minus := not Minus;
  end;
  Result := Div64EDX( Result, D );
  if Minus then
    Result := Neg64( Result );
end;

function Neg64( const X: I64 ): I64;
asm
  MOV  ECX, [EAX]
  NEG  ECX
  MOV  [EDX], ECX
  MOV  ECX, 0
  SBB  ECX, [EAX+4]
  MOV  [EDX+4], ECX
end;

function Mul64i( const X: I64; Mul: Integer ): I64;
var Minus: Boolean;
begin
  Minus := FALSE;
  if Mul < 0 then
  begin
    Minus := TRUE;
    Mul := -Mul;
  end;
  Result := Mul64EDX( X, Mul );
  if Minus then
    Result := Neg64( Result );
end;


function DiskFreeSpace(const Path: String): I64;
type TGetDFSEx = function(Path: PChar; CallerFreeBytes, TotalBytes, FreeBytes: Pointer): Bool; stdcall;
var
  GetDFSEx: TGetDFSEx;
  Kern32: THandle;
  V: TOSVersionInfo;
  Ex: Boolean;
  SpC, BpS, NFC, TNC: DWORD;
  FBA, TNB: I64;
begin
  GetDFSEx := nil;
  V.dwOSVersionInfoSize := Sizeof(V);
  GetVersionEx (POSVersionInfo(@V)^); // bug in Windows.pas !
  Ex := False;
  if V.dwPlatformId = VER_PLATFORM_WIN32_NT then
  begin
    Ex := V.dwMajorVersion >= 4;
  end
    else
  if V.dwPlatformId = VER_PLATFORM_WIN32_WINDOWS then
  begin
    Ex := V.dwMajorVersion > 4;
    if not Ex then
    if V.dwMajorVersion = 4 then
    begin
      Ex := V.dwMinorVersion > 0;
      if not Ex then
        Ex := LoWord(V.dwBuildNumber) >= $1111;
    end;
  end;
  if Ex then
  begin
    Kern32 := GetModuleHandle('kernel32');
    GetDFSEx := GetProcAddress(Kern32, 'GetDiskFreeSpaceExA');
  end;
  if Assigned(GetDFSEx) then
    GetDFSEx(PChar(Path), @FBA, @TNB, @Result)
  else
  begin
    GetDiskFreeSpace(PChar(Path), SpC, BpS, NFC, TNC);
    Result := Mul64i(MakeInt64(SpC*BpS, 0), NFC);
  end;
end;

function DiskTotalSpace(const Path: String): I64;
type TGetDFSEx = function(Path: PChar; CallerFreeBytes, TotalBytes, FreeBytes: Pointer): Bool; stdcall;
var
  GetDFSEx: TGetDFSEx;
  Kern32: THandle;
  V: TOSVersionInfo;
  Ex: Boolean;
  SpC, BpS, NFC, TNC: DWORD;
  FBA, TNB: I64;
begin
  GetDFSEx := nil;
  V.dwOSVersionInfoSize := Sizeof(V);
  GetVersionEx (POSVersionInfo(@V)^); // bug in Windows.pas !
  Ex := False;
  if V.dwPlatformId = VER_PLATFORM_WIN32_NT then
  begin
    Ex := V.dwMajorVersion >= 4;
  end
    else
  if V.dwPlatformId = VER_PLATFORM_WIN32_WINDOWS then
  begin
    Ex := V.dwMajorVersion > 4;
    if not Ex then
    if V.dwMajorVersion = 4 then
    begin
      Ex := V.dwMinorVersion > 0;
      if not Ex then
        Ex := LoWord(V.dwBuildNumber) >= $1111;
    end;
  end;
  if Ex then
  begin
    Kern32 := GetModuleHandle('kernel32');
    GetDFSEx := GetProcAddress(Kern32, 'GetDiskFreeSpaceExA');
  end;
  if Assigned(GetDFSEx) then
    GetDFSEx(PChar(Path), @FBA, @Result, @TNB)
  else
  begin
    GetDiskFreeSpace(PChar(Path), SpC, BpS, NFC, TNC);
    Result := Mul64i(MakeInt64(SpC*BpS, 0), TNC);
  end;
end;

function GetLabelDisk(Ch: Char): PAnsiChar;
var
  NotUsed, VolFlags: DWORD;
  Buf: array [0..MAX_PATH] of Char;
begin
  Buf[0] := #$00;
  GetVolumeInformation(PChar(Ch + ':\'), Buf, DWORD(sizeof(Buf)), nil, NotUsed, VolFlags, nil, 0);
  Result := Buf;
end;


function GetStartDir: PAnsiChar;
var
  Buffer: array[0..MAX_PATH] of char;
  i: integer;
begin
  i := GetModuleFileName(0, Buffer, MAX_PATH);
  for i := i downto 0 do
    if Buffer[i] = '\' then
    begin
      Buffer[i+1] := #0;
      break;
    end;
  Result := Buffer;
end;

function Int2Str( Value : Integer ) : AnsiString;
var Buf : Array[ 0..15 ] of AnsiChar;
    Dst : PAnsiChar;
    Minus : Boolean;
    D: DWORD;
begin
  Dst := @Buf[ 15 ];
  Dst^ := #0;
  Minus := False;
  if Value < 0 then
  begin
    Value := -Value;
    Minus := True;
  end;
  D := Value;
  repeat
    Dec( Dst );
    Dst^ := AnsiChar( (D mod 10) + Byte( '0' ) );
    D := D div 10;
  until D = 0;
  if Minus then
  begin
    Dec( Dst );
    Dst^ := '-';
  end;
  Result := Dst;
end;

function Int64_2Double(const X: I64): Double;
asm
  FILD qword ptr [EAX]
  FSTP @Result
end;

procedure IncInt64( var I64: I64; Delta: Integer );
asm
  ADD  [EAX], EDX
  ADC  dword ptr [EAX+4], 0
end;

function Str2Int64( const S: AnsiString ): I64;
var I: Integer;
    M: Boolean;
begin
  Result.Lo := 0;
  Result.Hi := 0;
  I := 1;
  if S = '' then Exit;
  M := FALSE;
  if S[ 1 ] = '-' then
  begin
    M := TRUE;
    Inc( I );
  end
    else
  if S[ 1 ] = '+' then
    Inc( I );
  while I <= Length( S ) do
  begin
    if not( S[ I ] in [ '0'..'9' ] ) then
      break;
    Result := Mul64i( Result, 10 );
    IncInt64( Result, Integer( S[ I ] ) - Integer( '0' ) );
    Inc( I );
  end;
  if M then
    Result := Neg64( Result );
end;

function S2Int(S: PAnsiChar): Integer;
var
  M : Integer;
begin
   Result := 0;
   if S = '' then Exit;
   M := 1;
   if S^ = '-' then
   begin
      M := -1;
      Inc(S);
   end
     else
   if S^ = '+' then Inc(S);
   while S^ in ['0'..'9'] do
   begin
      Result := Result * 10 + Integer(S^) - Integer('0');
      Inc(S);
   end;
   if M < 0 then Result := -Result;
end;

function Mod64i( const X: I64; D: Integer ): Integer;
begin
  Result := Sub64( X, Mul64i( Div64i( X, D ), D ) ).Lo;
end;

function Int64_2Str( X: I64 ): AnsiString;
var M: Boolean;
    Y: Integer;
    Buf: array[ 0..31 ] of AnsiChar;
    I: Integer;
begin
  M := FALSE;
  case Sgn64( X ) of
  -1: begin M := TRUE; X := Neg64( X ); end;
  0:  begin Result := '0'; Exit; end;
  end;
  I := 31;
  Buf[ 31 ] := #0;
  while Sgn64( X ) > 0 do
  begin
    Dec( I );
    Y := Mod64i( X, 10 );
    Buf[ I ] := AnsiChar( Y + Integer( '0' ) );
    X := Div64i( X, 10 );
  end;
  if M then
  begin
    Dec( I );
    Buf[ I ] := '-';
  end;
  Result := PAnsiChar( @Buf[ I ] );
end;

function StrScan(Str: PAnsiChar; Chr: AnsiChar): PAnsiChar; assembler;
asm
        PUSH    EDI
        PUSH    EAX
        MOV     EDI,Str
        OR      ECX, -1
        XOR     AL,AL
        REPNE   SCASB
        NOT     ECX
        POP     EDI
        XCHG    EAX, EDX
        REPNE   SCASB

        XCHG    EAX, EDI
        POP     EDI

        JE      @@1
        XOR     EAX, EAX
        RET

@@1:    DEC     EAX
end;


function Sub64(const X, Y: I64): I64;
asm
  PUSH  ESI
  XCHG  ESI, EAX
  LODSD
  SUB   EAX, [EDX]
  MOV   [ECX], EAX
  LODSD
  SBB   EAX, [EDX+4]
  MOV   [ECX+4], EAX
  POP   ESI
end;

end.


