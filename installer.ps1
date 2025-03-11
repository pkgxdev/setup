# irm https://pkgx.sh | iex

$ErrorActionPreference = "Stop"

# Determine install location
$installDir = "$env:ProgramFiles\pkgx"

# Create directory if it doesn't exist
if (!(Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

# Download and extract
$zipUrl = "https://pkgx.sh/Windows/x86_64.zip"
$zipFile = "$env:TEMP\pkgx.zip"
Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile
Expand-Archive -Path $zipFile -DestinationPath $installDir -Force
Remove-Item $zipFile

# Ensure PATH is updated
$envPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
if ($envPath -notlike "*$installDir*") {
    [System.Environment]::SetEnvironmentVariable("Path", "$envPath;$installDir", [System.EnvironmentVariableTarget]::Machine)
}

Write-Host "pkgx installed successfully! Restart your terminal to use it."
