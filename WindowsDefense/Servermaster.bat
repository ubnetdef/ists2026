@echo off
REM Windows Server Defense & Cleanup Tool (Active Directory edition)
REM Requires Administrator privileges; run on Domain Controller or with RSAT/AD module installed

setlocal EnableExtensions EnableDelayedExpansion

REM Track summary info
set "REMOVED_USERS="
set "FAILED_USERS="

REM Check admin
openfiles >nul 2>&1
if errorlevel 1 (
  echo This script requires Administrator privileges.
  exit /b 1
)

echo.
echo ========================================
echo   Windows Server Defense Tool (AD)
echo ========================================
echo.

REM -----------------------------
REM DOMAIN USER ACCOUNT REVIEW/REMOVAL (ONE CONFIRMATION)
REM -----------------------------
echo [INTERACTIVE] Scanning for domain user accounts...
echo.

set "USERLIST="

REM Collect enabled users excluding common built-ins (list first)
for /f "usebackq delims=" %%u in (`
  powershell -NoProfile -Command ^
    "Try { Import-Module ActiveDirectory -ErrorAction Stop } Catch { Exit 0 };" ^
    "$skip=@('Administrator','Guest','krbtgt','DefaultAccount');" ^
    "Get-ADUser -LDAPFilter '(objectCategory=person)' -Properties Enabled |" ^
    "Where-Object { $_.Enabled -eq $true -and ($skip -notcontains $_.SamAccountName) } |" ^
    "Sort-Object Name | Select-Object -ExpandProperty SamAccountName"
`) do (
  echo  - %%u
  set "USERLIST=!USERLIST!|%%u"
)

if not defined USERLIST (
  echo [DONE] No enabled removable domain users found (or AD module unavailable).
  echo.
) else (
  echo.
  set /p "CONFIRM_USERS=Remove ALL domain users listed above? Type YES to continue: "
  if /i not "!CONFIRM_USERS!"=="YES" (
    echo [SKIP] Domain user removal cancelled.
    echo.
  ) else (
    echo [RUN] Removing domain users...
    for %%z in ("!USERLIST:|=" "!") do (
      for %%u in (%%~z) do (
        powershell -NoProfile -Command ^
          "Import-Module ActiveDirectory -ErrorAction Stop; " ^
          "Remove-ADUser -Identity '%%u' -Confirm:$false -ErrorAction Stop" >nul 2>&1
        if !errorlevel! equ 0 (
          echo [DONE] Domain user %%u removed.
          set "REMOVED_USERS=!REMOVED_USERS!;%%u"
        ) else (
          echo [ERROR] Failed to remove domain user %%u.
          set "FAILED_USERS=!FAILED_USERS!;%%u"
        )
      )
    )
    echo.
  )
)

echo.
echo ========================================
echo   Malware Scanning & Removal
echo ========================================
echo.

echo [STEP 1] Cleaning suspicious startup locations...

reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDrive" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDrive" /f >nul 2>&1

for %%f in ("%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\*") do (
  if exist "%%~f" (
    if /i "%%~xf"==".exe" del /f /q "%%~f" >nul 2>&1
    if /i "%%~xf"==".bat" del /f /q "%%~f" >nul 2>&1
    if /i "%%~xf"==".vbs" del /f /q "%%~f" >nul 2>&1
    if /i "%%~xf"==".ps1" del /f /q "%%~f" >nul 2>&1
  )
)
echo [DONE] Startup locations cleaned.

echo.
echo [STEP 2] Cleaning hosts file...
copy "%windir%\System32\drivers\etc\hosts" "%windir%\System32\drivers\etc\hosts.bak" >nul 2>&1
(
  echo # Copyright (c) Microsoft Corp.
  echo # Default HOSTS file.
  echo 127.0.0.1       localhost
  echo ::1             localhost
) > "%windir%\System32\drivers\etc\hosts.tmp"
move /y "%windir%\System32\drivers\etc\hosts.tmp" "%windir%\System32\drivers\etc\hosts" >nul 2>&1
echo [DONE] Hosts file reset.

echo.
echo [STEP 3] Removing common malware directories...
if exist "%ProgramFiles%\PUPs" rmdir /s /q "%ProgramFiles%\PUPs" >nul 2>&1
if exist "%ProgramFiles(x86)%\PUPs" rmdir /s /q "%ProgramFiles(x86)%\PUPs" >nul 2>&1
if exist "%APPDATA%\InstallIQ" rmdir /s /q "%APPDATA%\InstallIQ" >nul 2>&1
if exist "%APPDATA%\Delta" rmdir /s /q "%APPDATA%\Delta" >nul 2>&1
if exist "%APPDATA%\Conduit" rmdir /s /q "%APPDATA%\Conduit" >nul 2>&1
if exist "%LOCALAPPDATA%\Temp\InstallIQ" rmdir /s /q "%LOCALAPPDATA%\Temp\InstallIQ" >nul 2>&1
echo [DONE] Common malware directories removed.

echo.
echo [STEP 4] Cleaning browser hijacking entries...
reg delete "HKLM\SOFTWARE\Microsoft\Internet Explorer\SearchScopes" /v "DefaultScope" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Internet Explorer\SearchScopes" /v "DefaultScope" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\Google\Chrome\Extensions" /f >nul 2>&1
echo [DONE] Browser hijacking cleaned.

echo.
echo [STEP 5] Removing suspicious temp files...
del /f /q "%temp%\*.exe" >nul 2>&1
del /f /q "%temp%\*.scr" >nul 2>&1
del /f /q "%temp%\*.vbs" >nul 2>&1
del /f /q "%temp%\*.js"  >nul 2>&1
del /f /q "%windir%\temp\*.exe" >nul 2>&1
del /f /q "%windir%\temp\*.vbs" >nul 2>&1
del /f /q "%windir%\Prefetch\*.*" >nul 2>&1
echo [DONE] Suspicious temp files removed.

echo.
echo [STEP 6] Disabling WMI event subscriptions (persistence vector)...
powershell -NoProfile -Command ^
  "Get-WmiObject __EventFilter -Namespace root\subscription | Remove-WmiObject -ErrorAction SilentlyContinue; " ^
  "Get-WmiObject __EventConsumer -Namespace root\subscription | Remove-WmiObject -ErrorAction SilentlyContinue" >nul 2>&1
echo [DONE] WMI subscriptions cleared.

echo.
echo [STEP 7] Checking for suspicious scheduled tasks...
powershell -NoProfile -Command ^
  "Get-ScheduledTask | Where-Object { $_.TaskPath -notlike '\Microsoft\*' } | " ^
  "Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue" >nul 2>&1
echo [DONE] Non-system scheduled tasks removed.

echo.
echo [STEP 8] Disabling suspicious services...
sc config RasSstp start= disabled >nul 2>&1
sc config RemoteRegistry start= disabled >nul 2>&1
sc config UmRdpService start= disabled >nul 2>&1
sc config Spooler start= disabled >nul 2>&1
net stop RasSstp >nul 2>&1
net stop RemoteRegistry >nul 2>&1
net stop Spooler >nul 2>&1
echo [DONE] Suspicious services disabled.

echo.
echo [STEP 9] Cleaning browser cache and temp files...
if exist "%APPDATA%\Mozilla\Firefox\Profiles" (
  for /d %%d in ("%APPDATA%\Mozilla\Firefox\Profiles\*") do (
    del /f /q "%%~d\cache2\*.tmp" >nul 2>&1
    del /f /q "%%~d\offlineCache\*.*" >nul 2>&1
  )
)
if exist "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache" (
  rmdir /s /q "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache" >nul 2>&1
)
echo [DONE] Browser cache cleaned.

echo.
echo [STEP 10] Resetting DNS settings...
ipconfig /flushdns >nul 2>&1
netsh int ip set dns name="Ethernet" static 8.8.8.8 >nul 2>&1
netsh int ip add dns name="Ethernet" 8.8.4.4 index=2 >nul 2>&1
echo [DONE] DNS flushed and reset.

echo.
echo ========================================
echo   Complete SSH Removal Tool
echo ========================================
echo.

echo [STEP 11] Stopping SSH services...
net stop sshd >nul 2>&1
net stop ssh-agent >nul 2>&1
taskkill /F /IM ssh.exe >nul 2>&1
taskkill /F /IM sshd.exe >nul 2>&1
echo [DONE] SSH services stopped.

echo.
echo [STEP 12] Disabling SSH services...
sc config sshd start= disabled >nul 2>&1
sc config ssh-agent start= disabled >nul 2>&1
echo [DONE] SSH services disabled.

echo.
echo [STEP 13] Uninstalling OpenSSH feature...
powershell -NoProfile -Command ^
  "Get-WindowsCapability -Online | Where-Object { $_.Name -like '*OpenSSH*' } | " ^
  "Remove-WindowsCapability -Online -ErrorAction SilentlyContinue" >nul 2>&1
echo [DONE] OpenSSH feature uninstalled.

echo.
echo [STEP 14] Removing SSH registry entries...
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\sshd" /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\ssh-agent" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\OpenSSH" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\OpenSSH" /f >nul 2>&1

echo.
echo [STEP 15] Removing SSH directories...
if exist "%ProgramFiles%\OpenSSH" (
  rmdir /s /q "%ProgramFiles%\OpenSSH" >nul 2>&1
)
if exist "%ProgramData%\ssh" (
  rmdir /s /q "%ProgramData%\ssh" >nul 2>&1
)

echo.
echo [STEP 16] Removing SSH user profiles...
for /d %%u in ("%systemdrive%\Users\*") do (
  if exist "%%~u\.ssh" (
    rmdir /s /q "%%~u\.ssh" >nul 2>&1
  )
)

echo.
echo [STEP 17] Clearing SSH from MACHINE PATH...
powershell -NoProfile -Command ^
  "$p=[Environment]::GetEnvironmentVariable('Path','Machine');" ^
  "$p=($p -split ';' | Where-Object { $_ -and ($_ -notmatch 'OpenSSH') }) -join ';';" ^
  "[Environment]::SetEnvironmentVariable('Path',$p,'Machine')" >nul 2>&1
echo [DONE] SSH removed from PATH.

echo.
echo [STEP 18] Removing SSH from Windows Firewall...
netsh advfirewall firewall delete rule name="OpenSSH-Server-In-TCP" >nul 2>&1
netsh advfirewall firewall delete rule name="OpenSSH-Server-In-UDP" >nul 2>&1
echo [DONE] SSH firewall rules removed.

echo.
echo [STEP 19] Cleaning Windows temporary files...
del /f /q "%temp%\*ssh*" >nul 2>&1
del /f /q "%windir%\temp\*ssh*" >nul 2>&1
echo [DONE] Temporary SSH files cleaned.

echo.
echo ========================================
echo   Summary (best-effort)
echo ========================================
if defined REMOVED_USERS (
  echo - Domain users removed: %REMOVED_USERS%
) else (
  echo - Domain users removed: (none)
)
if defined FAILED_USERS echo - Domain users FAILED to remove: %FAILED_USERS%
echo - Startup folder scripts/executables deleted (common extensions)
echo - Hosts file reset + backup: %windir%\System32\drivers\etc\hosts.bak
echo - PUP folders removed if present: PUPs / InstallIQ / Delta / Conduit
echo - Non-Microsoft scheduled tasks removed (Step 7)
echo - Services disabled: RasSstp, RemoteRegistry, UmRdpService, Spooler
echo - OpenSSH feature removal attempted + firewall rules removed
echo ========================================

echo.
echo ========================================
echo   Completed Server Defense Cleanup
echo ========================================
echo.
exit /b 0