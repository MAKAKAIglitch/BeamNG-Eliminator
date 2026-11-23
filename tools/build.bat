@echo off
setlocal
cd /d "%~dp0.."

where python >nul 2>nul
if errorlevel 1 (
  echo ERROR: Python 3 is required to run the project checks.
  exit /b 1
)

python -m unittest discover -s tests -v
if errorlevel 1 exit /b 1

if exist dist rmdir /s /q dist
mkdir "dist\Resources\Server\Eliminator"
xcopy "server-plugin\*" "dist\Resources\Server\Eliminator\" /E /I /Q /Y >nul
if errorlevel 1 exit /b 1

powershell -NoProfile -ExecutionPolicy Bypass -Command "Compress-Archive -Path 'client-mod\*' -DestinationPath 'dist\Eliminator-client.zip' -Force"
if errorlevel 1 exit /b 1

echo.
echo Build completed:
echo   dist\Resources\Server\Eliminator
echo   dist\Eliminator-client.zip
endlocal
