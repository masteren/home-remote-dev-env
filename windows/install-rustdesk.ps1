<#
.SYNOPSIS
    Silently install RustDesk as a service and point it at a self-hosted server.
    Designed to be run over SSH, without access to the desktop GUI.

.DESCRIPTION
    1. Download the latest x86_64 installer from GitHub Releases
    2. Install silently and make sure the RustDesk service is running
    3. Apply the server config string (exported from another client:
       Settings > Network > ID/Relay server > Export server config)
    4. Set a permanent password and print the device ID

.EXAMPLE
    # Over SSH in an administrator PowerShell session
    .\install-rustdesk.ps1 -ConfigString "<exported config string>"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigString
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # much faster Invoke-WebRequest

$password = Read-Host "Permanent password for RustDesk" -AsSecureString
$plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))

# 1. Download
$release = Invoke-RestMethod https://api.github.com/repos/rustdesk/rustdesk/releases/latest
$url = ($release.assets | Where-Object name -match 'x86_64\.exe$' | Select-Object -First 1).browser_download_url
Write-Host "Downloading $url"
$installer = Join-Path $env:TEMP "rustdesk.exe"
Invoke-WebRequest $url -OutFile $installer

# 2. Silent install as a service
Start-Process $installer -ArgumentList "--silent-install"
Start-Sleep -Seconds 30

$exe = Join-Path $env:ProgramFiles "RustDesk\rustdesk.exe"
if (-not (Get-Service RustDesk -ErrorAction SilentlyContinue)) {
    Start-Process $exe -ArgumentList "--install-service"
    Start-Sleep -Seconds 20
}
Start-Service RustDesk

# 3. Server config / 4. password
& $exe --config $ConfigString
& $exe --password $plainPassword
Restart-Service RustDesk

$id = & $exe --get-id | Out-String
Write-Host "RustDesk ID: $($id.Trim())"
