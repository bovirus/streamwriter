@ECHO OFF

if "%FPCBIN%" == "" (
  call SetEnvironment.bat
  if %ERRORLEVEL% GEQ 1 exit /B %ERRORLEVEL%
)

SET "SCRIPTSDIR=%~dp0"
SET "APPNAME=streamwriter"
SET "PROJECTDIR=%SCRIPTSDIR%\.."
SET "SOURCEDIR=%PROJECTDIR%\Source"
SET "OUTDIR=%PROJECTDIR%\Build"
SET "PUBLISHDIR=%PROJECTDIR%\Build\Publish"
SET "ZIPFILES=%APPNAME%.exe"
SET "UPLOADURL=https://streamwriter.org/de/downloads/svnbuild/?download=67&filename=%APPNAME%"

call :main
echo(
if %ERRORLEVEL% EQU 0 (
  echo Ok
) else (
  echo Error
  pause
)
echo(
goto end

:getgitsha
  cd "%PROJECTDIR%"
  for /f "tokens=1" %%r in ('git rev-parse --short HEAD') do set GITSHA=%%r
  exit /b 0

:build
  cd "%SOURCEDIR%"

  instantfpc "%SCRIPTSDIR%\SetGitVersion.pas" streamwriter.lpi streamwriter_gitsha.lpi
  if %ERRORLEVEL% GEQ 1 exit /B %ERRORLEVEL%

  REM Build executables
  lazbuild --build-all --cpu=i386 --os=Win32 --build-mode=Release streamwriter_gitsha.lpi
  if %ERRORLEVEL% GEQ 1 exit /B %ERRORLEVEL%
  
  del streamwriter_gitsha.lpi
  if %ERRORLEVEL% GEQ 1 exit /B %ERRORLEVEL%

  REM Build addons
  for /R "..\Addons" %%f in (*.lpi) do (
    cd "%%~dpf"

    lazbuild --build-all --cpu=i386 --os=Win32 --build-mode=Release "%%~nxf"
    if %ERRORLEVEL% GEQ 1 exit /B %ERRORLEVEL%
  )
  
  exit /b 0

:zip
  cd "%OUTDIR%"

  "%ZIP%" a -mx9 %APPNAME%.zip %ZIPFILES%
  if %ERRORLEVEL% GEQ 1 exit /B %ERRORLEVEL%

  exit /b 0

:setup
  cd "%PROJECTDIR%\Setup"

  "%INNO%" /O"%OUTDIR%" %APPNAME%.iss
  if %ERRORLEVEL% GEQ 1 exit /B %ERRORLEVEL%

  exit /b 0

:copyfiles
  if not exist "%PUBLISHDIR%" mkdir "%PUBLISHDIR%"

  copy /Y "%OUTDIR%\%APPNAME%.zip" "%PUBLISHDIR%\%APPNAME%.zip"
  if %ERRORLEVEL% GEQ 1 exit /B %ERRORLEVEL%

  copy /Y "%OUTDIR%\%APPNAME%_setup.exe" "%PUBLISHDIR%\%APPNAME%_setup.exe"
  if %ERRORLEVEL% GEQ 1 exit /B %ERRORLEVEL%

  exit /b 0

:upload
  cd "%PUBLISHDIR%"

  "%CURL%" -k -f -S -o nul -F "file=@%APPNAME%.zip" "%UPLOADURL%&gitsha=%GITSHA%"
  if %ERRORLEVEL% GEQ 1 exit /B 1

  exit /b 0

:main
  call :getgitsha
  if %ERRORLEVEL% GEQ 1 exit /b %ERRORLEVEL%

  call :build
  if %ERRORLEVEL% GEQ 1 exit /b %ERRORLEVEL%

  call :zip
  if %ERRORLEVEL% GEQ 1 exit /b %ERRORLEVEL%

  call :setup
  if %ERRORLEVEL% GEQ 1 exit /b %ERRORLEVEL%

  call :copyfiles
  if %ERRORLEVEL% GEQ 1 exit /b %ERRORLEVEL%

  call :upload
  if %ERRORLEVEL% GEQ 1 exit /b %ERRORLEVEL%

  exit /b 0

:end
  cd "%SCRIPTSDIR%"
