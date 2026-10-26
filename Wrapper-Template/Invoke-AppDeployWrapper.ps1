<#
.SYNOPSIS
    Standardized zero-dependency PowerShell wrapper for Microsoft Intune Win32 (.intunewin) deployments.
.DESCRIPTION
    Handles 32-bit to 64-bit PowerShell SysNative redirection, writes detailed logs to the Intune
    Management Extension log directory (so Collect Diagnostics captures it automatically), executes
    MSI or EXE installers, and stamps a clean registry tattoo for reliable Intune detection.
.PARAMETER DeploymentType
    Specify 'Install' or 'Uninstall'. Defaults to 'Install'.
.NOTES
    Author: AdminSignal (https://adminsignal.com)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Install", "Uninstall")]
    [string]$DeploymentType = "Install"
)

# --- 1. APPLICATION METADATA (Customize per package) ---
$AppVendor  = "Contoso"
$AppName    = "EnterpriseAgent"
$AppVersion = "2.4.0"
$InstallerFile = "setup.msi" # Place in same folder as this script

# --- 2. ENSURE 64-BIT POWERSHELL EXECUTION ---
if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    $sysNativePs = Join-Path $env:WINDIR "SysNative\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $sysNativePs) {
        $argsList = "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$PSCommandPath`" -DeploymentType $DeploymentType"
        $proc = Start-Process -FilePath $sysNativePs -ArgumentList $argsList -Wait -PassThru -NoNewWindow
        exit $proc.ExitCode
    }
}

# --- 3. INITIALIZE LOGGING IN IME DIRECTORY ---
$LogDir = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$LogFile = Join-Path $LogDir "$($AppVendor)_$($AppName)_$($AppVersion)_$($DeploymentType).log"

Start-Transcript -Path $LogFile -Append -Force | Out-Null
Write-Output "[$(Get-Date -Format 'u')] Starting $DeploymentType of $AppVendor $AppName v$AppVersion"

$RegBrandPath = "HKLM:\SOFTWARE\AdminSignal\InstalledApps\$AppName"
$ExitCode = 0

try {
    $InstallerPath = Join-Path $PSScriptRoot $InstallerFile

    if ($DeploymentType -eq "Install") {
        if (-not (Test-Path $InstallerPath)) {
            throw "Installer file not found at: $InstallerPath"
        }

        $msiLog = Join-Path $LogDir "$($AppVendor)_$($AppName)_$($AppVersion)_MSI_Install.log"
        if ($InstallerFile -match "\.msi$") {
            $msiArgs = "/i `"$InstallerPath`" /qn /norestart /L*v `"$msiLog`""
            Write-Output "Executing msiexec.exe $msiArgs"
            $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -NoNewWindow
            $ExitCode = $proc.ExitCode
        } else {
            $exeArgs = "/S /norestart"
            Write-Output "Executing $InstallerPath $exeArgs"
            $proc = Start-Process -FilePath $InstallerPath -ArgumentList $exeArgs -Wait -PassThru -NoNewWindow
            $ExitCode = $proc.ExitCode
        }

        if ($ExitCode -in @(0, 3010, 1641)) {
            if (-not (Test-Path $RegBrandPath)) { New-Item -Path $RegBrandPath -Force | Out-Null }
            Set-ItemProperty -Path $RegBrandPath -Name "Version" -Value $AppVersion -Type String -Force
            Set-ItemProperty -Path $RegBrandPath -Name "InstallDate" -Value (Get-Date -Format "u") -Type String -Force
            Set-ItemProperty -Path $RegBrandPath -Name "Vendor" -Value $AppVendor -Type String -Force
            Write-Output "Stamped detection registry key at $RegBrandPath"
        }
    }
    elseif ($DeploymentType -eq "Uninstall") {
        $msiLog = Join-Path $LogDir "$($AppVendor)_$($AppName)_$($AppVersion)_MSI_Uninstall.log"
        if ($InstallerFile -match "\.msi$" -and (Test-Path $InstallerPath)) {
            $msiArgs = "/x `"$InstallerPath`" /qn /norestart /L*v `"$msiLog`""
            $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -NoNewWindow
            $ExitCode = $proc.ExitCode
        }
        if ($ExitCode -in @(0, 3010, 1641)) {
            if (Test-Path $RegBrandPath) {
                Remove-Item -Path $RegBrandPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
catch {
    Write-Error "Exception during $DeploymentType : $($_.Exception.Message)"
    $ExitCode = 1
}
finally {
    Write-Output "[$(Get-Date -Format 'u')] Completed $DeploymentType with exit code: $ExitCode"
    Stop-Transcript | Out-Null
}

exit $ExitCode
