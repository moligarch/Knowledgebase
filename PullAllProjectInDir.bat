@echo off
setlocal EnableExtensions

:init
:: Internal variables do not change this part
set _script_dir_path=%~dp0
set _script_dir_name=
set _script_full_path=%~0
set _script_file_name=%~nx0
set _script_debug_mode=0

powershell.exe "Get-ChildItem -Recurse -Directory -Path .\projects\ | ForEach-Object { if ((Test-Path -Path (Join-Path -Path $_.FullName -ChildPath .git))) { Push-Location $_.FullName; Write-Host `"Updating $_.FullName`" ; git branch; git pull ;Pop-Location} }"
powershell.exe "Get-ChildItem -Recurse -Directory -Path .\Installer\ | ForEach-Object { if ((Test-Path -Path (Join-Path -Path $_.FullName -ChildPath .git))) { Push-Location $_.FullName; Write-Host `"Updating $_.FullName`" ; git branch; git pull ;Pop-Location} }"
