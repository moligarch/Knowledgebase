Param
(
	 [Parameter (Mandatory = $true)] [ValidateSet('x64', 'x86')] [string]$Arch
)

$VisualStudioPath = &(Join-Path ${env:ProgramFiles(x86)} "\Microsoft Visual Studio\Installer\vswhere.exe") -latest -property installationpath
echo "VS Installation path is: $VisualStudioPath"
$VisualStudioDevShellPath = (Join-Path -Path $VisualStudioPath -ChildPath "\Common7\Tools\Launch-VsDevShell.ps1")
echo "VS DevShell Script path is: $VisualStudioDevShellPath"
if ($Arch -ieq "x86") {
	& $VisualStudioDevShellPath -Arch x86 -HostArch amd64 -SkipAutomaticLocation
	echo "Done"
}
else {
	& $VisualStudioDevShellPath -Arch amd64 -HostArch amd64 -SkipAutomaticLocation
	echo "Done"
}