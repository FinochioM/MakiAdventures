
rem TODO, port this over to the new odin build script

@echo off
setlocal

set ODIN_FLAGS=-define:PLATFORM=desktop -extra-linker-flags:"/STACK:536870912"

if "%1"=="dev" (
  echo dev
  set OUT_DIR=build\desktop_debug
) else if "%1"=="release" (
  echo release
  set OUT_DIR=build\desktop_release
  set ODIN_FLAGS=%ODIN_FLAGS% -o:speed -define:RELEASE=true -define:FMOD_LOGGING_ENABLED=false
) else (
  echo arg1 needs dev or release
  goto err
)

if "%1"=="release" (
  rmdir /S /Q %OUT_DIR%
)

if not exist %OUT_DIR% mkdir %OUT_DIR%

if "%2" == "debug" (
  echo debug
  set ODIN_FLAGS=%ODIN_FLAGS% -debug
)

rem https://github.com/floooh/sokol-tools/blob/master/docs/sokol-shdc.md
sokol-shdc -i sauce/shader.glsl -o sauce/shader.odin -l hlsl5 -f sokol_odin

rem pushd terrafactor_cpp
rem call cpp_build.bat
rem popd


@echo on
odin build sauce %ODIN_FLAGS% -out:%OUT_DIR%\terrafactor.exe
@echo off

if "%1"=="release" (
  xcopy res %OUT_DIR%\res /E /I /Y /Q
  copy fmod.dll %OUT_DIR%\fmod.dll /Y
  copy fmodstudio.dll %OUT_DIR%\fmodstudio.dll /Y
  copy libssl-3-x64.dll %OUT_DIR%\libssl-3-x64.dll /Y
  copy libcrypto-3-x64.dll %OUT_DIR%\libcrypto-3-x64.dll /Y
  copy steam_api64.dll %OUT_DIR%\steam_api64.dll /Y
)

goto end

:err
echo ERROR, exiting

:end
echo completed.