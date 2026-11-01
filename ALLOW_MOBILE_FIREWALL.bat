@echo off
:: Self-elevation script for Grand Aqua Mobile Access
set "params=%*"
cd /d "%~dp0" && ( if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs" ) && fsutil dirty query %systemdrive% 1>nul 2>nul || (  echo Set UAC = CreateObject^("Shell.Application"^) : UAC.ShellExecute "cmd.exe", "/k cd ""%~sdp0"" && ""%~s0"" %params%", "", "runas", 1 >> "%temp%\getadmin.vbs" && "%temp%\getadmin.vbs" && exit /B )

echo ========================================================
echo   GRAND AQUA - MOBILE ACCESS FIREWALL UNLOCKER
echo ========================================================
echo.
echo Allowing inbound connections to Node.js and Port 4000...
echo.

netsh advfirewall firewall set rule name="Node.js JavaScript Runtime" profile=private new action=allow
netsh advfirewall firewall set rule name="Node.js JavaScript Runtime" profile=public new action=allow
netsh advfirewall firewall delete rule name="Grand Aqua Backend 4000" >nul 2>&1
netsh advfirewall firewall add rule name="Grand Aqua Backend 4000" dir=in action=allow protocol=TCP localport=4000 profile=any

echo.
echo ========================================================
echo   [SUCCESS] Port 4000 is now open to your mobile phone!
echo   Mobile URL: http://192.168.29.44:4000/api/v1
echo ========================================================
echo.
pause
