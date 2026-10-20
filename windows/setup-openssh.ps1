<#
.SYNOPSIS
    Install OpenSSH Server and register a public key for key-based login.

.DESCRIPTION
    For an administrator account, Windows OpenSSH reads keys from
    C:\ProgramData\ssh\administrators_authorized_keys (not ~/.ssh/authorized_keys),
    and the file must be accessible only by Administrators and SYSTEM.

.EXAMPLE
    # Run in an administrator PowerShell
    .\setup-openssh.ps1 -PublicKey "ssh-ed25519 AAAA... user@mac"
    .\setup-openssh.ps1 -PublicKey "ssh-ed25519 AAAA... user@mac" -DefaultShellPowerShell
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$PublicKey,

    [switch]$DefaultShellPowerShell
)

$ErrorActionPreference = "Stop"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    throw "Run this script in an administrator PowerShell."
}

# Install and start sshd (installation can take a few minutes)
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic

# Register the public key
$keyFile = "C:\ProgramData\ssh\administrators_authorized_keys"
Add-Content -Path $keyFile -Value $PublicKey
icacls.exe $keyFile /inheritance:r /grant "*S-1-5-32-544:F" /grant "*S-1-5-18:F" | Out-Null

# Optional: use PowerShell instead of cmd for SSH sessions
if ($DefaultShellPowerShell) {
    New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell `
        -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
        -PropertyType String -Force | Out-Null
}

Get-Service sshd
Write-Host "SSH user name: $env:USERNAME"
