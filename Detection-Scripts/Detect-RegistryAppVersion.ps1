<#
.SYNOPSIS
    Custom Intune Win32 Detection Script that checks both 64-bit and 32-bit Uninstall keys using [version] comparison.
.DESCRIPTION
    Prevents the common Intune string comparison bug (where "9.0" is evaluated as greater than "10.0")
    by parsing DisplayVersion into a [System.Version] object and searching both x64 and WOW6432Node hives.
.NOTES
    Author: AdminSignal (https://adminsignal.com)
#>

$TargetAppNamePattern = "*7-Zip*"
[version]$MinimumVersion = "24.0.0"

$UninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$matchedApps = Get-ItemProperty -Path $UninstallPaths -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like $TargetAppNamePattern -and $_.DisplayVersion }

foreach ($app in $matchedApps) {
    try {
        $cleanVerString = ($app.DisplayVersion -replace "[^0-9\.]", "").Trim(".")
        [version]$installedVer = $cleanVerString
        if ($installedVer -ge $MinimumVersion) {
            Write-Output "Detected: $($app.DisplayName) v$($app.DisplayVersion) (Meets minimum v$MinimumVersion)"
            exit 0
        }
    } catch {}
}

exit 1
