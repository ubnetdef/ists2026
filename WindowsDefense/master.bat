@echo off
REM Windows Defense & Cleanup Tool
REM Complete system hardening and removal of unwanted software
REM Requires Administrator privileges

setlocal enabledelayedexpansion

REM Check if running as administrator
openfiles >nul 2>&1
if errorlevel 1 (
    echo This script requires Administrator privileges.
    exit /b 1
)

echo.
echo ========================================
echo   Windows Defense Tool
echo ========================================
echo.

echo [INTERACTIVE] Scanning for user accounts...
echo.
setlocal enabledelayedexpansion

REM Get all users sorted A-Z using PowerShell
for /f "delims=" %%u in ('powershell -NoProfile -Command "Get-LocalUser | Where-Object {$_.Name -notlike '*$'} | Sort-Object Name | Select-Object -ExpandProperty Name" 2^>nul') do (
    set /p removeconfirm="Remove user '%%u'? (YES/NO): "
    if /i "!removeconfirm!"=="YES" (
        net user "%%u" /delete >nul 2>&1
        if !errorlevel! equ 0 (
            echo [DONE] User %%u removed.
            if exist "C:\Users\%%u" (
                rmdir /s /q "C:\Users\%%u" >nul 2>&1
                echo [DONE] Profile deleted.
            )
        ) else (
            echo [ERROR] Failed to remove user %%u.
        )
    ) else (
        echo Skipped %%u.
    )
    echo.
)

echo.
echo ========================================
echo   Malware Scanning & Removal
echo ========================================
echo.

echo [STEP 1] Cleaning suspicious startup locations...
REM Remove suspicious Run registry entries
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDrive" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDrive" /f >nul 2>&1
REM Check and clean StartUp folder
for %%f in (%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\*) do (
    if exist "%%f" (
        if /i "%%~xf" EQU ".exe" (
            del /f /q "%%f" >nul 2>&1
        )
        if /i "%%~xf" EQU ".bat" (
            del /f /q "%%f" >nul 2>&1
        )
        if /i "%%~xf" EQU ".vbs" (
            del /f /q "%%f" >nul 2>&1
        )
        if /i "%%~xf" EQU ".ps1" (
            del /f /q "%%f" >nul 2>&1
        )
    )
)
echo [DONE] Startup locations cleaned.

echo.
echo [STEP 2] Cleaning hosts file...
REM Backup original hosts file
copy %windir%\System32\drivers\etc\hosts %windir%\System32\drivers\etc\hosts.bak >nul 2>&1
REM Reset hosts file to default
(
    echo # Copyright (c) 1993-2009 Microsoft Corp.
    echo # This is a sample HOSTS file used by Microsoft TCP/IP for Windows.
    echo 127.0.0.1       localhost
    echo ::1             localhost
) > %windir%\System32\drivers\etc\hosts.tmp
move /y %windir%\System32\drivers\etc\hosts.tmp %windir%\System32\drivers\etc\hosts >nul 2>&1
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
REM Remove common browser hijacker registry entries
reg delete "HKLM\SOFTWARE\Microsoft\Internet Explorer\SearchScopes" /v "DefaultScope" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Internet Explorer\SearchScopes" /v "DefaultScope" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\Google\Chrome\Extensions" /f >nul 2>&1
REM Clean common Chrome extensions
for /f %%k in ('reg query "HKCU\SOFTWARE\Google\Chrome\Extensions" /s ^| findstr /i "DisplayName"') do (
    reg delete "%%k" /f >nul 2>&1
)
echo [DONE] Browser hijacking cleaned.

echo.
echo [STEP 5] Removing suspicious temp files...
del /f /q "%temp%\*.exe" >nul 2>&1
del /f /q "%temp%\*.scr" >nul 2>&1
del /f /q "%temp%\*.vbs" >nul 2>&1
del /f /q "%temp%\*.js" >nul 2>&1
del /f /q "%windir%\temp\*.exe" >nul 2>&1
del /f /q "%windir%\temp\*.vbs" >nul 2>&1
del /f /q "%windir%\Prefetch\*.*" >nul 2>&1
echo [DONE] Suspicious temp files removed.

echo.
echo [STEP 6] Disabling WMI event subscriptions (persistence vector)...
powershell -NoProfile -Command "Get-WmiObject __EventFilter -Namespace root\subscription | Remove-WmiObject 2>$null; Get-WmiObject __EventConsumer -Namespace root\subscription | Remove-WmiObject 2>$null" >nul 2>&1
echo [DONE] WMI subscriptions cleared.

echo.
echo [STEP 7] Checking for suspicious scheduled tasks...
powershell -NoProfile -Command "Get-ScheduledTask | Where-Object {$_.TaskPath -notlike '\Microsoft\*'} | Unregister-ScheduledTask -Confirm:$false 2>$null" >nul 2>&1
echo [DONE] Non-system scheduled tasks removed.

echo.
echo [STEP 8] Disabling suspicious services...
REM Common malware services
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
        del /f /q "%%d\cache2\*.tmp" >nul 2>&1
        del /f /q "%%d\offlineCache\*.*" >nul 2>&1
    )
)
if exist "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache" (
    rmdir /s /q "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache" >nul 2>&1
)
echo [DONE] Browser cache cleaned.

echo.
echo [STEP 10] Resetting DNS settings...
ipconfig /flushdns >nul 2>&1
netsh int ip set dns "Ethernet" static 8.8.8.8 >nul 2>&1
netsh int ip add dns "Ethernet" 8.8.4.4 index=2 >nul 2>&1
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
powershell -NoProfile -Command "Get-WindowsCapability -Online | Where-Object {$_.Name -like '*OpenSSH*'} | Remove-WindowsCapability -Online" 2>nul
echo [DONE] OpenSSH feature uninstalled.

echo.
echo [STEP 14] Removing SSH registry entries...
REM Remove SSH from HKLM
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\sshd" /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\ssh-agent" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\OpenSSH" /f >nul 2>&1

REM Remove SSH from HKCU (current user)
reg delete "HKCU\SOFTWARE\OpenSSH" /f >nul 2>&1
echo [DONE] SSH registry entries removed.

echo.
echo [STEP 15] Removing SSH directories...
REM Remove OpenSSH installation directory
if exist "%ProgramFiles%\OpenSSH" (
    rmdir /s /q "%ProgramFiles%\OpenSSH"
    echo [DONE] Removed: %%ProgramFiles%%\OpenSSH
)

REM Remove SSH configuration
if exist "%ProgramData%\ssh" (
    rmdir /s /q "%ProgramData%\ssh"
    echo [DONE] Removed: %%ProgramData%%\ssh
)

echo.
echo [STEP 16] Removing SSH user profiles...
REM Remove .ssh directories from user profiles
for /d %%u in (%systemdrive%\Users\*) do (
    if exist "%%u\.ssh" (
        rmdir /s /q "%%u\.ssh"
        echo [DONE] Removed: %%u\.ssh
    )
)

echo.
echo [STEP 17] Clearing SSH environment variables...
setx PATH "%PATH:C:\Program Files\OpenSSH=%%" /M >nul 2>&1
for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH ^| findstr /i path') do set "systempath=%%b"
echo [DONE] SSH removed from PATH.

echo.
echo [STEP 18] Removing SSH from Windows Firewall...
netsh advfirewall firewall delete rule name="OpenSSH-Server-In-TCP" >nul 2>&1
netsh advfirewall firewall delete rule name="OpenSSH-Server-In-UDP" >nul 2>&1
echo [DONE] SSH firewall rules removed.

echo.
echo [STEP 19] Cleaning Windows temporary files...
del /f /q %temp%\*ssh* >nul 2>&1
del /f /q %windir%\temp\*ssh* >nul 2>&1
echo [DONE] Temporary SSH files cleaned.

echo.
echo ========================================
echo   SSH Removal Complete
echo ========================================
echo.
echo All traces of SSH have been removed from this system.
echo If you had SSH installed via third-party tools, you may need to
echo uninstall them separately using Control Panel > Programs.
echo.

echo.
echo [STEP 20] Removing Desktop Goose...
taskkill /F /IM goose.exe >nul 2>&1
taskkill /F /IM DesktopGoose.exe >nul 2>&1
if exist "%ProgramFiles%\DesktopGoose" rmdir /s /q "%ProgramFiles%\DesktopGoose" >nul 2>&1
if exist "%ProgramFiles(x86)%\DesktopGoose" rmdir /s /q "%ProgramFiles(x86)%\DesktopGoose" >nul 2>&1
if exist "%APPDATA%\DesktopGoose" rmdir /s /q "%APPDATA%\DesktopGoose" >nul 2>&1
if exist "%LOCALAPPDATA%\DesktopGoose" rmdir /s /q "%LOCALAPPDATA%\DesktopGoose" >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "DesktopGoose" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "DesktopGoose" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\DesktopGoose" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\DesktopGoose" /f >nul 2>&1
echo [DONE] Desktop Goose removed.

echo.
echo [STEP 21] Removing Tactical RMM...
taskkill /F /IM tacticalrmm.exe >nul 2>&1
taskkill /F /IM agent.exe >nul 2>&1
taskkill /F /IM mesh.exe >nul 2>&1
sc stop tacticalrmm >nul 2>&1
sc delete tacticalrmm >nul 2>&1
sc stop trmm-agent >nul 2>&1
sc delete trmm-agent >nul 2>&1
if exist "%ProgramFiles%\TacticalRMM" rmdir /s /q "%ProgramFiles%\TacticalRMM" >nul 2>&1
if exist "%ProgramFiles(x86)%\TacticalRMM" rmdir /s /q "%ProgramFiles(x86)%\TacticalRMM" >nul 2>&1
if exist "C:\Program Files\TacticalRMM" rmdir /s /q "C:\Program Files\TacticalRMM" >nul 2>&1
if exist "%APPDATA%\TacticalRMM" rmdir /s /q "%APPDATA%\TacticalRMM" >nul 2>&1
if exist "%ProgramData%\TacticalRMM" rmdir /s /q "%ProgramData%\TacticalRMM" >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "TacticalRMM" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v "TacticalRMM" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "TacticalRMM" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v "TacticalRMM" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\TacticalRMM" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\TacticalRMM" /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\TacticalRMM" /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\trmm-agent" /f >nul 2>&1
echo [DONE] Tactical RMM removed.

echo.
echo [STEP 22] Removing MeshCentral...
taskkill /F /IM meshcentral.exe >nul 2>&1
taskkill /F /IM meshagent.exe >nul 2>&1
taskkill /F /IM meshcmd.exe >nul 2>&1
sc stop MeshAgent >nul 2>&1
sc delete MeshAgent >nul 2>&1
sc stop meshcentralagent >nul 2>&1
sc delete meshcentralagent >nul 2>&1
if exist "%ProgramFiles%\MeshCentral" rmdir /s /q "%ProgramFiles%\MeshCentral" >nul 2>&1
if exist "%ProgramFiles(x86)%\MeshCentral" rmdir /s /q "%ProgramFiles(x86)%\MeshCentral" >nul 2>&1
if exist "%ProgramFiles%\Mesh Agent" rmdir /s /q "%ProgramFiles%\Mesh Agent" >nul 2>&1
if exist "%ProgramFiles(x86)%\Mesh Agent" rmdir /s /q "%ProgramFiles(x86)%\Mesh Agent" >nul 2>&1
if exist "%APPDATA%\MeshCentral" rmdir /s /q "%APPDATA%\MeshCentral" >nul 2>&1
if exist "%APPDATA%\Mesh Agent" rmdir /s /q "%APPDATA%\Mesh Agent" >nul 2>&1
if exist "%ProgramData%\MeshCentral" rmdir /s /q "%ProgramData%\MeshCentral" >nul 2>&1
if exist "%ProgramData%\MeshAgent" rmdir /s /q "%ProgramData%\MeshAgent" >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "MeshCentral" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "MeshAgent" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v "MeshCentral" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "MeshCentral" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "MeshAgent" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v "MeshCentral" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\MeshCentral" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Intel\MeshAgent" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\MeshCentral" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\MeshAgent" /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\MeshAgent" /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\meshcentralagent" /f >nul 2>&1
echo [DONE] MeshCentral removed.

echo.
echo [STEP 23] Nuking all startup tasks...
powershell -NoProfile -Command "Get-ScheduledTask | Where-Object {$_.TaskName -match 'Goose|TacticalRMM|RMM|MeshCentral|MeshAgent|trmm|mesh' -and $_.TaskPath -like '\Microsoft\*'} | Disable-ScheduledTask -Confirm:$false 2>$null; Get-ScheduledTask | Where-Object {$_.TaskName -match 'Goose|TacticalRMM|RMM|MeshCentral|MeshAgent|trmm|mesh' -and $_.TaskPath -notlike '\Microsoft\*'} | Unregister-ScheduledTask -Confirm:$false 2>$null" >nul 2>&1
echo [DONE] Startup tasks removed.

echo.
echo [STEP 24] Disabling unnecessary Windows services...
REM Disable telemetry and bloatware services
sc config DiagTrack start= disabled >nul 2>&1
sc config dmwappushservice start= disabled >nul 2>&1
sc config MapsBroker start= disabled >nul 2>&1
sc config lfsvc start= disabled >nul 2>&1
sc config SharedAccess start= disabled >nul 2>&1
sc config WMPNetworkSvc start= disabled >nul 2>&1
sc config RemoteRegistry start= disabled >nul 2>&1
sc config TabletInputService start= disabled >nul 2>&1
sc config RetailDemo start= disabled >nul 2>&1
sc config AJRouter start= disabled >nul 2>&1
sc config BDESVC start= disabled >nul 2>&1
sc config WerSvc start= disabled >nul 2>&1
sc config CloudSignInService start= disabled >nul 2>&1
sc config TriageScheduler start= disabled >nul 2>&1
sc config dmwappushservice start= disabled >nul 2>&1
net stop DiagTrack >nul 2>&1
net stop dmwappushservice >nul 2>&1
net stop MapsBroker >nul 2>&1
net stop lfsvc >nul 2>&1
net stop RemoteRegistry >nul 2>&1
echo [DONE] Unnecessary services disabled.

echo.
echo [STEP 25] Installing and launching Autoruns...
powershell -NoProfile -Command "$ProgressPreference = 'SilentlyContinue'; $url = 'https://download.sysinternals.com/files/Autoruns.zip'; $destination = '$env:TEMP\Autoruns.zip'; $extractPath = '$env:ProgramFiles\Autoruns'; if (-not (Test-Path $extractPath)) { Invoke-WebRequest -Uri $url -OutFile $destination -ErrorAction SilentlyContinue; Expand-Archive -Path $destination -DestinationPath $extractPath -Force; Remove-Item $destination -Force -ErrorAction SilentlyContinue }; Start-Process '$extractPath\autoruns.exe'" 2>nul
echo [DONE] Autoruns launched.

echo.
exit /b 0
