:: ============================================================================
:: Project       : synthChip
:: Module name   : -
:: File name     : run.bat
:: File type     : Batch script for Windows
:: Purpose       : syntax check, compile and simulation script
:: Author        : QuBi (nitrogenium@outlook.fr)
:: Creation date : August 10th, 2025
:: ----------------------------------------------------------------------------
:: Best viewed with space indentation (2 spaces)
:: ============================================================================

@echo off

:: ============================================================================
:: SETTINGS
:: ============================================================================

:: Color palette for terminal highlighting
set COL_INFO=[1m
set COL_NOTE=[34m
set COL_OK=[92m
set COL_ERR=[91m
set COL_WARN=[93m
set COL_END=[0m

set SRC_DIR=../../src
set WAVE_FILE="tb_sim.wcfg"

for /f "usebackq tokens=1,2 delims==" %%A in ("..\..\xilinx_tools_path.ini") do (
  set %%A=%%B
)

echo %COL_INFO%[INFO] Read Vivado 'bin' path from 'xilinx_tools_path.ini': '%VIVADO_BIN%'%COL_END%

echo CALLING PYTHON
python %SRC_DIR%/blinky/makeBrightnessLut.py"


:: ============================================================================
:: SYNTAX CHECK AND COMPILE
:: ============================================================================
echo.
echo %COL_NOTE%[NOTE] SYNTAX CHECK...%COL_END%
echo.

call :synCheck "blinky_lib" "%SRC_DIR%/blinky/blinky_pkg.vhd"
call :synCheck "blinky_lib" "%SRC_DIR%/blinky/blinky.vhd"

call :synCheck "work" "./tb_blinky.vhd"



:: ============================================================================
:: TESTBENCH ELABORATION
:: ============================================================================
echo.
echo %COL_NOTE%[NOTE] ELABORATION...%COL_END%
echo.

call %VIVADO_BIN%\xelab tb_blinky -L blinky_lib -generic_top "BLINK_FREQ_HZ=10.0" -s tb_sim -debug all



:: ============================================================================
:: RUN SIMULATION
:: ============================================================================
echo.
echo %COL_NOTE%[NOTE] SIMULATION...%COL_END%
echo.

if "%~1"=="nosim" (
  echo.
  echo %COL_INFO%[INFO] 'nosim' option detected: exiting...%COL_END%
  echo.

) else (
  
  if "%~1"=="nogui" (
    echo %COL_INFO%[INFO] GUI is disabled. Running simulation silently...%COL_END%
    %VIVADO_BIN%\xsim tb_sim -runall
    
  ) else (
    echo %COL_INFO%[INFO] GUI is enabled%COL_END%
    
    if exist "%WAVE_FILE%" (
      %VIVADO_BIN%\xsim tb_sim --gui -view "%WAVE_FILE%"
    ) else (
      echo %COL_WARN%[WARNING] Wave file directive not found. Using defaults...%COL_END%
      %VIVADO_BIN%\xsim tb_sim --gui
    )
  )
)

echo Done.
exit /b


:: ============================================================================
:: FUNCTION: Syntax check
:: ============================================================================
:synCheck

:: Read arguments
set "lib=%~1"
set "src=%~2"

:: Call xvhdl
call %VIVADO_BIN%\xvhdl --work %lib% %src%

:: Check the return status
if errorlevel 1 (
  echo %COL_ERR%[FAIL] Syntax check: %src%%COL_END%
) else (
  echo %COL_OK%[PASS] Syntax check: %src%%COL_END%
)
echo.

exit /b



:: ============================================================================
:: FUNCTION: Elaborate
:: ============================================================================
:elaborate

echo TODO

exit /b



