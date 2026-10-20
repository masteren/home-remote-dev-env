<#
.SYNOPSIS
    Configure the wired NIC for Wake-on-LAN (wake from sleep and shutdown).

.DESCRIPTION
    - Wake on Magic Packet: on
    - Wake on pattern match: off (prevents unwanted wake-ups from ordinary LAN traffic)
    - Allow the NIC to wake the computer
    - Disable hibernation, which also disables Fast Startup (it interferes with WoL)
    - Disable automatic sleep on AC power (remote SSH sessions would be cut off)

    BIOS settings are also required (MSI boards):
      Settings > Advanced > Power Management Setup > ErP Ready = Disabled
      Settings > Advanced > Wake Up Event Setup > Resume By PCI-E/Networking Device = Enabled

.EXAMPLE
    # Run in an administrator PowerShell
    Get-NetAdapter                       # find the wired adapter name
    .\setup-wol.ps1 -AdapterName "Ethernet"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$AdapterName
)

$ErrorActionPreference = "Stop"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    throw "Run this script in an administrator PowerShell."
}

$adapter = Get-NetAdapter -Name $AdapterName

# Advanced properties of the NIC driver
Set-NetAdapterAdvancedProperty -Name $AdapterName -RegistryKeyword "*WakeOnMagicPacket" -RegistryValue 1
Set-NetAdapterAdvancedProperty -Name $AdapterName -RegistryKeyword "*WakeOnPattern" -RegistryValue 0

# Wake from shutdown (S5). Keyword exists on Realtek drivers; skip if absent.
if (Get-NetAdapterAdvancedProperty -Name $AdapterName -RegistryKeyword "S5WakeOnLan" -ErrorAction SilentlyContinue) {
    Set-NetAdapterAdvancedProperty -Name $AdapterName -RegistryKeyword "S5WakeOnLan" -RegistryValue 1
}

# Power management tab
Set-NetAdapterPowerManagement -Name $AdapterName -WakeOnMagicPacket Enabled -WakeOnPattern Disabled
powercfg /deviceenablewake "$($adapter.InterfaceDescription)"

# Disable hibernation (and therefore Fast Startup)
powercfg -h off

# Never sleep automatically on AC power, so remote SSH sessions are not cut off.
# Use `shutdown` or a manual sleep command when finished instead.
powercfg /change standby-timeout-ac 0

Write-Host ""
Write-Host "MAC address : $($adapter.MacAddress)"
Write-Host "Devices allowed to wake the computer:"
powercfg /devicequery wake_armed
