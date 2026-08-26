$ErrorActionPreference = "Stop"

# Install .NET on Windows: https://github.com/actions/virtual-environments/blob/main/images/win/scripts/Install-DotnetSDK.ps1

$dotnetPath = Join-Path -Path $env:ProgramFiles -ChildPath "dotnet"
$runKeyPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"

if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    Write-Host "Installed .NET SDKs before cleanup:"
    dotnet --list-sdks
} else {
    Write-Host "dotnet is not present before cleanup."
}

Write-Host "Moving .NET files"
# Move dotnet files to other place. Delete is too slow. Deletion takes about 7 minutes on GitHub Actions.
if (Test-Path -LiteralPath $dotnetPath) {
    Move-Item -LiteralPath $dotnetPath -Destination "C:\DotnetRecycleBin" -Force -Confirm:$false
} else {
    Write-Host "No .NET installation directory found at $dotnetPath."
}

Write-Host "Cleaning up registry"
if (Test-Path -LiteralPath $runKeyPath) {
    Remove-ItemProperty -Path $runKeyPath -Name "DOTNETUSERPATH" -ErrorAction SilentlyContinue
}

if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    Write-Host "dotnet remains available after cleanup."
} else {
    Write-Host "dotnet is unavailable after cleanup, as expected."
}
