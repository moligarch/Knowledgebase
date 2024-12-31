param (
    [Parameter (Mandatory = $true)] [ValidateSet('Release', 'Debug')] [string]$BuildConfig,
    [Parameter (Mandatory = $true)] [ValidateSet('x86', 'x64')] [string]$BuildArch
)

function GetVcpkgPath() {
    $vcpkg_install_dir = ""
    #
    # Check whther vcpkg is already installed/integrated or not, in case there was no vcpkg installed, then
    # try to clone and installed at hardcoded address "c:\dev\kits\vcpkg"
    #
    if (Test-Path -Path $env:localappdata\vcpkg\vcpkg.path.txt) {
        $vcpkg_install_dir = Get-Content $env:localappdata\vcpkg\vcpkg.path.txt
    }

    if ( ([string]::IsNullOrEmpty($vcpkg_install_dir))  ) {
        $vcpkg_install_dir = "c:\dev\kits\vcpkg"
    }
    
    return $vcpkg_install_dir
}

function InitDevShell {   
    if (-not $env:VSCMD_VER) {
        $vsPath = &(Join-Path ${env:ProgramFiles(x86)} "\Microsoft Visual Studio\Installer\vswhere.exe") -latest -property installationpath
        
        if ($BuildArch -ieq "x86") {
            & (Join-Path -Path $vsPath -ChildPath "Common7\Tools\Launch-VsDevShell.ps1") -Arch x86 -HostArch amd64 -SkipAutomaticLocation
        }
        if ($BuildArch -ieq "x64") {
            & (Join-Path -Path $vsPath -ChildPath "Common7\Tools\Launch-VsDevShell.ps1") -Arch amd64 -HostArch amd64 -SkipAutomaticLocation
        } 
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

function CmakeGenerate {
    param (
        [Parameter (Mandatory = $true)] [string]$SourceDir,
        [Parameter (Mandatory = $true)] [string]$BuildDir  ,      
        [Parameter (Mandatory = $true)] [ValidateSet('Release', 'Debug')] [string]$BuildConfig,
        [Parameter (Mandatory = $true)] [string]$InstallDir
    )
    

    $vcpkg_path = GetVcpkgPath
    if ( -Not (Test-Path -Path $vcpkg_path)) {
        Write-Error Failed to locate vcpkg.
    }


    # Do not compile redundant plugins: Node, Objective-C, PHP, Python and Ruby
    # gRPC_BACKWARDS_COMPATIBILITY_MODE Build libraries that are binary compatible across a larger number of OS and libc versions 
    # Build gRPC++ with OpenSSL instead of BoringSSL
    # -DgRPC_SSL_PROVIDER=package
    & cmake.exe -G Ninja -S "${SourceDir}" -B "${BuildDir}" -DCMAKE_BUILD_TYPE="${BuildConfig}" -DCMAKE_INSTALL_PREFIX="${InstallDir}" `

        -DgRPC_BUILD_GRPC_CSHARP_PLUGIN=OFF -DgRPC_BUILD_GRPC_NODE_PLUGIN=OFF -DgRPC_BUILD_GRPC_OBJECTIVE_C_PLUGIN=OFF `

        -DgRPC_BUILD_GRPC_PHP_PLUGIN=OFF  -DgRPC_BUILD_GRPC_PYTHON_PLUGIN=OFF -DgRPC_BUILD_GRPC_RUBY_PLUGIN=OFF  `

        -DgRPC_BACKWARDS_COMPATIBILITY_MODE=ON -DgRPC_SSL_PROVIDER=package `

        -DCMAKE_C_COMPILER="cl.exe" -DCMAKE_CXX_COMPILER="cl.exe" `

        -DCMAKE_TOOLCHAIN_FILE="${vcpkg_path}\scripts\buildsystems\vcpkg.cmake" -DVCPKG_INSTALLED_DIR="C:\vcpkg_install_${BuildArch}" -DVCPKG_TARGET_TRIPLET="${BuildArch}-windows-v143"
        
    # To build the gRPC with MT
    #  -DgRPC_MSVC_STATIC_RUNTIME=ON
    # 
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

$Version = "1.67.0"
$BuildRepoDir = "C:\dev\source"

$SourceRepoDir = "${BuildRepoDir}\grpc_${Version}"
$BuildDir = "$SourceRepoDir\${BuildArch}_${BuildConfig}_build"
$InstallDir = "C:\dev\third_party\grpc\build-${BuildArch}-${BuildConfig}"

Write-Host --------------------------------------------------------------------
Write-Host "Version:       ${Version}"
Write-Host "BuildRepoDir:  ${BuildRepoDir}"
Write-Host "SourceRepoDir: ${SourceRepoDir}"
Write-Host "BuildDir:      ${BuildDir}"
Write-Host "InstallDir:    ${InstallDir}"
Write-Host --------------------------------------------------------------------

CloneRepo -RepoDir "${SourceRepoDir}" -TargetBranch "${Version}"
CmakeGenerate -SourceDir "${SourceRepoDir}" -BuildDir "${BuildDir}" -BuildConfig "${BuildConfig}" -InstallDir "${InstallDir}"
CmakeBuildInstall -SourceDir "${SourceRepoDir}" -BuildDir "${BuildDir}" -BuildConfig "${BuildConfig}" -InstallDir "${InstallDir}"

# Remove the zlib.lib to remove extra dependency to the zlib.dll.
$ZlibFullPath = (Join-Path -Path "${InstallDir}" -ChildPath "lib\zlib.lib")
if( Test-Path -Path "${ZlibFullPath}") { Remove-Item -Path "${ZlibFullPath}" }
