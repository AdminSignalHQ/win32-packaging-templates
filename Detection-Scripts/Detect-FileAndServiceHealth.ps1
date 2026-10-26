<#
.SYNOPSIS
    Multi-condition Intune Detection Script verifying binary existence, file version, and Windows service status.
.DESCRIPTION
    Ideal for endpoint management and security agents (Tanium, Defender, CrowdStrike, VPN clients) where
    a registry key alone does not guarantee the agent binary is present and running.
.NOTES
    Author: AdminSignal (https://adminsignal.com)
#>

$BinaryPath     = "C:\Program Files\Tanium\Tanium Client\TaniumClient.exe"
$ServiceName    = "Tanium Client"
[version]$MinFileVersion = "7.4.0.0"

if (-not (Test-Path -Path $BinaryPath)) {
    exit 1
}

try {
    $fileInfo = (Get-Item -Path $BinaryPath).VersionInfo
    $rawVersion = "$($fileInfo.FileMajorPart).$($fileInfo.FileMinorPart).$($fileInfo.FileBuildPart).$($fileInfo.FilePrivatePart)"
    [version]$currentVersion = $rawVersion
    if ($currentVersion -lt $MinFileVersion) {
        exit 1
    }
} catch {
    exit 1
}

$svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($null -eq $svc -or $svc.Status -ne "Running") {
    exit 1
}

Write-Output "Healthy: $ServiceName is Running and binary version is $currentVersion"
exit 0
