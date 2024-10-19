library drover;

uses
  System.SysUtils,
  Winapi.Windows,
  DDetours,
  PsAPI,
  TlHelp32,
  WinSock,
  WinSock2,
  IniFiles;

type
  TDroverOptions = record
    proxy: string;
    useNekoboxProxy: bool;
    nekoboxProxy: string;
  end;

  TSocketData = record
    s: TSocket;
  end;

  TSocketManager = class
  private
    sockets: array of TSocketData;

    function GetIndex(s: TSocket): integer;
  public
    procedure Add(s: TSocket);
    function Delete(s: TSocket): bool;
  end;

var
  RealGetFileVersionInfoA: function(lptstrFilename: LPSTR; dwHandle, dwLen: DWORD; lpData: Pointer): bool; stdcall;
  RealGetFileVersionInfoW: function(lptstrFilename: LPWSTR; dwHandle, dwLen: DWORD; lpData: Pointer): bool; stdcall;
  RealGetFileVersionInfoSizeA: function(lptstrFilename: LPSTR; var lpdwHandle: DWORD): DWORD; stdcall;
  RealGetFileVersionInfoSizeW: function(lptstrFilename: LPWSTR; var lpdwHandle: DWORD): DWORD; stdcall;
  RealVerFindFileA: function(uFlags: DWORD; szFileName, szWinDir, szAppDir, szCurDir: LPSTR; var lpuCurDirLen: UINT;
    szDestDir: LPSTR; var lpuDestDirLen: UINT): DWORD; stdcall;
  RealVerFindFileW: function(uFlags: DWORD; szFileName, szWinDir, szAppDir, szCurDir: LPWSTR; var lpuCurDirLen: UINT;
    szDestDir: LPWSTR; var lpuDestDirLen: UINT): DWORD; stdcall;
  RealVerInstallFileA: function(uFlags: DWORD; szSrcFileName, szDestFileName, szSrcDir, szDestDir, szCurDir,
    szTmpFile: LPSTR; var lpuTmpFileLen: UINT): DWORD; stdcall;
  RealVerInstallFileW: function(uFlags: DWORD; szSrcFileName, szDestFileName, szSrcDir, szDestDir, szCurDir,
    szTmpFile: LPWSTR; var lpuTmpFileLen: UINT): DWORD; stdcall;
  RealVerLanguageNameA: function(wLang: DWORD; szLang: LPSTR; nSize: DWORD): DWORD; stdcall;
  RealVerLanguageNameW: function(wLang: DWORD; szLang: LPWSTR; nSize: DWORD): DWORD; stdcall;
  RealVerQueryValueA: function(pBlock: Pointer; lpSubBlock: LPSTR; var lplpBuffer: Pointer; var puLen: UINT)
    : bool; stdcall;
  RealVerQueryValueW: function(pBlock: Pointer; lpSubBlock: LPWSTR; var lplpBuffer: Pointer; var puLen: UINT)
    : bool; stdcall;

  RealGetEnvironmentVariableW: function(lpName: LPCWSTR; lpBuffer: LPWSTR; nSize: DWORD): DWORD; stdcall;
  RealCreateProcessW: function(lpApplicationName: LPCWSTR; lpCommandLine: LPWSTR;
    lpProcessAttributes, lpThreadAttributes: PSecurityAttributes; bInheritHandles: bool; dwCreationFlags: DWORD;
    lpEnvironment: Pointer; lpCurrentDirectory: LPCWSTR; const lpStartupInfo: TStartupInfoW;
    var lpProcessInformation: TProcessInformation): bool; stdcall;
  RealGetCommandLineW: function: LPWSTR; stdcall;

  RealSocket: function(af, Struct, protocol: integer): TSocket; stdcall;
  RealWSASendTo: function(s: TSocket; lpBuffers: LPWSABUF; dwBufferCount: DWORD; lpNumberOfBytesSent: LPDWORD;
    dwFlags: DWORD; const lpTo: TSockAddr; iTolen: integer; lpOverlapped: LPWSAOVERLAPPED;
    lpCompletionRoutine: LPWSAOVERLAPPED_COMPLETION_ROUTINE): integer; stdcall;

  socketManager: TSocketManager;
  options: TDroverOptions;
  proxyValue: string;

function TSocketManager.GetIndex(s: TSocket): integer;
var
  i: integer;
begin
  for i := 0 to High(sockets) do
  begin
    if sockets[i].s = s then
    begin
      exit(i);
    end;
  end;
  result := -1;
end;

procedure TSocketManager.Add(s: TSocket);
var
  i: integer;
begin
  i := GetIndex(s);
  if i = -1 then
  begin
    i := Length(sockets);
    SetLength(sockets, i + 1);
  end;
  sockets[i].s := s;
end;

function TSocketManager.Delete(s: TSocket): bool;
var
  targetIndex, lastIndex: integer;
begin
  targetIndex := GetIndex(s);
  if targetIndex = -1 then
    exit(false);
  lastIndex := High(sockets);
  if targetIndex < lastIndex then
    sockets[targetIndex] := sockets[lastIndex];
  SetLength(sockets, lastIndex);
  result := true;
end;

function MyGetFileVersionInfoA(lptstrFilename: LPSTR; dwHandle, dwLen: DWORD; lpData: Pointer): bool; stdcall;
begin
  result := RealGetFileVersionInfoA(lptstrFilename, dwHandle, dwLen, lpData);
end;

function MyGetFileVersionInfoW(lptstrFilename: LPWSTR; dwHandle, dwLen: DWORD; lpData: Pointer): bool; stdcall;
begin
  result := RealGetFileVersionInfoW(lptstrFilename, dwHandle, dwLen, lpData);
end;

function MyGetFileVersionInfoSizeA(lptstrFilename: LPSTR; var lpdwHandle: DWORD): DWORD; stdcall;
begin
  result := RealGetFileVersionInfoSizeA(lptstrFilename, lpdwHandle);
end;

function MyGetFileVersionInfoSizeW(lptstrFilename: LPWSTR; var lpdwHandle: DWORD): DWORD; stdcall;
begin
  result := RealGetFileVersionInfoSizeW(lptstrFilename, lpdwHandle);
end;

function MyVerFindFileA(uFlags: DWORD; szFileName, szWinDir, szAppDir, szCurDir: LPSTR; var lpuCurDirLen: UINT;
  szDestDir: LPSTR; var lpuDestDirLen: UINT): DWORD; stdcall;
begin
  result := RealVerFindFileA(uFlags, szFileName, szWinDir, szAppDir, szCurDir, lpuCurDirLen, szDestDir, lpuDestDirLen);
end;

function MyVerFindFileW(uFlags: DWORD; szFileName, szWinDir, szAppDir, szCurDir: LPWSTR; var lpuCurDirLen: UINT;
  szDestDir: LPWSTR; var lpuDestDirLen: UINT): DWORD; stdcall;
begin
  result := RealVerFindFileW(uFlags, szFileName, szWinDir, szAppDir, szCurDir, lpuCurDirLen, szDestDir, lpuDestDirLen);
end;

function MyVerInstallFileA(uFlags: DWORD; szSrcFileName, szDestFileName, szSrcDir, szDestDir, szCurDir,
  szTmpFile: LPSTR; var lpuTmpFileLen: UINT): DWORD; stdcall;
begin
  result := RealVerInstallFileA(uFlags, szSrcFileName, szDestFileName, szSrcDir, szDestDir, szCurDir, szTmpFile,
    lpuTmpFileLen);
end;

function MyVerInstallFileW(uFlags: DWORD; szSrcFileName, szDestFileName, szSrcDir, szDestDir, szCurDir,
  szTmpFile: LPWSTR; var lpuTmpFileLen: UINT): DWORD; stdcall;
begin
  result := RealVerInstallFileW(uFlags, szSrcFileName, szDestFileName, szSrcDir, szDestDir, szCurDir, szTmpFile,
    lpuTmpFileLen);
end;

function MyVerLanguageNameA(wLang: DWORD; szLang: LPSTR; nSize: DWORD): DWORD; stdcall;
begin
  result := RealVerLanguageNameA(wLang, szLang, nSize);
end;

function MyVerLanguageNameW(wLang: DWORD; szLang: LPWSTR; nSize: DWORD): DWORD; stdcall;
begin
  result := RealVerLanguageNameW(wLang, szLang, nSize);
end;

function MyVerQueryValueA(pBlock: Pointer; lpSubBlock: LPSTR; var lplpBuffer: Pointer; var puLen: UINT): bool; stdcall;
begin
  result := RealVerQueryValueA(pBlock, lpSubBlock, lplpBuffer, puLen);
end;

function MyVerQueryValueW(pBlock: Pointer; lpSubBlock: LPWSTR; var lplpBuffer: Pointer; var puLen: UINT): bool; stdcall;
begin
  result := RealVerQueryValueW(pBlock, lpSubBlock, lplpBuffer, puLen);
end;

function MyGetEnvironmentVariableW(lpName: LPCWSTR; lpBuffer: LPWSTR; nSize: DWORD): DWORD; stdcall;
var
  s: string;
  newValue: string;
begin
  if proxyValue <> '' then
  begin
    s := lpName;
    if (Pos('http_proxy', s) > 0) or (Pos('HTTP_PROXY', s) > 0) or (Pos('https_proxy', s) > 0) or
      (Pos('HTTPS_PROXY', s) > 0) then
    begin
      newValue := proxyValue;
      StringToWideChar(newValue, lpBuffer, nSize);
      result := Length(newValue);
      exit;
    end;
  end;

  result := RealGetEnvironmentVariableW(lpName, lpBuffer, nSize);
end;

function MyCreateProcessW(lpApplicationName: LPCWSTR; lpCommandLine: LPWSTR;
  lpProcessAttributes, lpThreadAttributes: PSecurityAttributes; bInheritHandles: bool; dwCreationFlags: DWORD;
  lpEnvironment: Pointer; lpCurrentDirectory: LPCWSTR; const lpStartupInfo: TStartupInfoW;
  var lpProcessInformation: TProcessInformation): bool; stdcall;
begin
  result := RealCreateProcessW(lpApplicationName, lpCommandLine, lpProcessAttributes, lpThreadAttributes,
    bInheritHandles, dwCreationFlags, lpEnvironment, lpCurrentDirectory, lpStartupInfo, lpProcessInformation);
end;

function MyGetCommandLineW: LPWSTR; stdcall;
var
  s: string;
begin
  s := RealGetCommandLineW;
  if proxyValue <> '' then
  begin
    if Pos('Discord.exe', ParamStr(0)) > 0 then
      s := s + ' --proxy-server=' + proxyValue;
  end;
  result := PChar(s);
end;

function MySocket(af, Struct, protocol: integer): TSocket; stdcall;
var
  socket: TSocket;
begin
  socket := RealSocket(af, Struct, protocol);
  if Struct = SOCK_DGRAM then
  begin
    socketManager.Add(socket);
  end;
  result := socket;
end;

function MyWSASendTo(s: TSocket; lpBuffers: LPWSABUF; dwBufferCount: DWORD; lpNumberOfBytesSent: LPDWORD;
  dwFlags: DWORD; const lpTo: TSockAddr; iTolen: integer; lpOverlapped: LPWSAOVERLAPPED;
  lpCompletionRoutine: LPWSAOVERLAPPED_COMPLETION_ROUTINE): integer; stdcall;
var
  zeroByte: Byte;
begin
  if socketManager.Delete(s) and (lpBuffers.len = 74) then
  begin
    zeroByte := 0;
    sendto(s, Pointer(@zeroByte)^, 1, 0, @lpTo, iTolen);
  end;

  result := RealWSASendTo(s, lpBuffers, dwBufferCount, lpNumberOfBytesSent, dwFlags, lpTo, iTolen, lpOverlapped,
    lpCompletionRoutine);
end;

function GetSystemFolder: string;
var
  s: string;
begin
  SetLength(s, MAX_PATH);
  GetSystemDirectory(PChar(s), MAX_PATH);
  result := IncludeTrailingBackSlash(PChar(s));
end;

procedure LoadOriginalVersionDll;
var
  hOriginal: THandle;
begin
  hOriginal := LoadLibrary(PChar(GetSystemFolder() + 'version.dll'));
  if hOriginal = 0 then
    raise Exception.Create('Error.');

  @RealGetFileVersionInfoA := GetProcAddress(hOriginal, 'GetFileVersionInfoA');
  @RealGetFileVersionInfoW := GetProcAddress(hOriginal, 'GetFileVersionInfoW');
  @RealGetFileVersionInfoSizeA := GetProcAddress(hOriginal, 'GetFileVersionInfoSizeA');
  @RealGetFileVersionInfoSizeW := GetProcAddress(hOriginal, 'GetFileVersionInfoSizeW');
  @RealVerFindFileA := GetProcAddress(hOriginal, 'VerFindFileA');
  @RealVerFindFileW := GetProcAddress(hOriginal, 'VerFindFileW');
  @RealVerInstallFileA := GetProcAddress(hOriginal, 'VerInstallFileA');
  @RealVerInstallFileW := GetProcAddress(hOriginal, 'VerInstallFileW');
  @RealVerLanguageNameA := GetProcAddress(hOriginal, 'VerLanguageNameA');
  @RealVerLanguageNameW := GetProcAddress(hOriginal, 'VerLanguageNameW');
  @RealVerQueryValueA := GetProcAddress(hOriginal, 'VerQueryValueA');
  @RealVerQueryValueW := GetProcAddress(hOriginal, 'VerQueryValueW');
end;

function IsNekoBoxExists: bool;
var
  hSnapshot: THandle;
  pe32: TProcessEntry32;
  processName: string;
begin
  result := false;
  hSnapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if hSnapshot = INVALID_HANDLE_VALUE then
    exit;
  try
    pe32.dwSize := SizeOf(TProcessEntry32);

    if Process32First(hSnapshot, pe32) then
    begin
      repeat
        processName := LowerCase(StrPas(pe32.szExeFile));
        if (Pos('nekobox', processName) > 0) or (Pos('nekoray', processName) > 0) then
        begin
          result := true;
          exit;
        end;

      until not Process32Next(hSnapshot, pe32);
    end;
  finally
    CloseHandle(hSnapshot);
  end;
end;

function LoadOptions: TDroverOptions;
var
  f: TIniFile;
  filename: string;
begin
  try
    filename := ExtractFilePath(ParamStr(0)) + 'drover.ini';

    f := TIniFile.Create(filename);
    try
      with f do
      begin
        result.proxy := ReadString('drover', 'proxy', '');
        result.useNekoboxProxy := ReadBool('drover', 'use-nekobox-proxy', false);
        result.nekoboxProxy := ReadString('drover', 'nekobox-proxy', '127.0.0.1:2080');
      end;
    finally
      f.Free;
    end;
  except
  end;
end;

exports
  MyGetFileVersionInfoA name 'GetFileVersionInfoA',
  MyGetFileVersionInfoW name 'GetFileVersionInfoW',
  MyGetFileVersionInfoSizeA name 'GetFileVersionInfoSizeA',
  MyGetFileVersionInfoSizeW name 'GetFileVersionInfoSizeW',
  MyVerFindFileA name 'VerFindFileA',
  MyVerFindFileW name 'VerFindFileW',
  MyVerInstallFileA name 'VerInstallFileA',
  MyVerInstallFileW name 'VerInstallFileW',
  MyVerLanguageNameA name 'VerLanguageNameA',
  MyVerLanguageNameW name 'VerLanguageNameW',
  MyVerQueryValueA name 'VerQueryValueA',
  MyVerQueryValueW name 'VerQueryValueW';

begin
  socketManager := TSocketManager.Create;

  options := LoadOptions;

  if options.useNekoboxProxy and IsNekoBoxExists then
    proxyValue := options.nekoboxProxy
  else
    proxyValue := options.proxy;

  LoadOriginalVersionDll;

  RealGetEnvironmentVariableW := InterceptCreate(@GetEnvironmentVariableW, @MyGetEnvironmentVariableW, nil);
  RealCreateProcessW := InterceptCreate(@CreateProcessW, @MyCreateProcessW, nil);
  RealGetCommandLineW := InterceptCreate(@GetCommandLineW, @MyGetCommandLineW, nil);

  RealSocket := InterceptCreate(@socket, @MySocket, nil);
  RealWSASendTo := InterceptCreate(@WSASendTo, @MyWSASendTo, nil);

end.
