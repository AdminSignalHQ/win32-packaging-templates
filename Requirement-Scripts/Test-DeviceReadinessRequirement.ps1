<#
.SYNOPSIS
    Custom Intune Win32 Requirement Rule script checking free disk space, conflicting processes, and pending reboots.
.DESCRIPTION
    Configure Intune Requirement Rule to wait for String output 'READY' with exit code 0.
    Ensures silent upgrades do not forcibly kill active user productivity apps mid-meeting or fail on low disk.
.NOTES
    Author: AdminSignal (https://adminsignal.com)
#>

$MinFreeSpaceGB      = 10
$ConflictingProcs    = @("outlook", "ms-teams", "winword")
$BlockOnPendingReboot = $true

# 1. Check free space on SystemDrive
$drive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
$freeGB = [math]::Round($drive.FreeSpace / 1GB, 2)
if ($freeGB -lt $MinFreeSpaceGB) {
    Write-Output "NOT_READY: Insufficient disk space ($freeGB GB free, $MinFreeSpaceGB GB required)"
    exit 0
}

# 2. Check conflicting processes
foreach ($procName in $ConflictingProcs) {
    if (Get-Process -Name $procName -ErrorAction SilentlyContinue) {
        Write-Output "NOT_READY: Conflicting process '$procName' is currently running"
        exit 0
    }
}

# 3. Check pending reboot if enabled
if ($BlockOnPendingReboot) {
    $cbsReboot = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
    $wuReboot  = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    if ($cbsReboot -or $wuReboot) {
        Write-Output "NOT_READY: Endpoint has a pending reboot"
        exit 0
    }
}

Write-Output "READY"
exit 0
