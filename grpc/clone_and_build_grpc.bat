

@echo off
setlocal EnableExtensions

:init
:: Internal variables do not change this part
set _script_dir_path=%~dp0
set _script_dir_name=
set _script_full_path=%~0
set _script_file_name=%~nx0
set _script_debug_mode=0

powershell.exe -executionpolicy bypass -file "%_script_dir_path%\CloneBuildGrpc.ps1"

pause