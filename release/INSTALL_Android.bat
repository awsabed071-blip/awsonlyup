@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo.
echo  TALAA 2.0 for Android - joining the 5 parts...
if not exist Talaa-apk.part1 goto missing
if not exist Talaa-apk.part2 goto missing
if not exist Talaa-apk.part3 goto missing
if not exist Talaa-apk.part4 goto missing
if not exist Talaa-apk.part5 goto missing
copy /b Talaa-apk.part1 + Talaa-apk.part2 + Talaa-apk.part3 + Talaa-apk.part4 + Talaa-apk.part5 Talaa.apk >nul
certutil -hashfile Talaa.apk SHA256 | findstr /i "1c919c1e4486b8bc5bcc9fb9badb4d1635f8e91640b02527e8b645b20d8a5719" >nul
if errorlevel 1 goto badhash
echo.
echo  Done! Talaa.apk is ready (check OK).
echo.
echo  Send Talaa.apk to your phone (USB cable, WhatsApp to yourself, Google Drive...)
echo  and tap it to install.
echo.
echo  IMPORTANT: if TAL'A 1.5 is still installed, uninstall it first. Version 2.0 is
echo  signed with a new key, so Android will refuse to install it over the old one.
echo  (2.0 is a new story with a new save, nothing from 1.5 carries over.)
echo.
echo  If Android asks, allow "Install unknown apps" for the app you opened it from.
echo.
explorer /select,"%~dp0Talaa.apk"
pause
exit /b
:badhash
echo.
echo  The joined file is damaged - one of the parts did not download completely.
echo  Download the parts again and run this file again.
del Talaa.apk >nul 2>nul
pause
exit /b
:missing
echo.
echo  Put all 5 Talaa-apk.part files in the same folder as this file.
pause
