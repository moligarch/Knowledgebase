# Define the root directory of your project
$projectRoot = "C:\Users\verkiani\Desktop\root"

# Function to create directory if it doesn't exist
function Ensure-Directory($path) {
    if (!(Test-Path $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
    }
}

# Main function to organize files
function Organize-ProjectFiles($currentDir) {
    # Get all items in the current directory
    $items = Get-ChildItem -Path $currentDir

    foreach ($item in $items) {
        if ($item.PSIsContainer) {
            # Handle directories
            if ($item.Name -ne "include" -and $item.Name -ne "src") {
                $relativePath = $item.FullName.Substring($projectRoot.Length).TrimStart('\')
                
                # Create corresponding directories in include and src
                $includeTarget = Join-Path $projectRoot -ChildPath "include" | Join-Path -ChildPath $relativePath
                $srcTarget = Join-Path $projectRoot -ChildPath "src" | Join-Path -ChildPath $relativePath
                
                Ensure-Directory $includeTarget
                Ensure-Directory $srcTarget

                Organize-ProjectFiles $item.FullName
            }
        } else {
            # Handle files
            $fileName = $item.Name
            $fileExtension = $item.Extension
            
            if (($fileExtension -eq ".h") -or ($fileExtension -eq ".hpp")) {
                $targetPath = Join-Path $projectRoot -ChildPath "include" | Join-Path -ChildPath ($item.FullName.Substring($projectRoot.Length).TrimStart('\'))
                Move-Item -Path $item.FullName -Destination $targetPath -Force
                Write-Host "Moved header file: $($item.FullName) -> $targetPath" -ForegroundColor Green
            } elseif ($fileExtension -eq ".cpp") {
                $targetPath = Join-Path $projectRoot -ChildPath "src" | Join-Path -ChildPath ($item.FullName.Substring($projectRoot.Length).TrimStart('\'))
                Move-Item -Path $item.FullName -Destination $targetPath -Force
                Write-Host "Moved source file: $($item.FullName) -> $targetPath" -ForegroundColor Green
            } else {
                Write-Host "Skipping non-C++ file: $($item.FullName)" -ForegroundColor Yellow
            }
        }
    }
}

try {
    # Create main include and src folders if they don't exist
    Ensure-Directory (Join-Path $projectRoot "include")
    Ensure-Directory (Join-Path $projectRoot "src")

    # Start organizing from the project root
    Organize-ProjectFiles $projectRoot
    
    Write-Host "Project organization completed." -ForegroundColor Cyan
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
}