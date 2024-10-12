param (
    [Parameter (Mandatory = $true)] [ValidateSet('Release', 'Debug')] [string]$BuildConfig,
    [Parameter (Mandatory = $true)] [ValidateSet('x86', 'x64')] [string]$BuildArch
)

function InitDevShell {   
    $vsPath = &(Join-Path ${env:ProgramFiles(x86)} "\Microsoft Visual Studio\Installer\vswhere.exe") -latest -property installationpath
    
    if ($BuildArch -ieq "x86") {
        & (Join-Path -Path $vsPath -ChildPath "Common7\Tools\Launch-VsDevShell.ps1") -Arch x86 -HostArch amd64 -SkipAutomaticLocation
    }
    if ($BuildArch -ieq "x64") {
        & (Join-Path -Path $vsPath -ChildPath "Common7\Tools\Launch-VsDevShell.ps1") -Arch amd64 -HostArch amd64 -SkipAutomaticLocation
    } 
}

function CloneRepo {
    param (
        [Parameter (Mandatory = $true)] [string]$RepoDir,
        [Parameter (Mandatory = $true)] [string]$TargetBranch
    )
        
    if (-Not (Test-Path (Join-Path -Path $RepoDir -ChildPath ".git"))) {
        Write-Host "Git repo doesn't exist, starting cloning it at ${RepoDir}`n"
        git clone --depth 1 --branch "v${TargetBranch}" --recurse-submodules --shallow-submodules https://github.com/grpc/grpc "${RepoDir}"
    }
    else {
        Push-Location $RepoDir
        git pull
        Pop-Location
    }
}

function EnsureDirectoryExists {
    param (
        [Parameter(Mandatory=$true)] [string]$DirectoryPath
    )
    
    if (-not (Test-Path $DirectoryPath)) {
        try {
            New-Item -ItemType Directory -Force -Path $DirectoryPath | Out-Null
            Write-Host "Created directory: $DirectoryPath"
        }
        catch {
            Write-Host "Error creating directory $DirectoryPath: $_" -ForegroundColor Red
            exit 1
        }
    }
}

function CmakeGenerate {
    param (
        [Parameter (Mandatory = $true)] [string]$SourceDir,
        [Parameter (Mandatory = $true)] [string]$BuildDir  ,      
        [Parameter (Mandatory = $true)] [ValidateSet('Release', 'Debug')] [string]$BuildConfig,
        [Parameter (Mandatory = $true)] [string]$InstallDir
    )
    
    & cmake.exe -G Ninja -S "${SourceDir}" -B "${BuildDir}" -DCMAKE_BUILD_TYPE="${BuildConfig}" -DCMAKE_INSTALL_PREFIX="${InstallDir}" -DCMAKE_C_COMPILER="cl.exe" -DCMAKE_CXX_COMPILER="cl.exe"
}

function CmakeBuildInstall {
    param (
        [Parameter (Mandatory = $true)] [string]$SourceDir,
        [Parameter (Mandatory = $true)] [string]$BuildDir  ,      
        [Parameter (Mandatory = $true)] [ValidateSet('Release', 'Debug')] [string]$BuildConfig,
        [Parameter (Mandatory = $true)] [string]$InstallDir
    )
    
    & cmake.exe --build "${BuildDir}" --config "${BuildConfig}" --target install -- -v -j9 
}

InitDevShell

$Version = "1.59.1"
$BuildRepoDir = "C:\dev\source"

EnsureDirectoryExists -DirectoryPath $BuildRepoDir

$SourceRepoDir 	= "${BuildRepoDir}\grpc_${Version}"
$BuildDir 		= "$SourceRepoDir\${BuildArch}_release_build"
$InstallDir 	= "C:\dev\third_party\grpc\build-${BuildArch}-${BuildConfig}"

EnsureDirectoryExists -DirectoryPath $SourceRepoDir
EnsureDirectoryExists -DirectoryPath $BuildDir
EnsureDirectoryExists -DirectoryPath $InstallDir

CloneRepo -RepoDir "${SourceRepoDir}" -TargetBranch "${Version}"
CmakeGenerate -SourceDir "${SourceRepoDir}" -BuildDir "${BuildDir}" -BuildConfig "${BuildConfig}" -InstallDir "${InstallDir}"
CmakeBuildInstall -SourceDir "${SourceRepoDir}" -BuildDir "${BuildDir}" -BuildConfig "${BuildConfig}" -InstallDir "${InstallDir}"