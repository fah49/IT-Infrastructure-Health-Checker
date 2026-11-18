
# ==========================================================
# IT INFRASTRUCTURE HEALTH CHECKER
# Compatible with Windows PowerShell 5.1
# ==========================================================

# ---------------- CONFIGURATION ----------------

$ErrorActionPreference = "Stop"

$ReportPath = Join-Path $PSScriptRoot "HealthReport.csv"
$LogPath = Join-Path $PSScriptRoot "HealthChecker.log"

$Report = @()
$CheckTime = Get-Date



# ---------------- REPORTING FUNCTION ----------------

function Add-HealthResult {

    param(
        [string]$Category,
        [string]$Check,
        [string]$Result,
        [string]$Status
    )

    $ReportRow = [PSCustomObject]@{
        CheckTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Category  = $Category
        Check     = $Check
        Result    = $Result
        Status    = $Status
    }

    $script:Report += $ReportRow
}

# ---------------- LOGGING FUNCTION ----------------

function Write-HealthLog {

    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp [$Level] $Message"

    Add-Content -Path $LogPath -Value $LogEntry
}

# ==========================================================
# 1. SYSTEM INFORMATION
# ==========================================================

Write-Host "`n===================================="
Write-Host "SYSTEM INFORMATION"
Write-Host "===================================="

try {

    $ComputerName = $env:COMPUTERNAME
    $Username = $env:USERNAME
    $OperatingSystem = (Get-CimInstance Win32_OperatingSystem).Caption
    $PowerShellVersion = $PSVersionTable.PSVersion.ToString()

    Write-Host "Computer Name: $ComputerName"
    Write-Host "Username: $Username"
    Write-Host "Operating System: $OperatingSystem"
    Write-Host "PowerShell Version: $PowerShellVersion"
    Write-Host "Check Date: $CheckTime"

    Add-HealthResult "System" "Computer Name" $ComputerName "Healthy"
    Add-HealthResult "System" "Operating System" $OperatingSystem "Healthy"
    Add-HealthResult "System" "PowerShell Version" $PowerShellVersion "Healthy"

}
catch {

    Write-Host "System information check failed." -ForegroundColor Red
    Write-HealthLog $_.Exception.Message "ERROR"

    Add-HealthResult "System" "System Information" $_.Exception.Message "Error"
}

# ==========================================================
# 2. CPU MONITORING
# ==========================================================

Write-Host "`n===================================="
Write-Host "CPU MONITORING"
Write-Host "===================================="

try {

    $CPUData = Get-CimInstance Win32_Processor

    $CPUUsage = ($CPUData |
        Measure-Object -Property LoadPercentage -Average).Average

    if ($null -eq $CPUUsage) {
        throw "CPU usage could not be retrieved."
    }

    $CPUUsage = [math]::Round($CPUUsage, 2)

    Write-Host "CPU Usage: $CPUUsage%"

    if ($CPUUsage -ge 90) {

        $CPUStatus = "Warning"
        Write-Host "WARNING: High CPU usage!" -ForegroundColor Red

    }
    else {

        $CPUStatus = "Healthy"
        Write-Host "CPU status: Normal" -ForegroundColor Green

    }

    Add-HealthResult "Performance" "CPU Usage" "$CPUUsage%" $CPUStatus

}
catch {

    Write-Host "CPU monitoring failed." -ForegroundColor Red
    Write-HealthLog $_.Exception.Message "ERROR"

    Add-HealthResult "Performance" "CPU Usage" $_.Exception.Message "Error"
}

# ==========================================================
# 3. MEMORY MONITORING
# ==========================================================

Write-Host "`n===================================="
Write-Host "MEMORY MONITORING"
Write-Host "===================================="

try {

    $OS = Get-CimInstance Win32_OperatingSystem

    $TotalMemoryGB = [math]::Round($OS.TotalVisibleMemorySize / 1MB, 2)
    $FreeMemoryGB = [math]::Round($OS.FreePhysicalMemory / 1MB, 2)
    $UsedMemoryGB = [math]::Round($TotalMemoryGB - $FreeMemoryGB, 2)

    $MemoryUsage = [math]::Round(
        (($TotalMemoryGB - $FreeMemoryGB) / $TotalMemoryGB) * 100, 2
    )

    Write-Host "Total Memory: $TotalMemoryGB GB"
    Write-Host "Used Memory: $UsedMemoryGB GB"
    Write-Host "Free Memory: $FreeMemoryGB GB"
    Write-Host "Memory Usage: $MemoryUsage%"

    if ($MemoryUsage -ge 90) {

        $MemoryStatus = "Warning"
        Write-Host "WARNING: High memory usage!" -ForegroundColor Red

    }
    else {

        $MemoryStatus = "Healthy"
        Write-Host "Memory status: Normal" -ForegroundColor Green

    }

    Add-HealthResult "Performance" "Memory Usage" "$MemoryUsage%" $MemoryStatus
    Add-HealthResult "Performance" "Total Memory" "$TotalMemoryGB GB" "Healthy"
    Add-HealthResult "Performance" "Free Memory" "$FreeMemoryGB GB" "Healthy"

}
catch {

    Write-Host "Memory monitoring failed." -ForegroundColor Red
    Write-HealthLog $_.Exception.Message "ERROR"

    Add-HealthResult "Performance" "Memory Usage" $_.Exception.Message "Error"
}

# ==========================================================
# 4. DISK SPACE MONITORING
# ==========================================================

Write-Host "`n===================================="
Write-Host "DISK SPACE MONITORING"
Write-Host "===================================="

try {

    $Disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"

    foreach ($Disk in $Disks) {

        try {

            if ($Disk.Size -le 0) {
                throw "Drive size is unavailable."
            }

            $DriveName = $Disk.DeviceID

            $TotalSpaceGB = [math]::Round($Disk.Size / 1GB, 2)
            $FreeSpaceGB = [math]::Round($Disk.FreeSpace / 1GB, 2)
            $UsedSpaceGB = [math]::Round(($Disk.Size - $Disk.FreeSpace) / 1GB, 2)

            $FreePercentage = [math]::Round(
                ($Disk.FreeSpace / $Disk.Size) * 100, 2
            )

            Write-Host "`nDrive: $DriveName"
            Write-Host "Total Space: $TotalSpaceGB GB"
            Write-Host "Used Space: $UsedSpaceGB GB"
            Write-Host "Free Space: $FreeSpaceGB GB"
            Write-Host "Free Space: $FreePercentage%"

            if ($FreePercentage -lt 15) {

                $DiskStatus = "Warning"
                Write-Host "WARNING: Low disk space!" -ForegroundColor Red

            }
            else {

                $DiskStatus = "Healthy"
                Write-Host "Disk status: Normal" -ForegroundColor Green

            }

            Add-HealthResult "Disk" "$DriveName Free Space" "$FreePercentage% free" $DiskStatus
            Add-HealthResult "Disk" "$DriveName Total Capacity" "$TotalSpaceGB GB" "Healthy"

        }
        catch {

            Write-HealthLog "$($Disk.DeviceID): $($_.Exception.Message)" "ERROR"

            Add-HealthResult "Disk" "$($Disk.DeviceID) Check" $_.Exception.Message "Error"
        }
    }

}
catch {

    Write-Host "Disk monitoring failed." -ForegroundColor Red
    Write-HealthLog $_.Exception.Message "ERROR"

    Add-HealthResult "Disk" "Disk Monitoring" $_.Exception.Message "Error"
}

# ==========================================================
# 5. WINDOWS SERVICE MONITORING
# ==========================================================

Write-Host "`n===================================="
Write-Host "WINDOWS SERVICE MONITORING"
Write-Host "===================================="

# Some services normally stop when not needed.
# Only services marked ExpectedRunning are flagged as warnings.

$ImportantServices = @(
    [PSCustomObject]@{ Name = "Dhcp"; ExpectedRunning = $true }
    [PSCustomObject]@{ Name = "Dnscache"; ExpectedRunning = $true }
    [PSCustomObject]@{ Name = "EventLog"; ExpectedRunning = $true }
    [PSCustomObject]@{ Name = "wuauserv"; ExpectedRunning = $false }
    [PSCustomObject]@{ Name = "WinDefend"; ExpectedRunning = $false }
)

foreach ($ServiceInfo in $ImportantServices) {

    try {

        $Service = Get-Service -Name $ServiceInfo.Name -ErrorAction Stop

        Write-Host "`nService: $($Service.DisplayName)"
        Write-Host "Status: $($Service.Status)"

        if ($Service.Status -eq "Running") {

            $ServiceStatus = "Healthy"
            Write-Host "Service status: Normal" -ForegroundColor Green

        }
        elseif ($ServiceInfo.ExpectedRunning) {

            $ServiceStatus = "Warning"
            Write-Host "WARNING: Expected service is not running!" -ForegroundColor Red

        }
        else {

            $ServiceStatus = "Informational"
            Write-Host "Service is stopped; this may be normal." -ForegroundColor Yellow

        }

        Add-HealthResult "Services" $Service.DisplayName "$($Service.Status)" $ServiceStatus

    }
    catch {

        Write-Host "Could not check service: $($ServiceInfo.Name)" -ForegroundColor Red
        Write-HealthLog "$($ServiceInfo.Name): $($_.Exception.Message)" "ERROR"

        Add-HealthResult "Services" $ServiceInfo.Name $_.Exception.Message "Error"
    }
}

# ==========================================================
# 6. NETWORK CONNECTIVITY MONITORING
# ==========================================================

Write-Host "`n===================================="
Write-Host "NETWORK CONNECTIVITY"
Write-Host "===================================="

try {

    $NetworkConfig = Get-NetIPConfiguration |
        Where-Object { $_.IPv4DefaultGateway -ne $null } |
        Select-Object -First 1

    if ($NetworkConfig) {

        $IPAddress = $NetworkConfig.IPv4Address.IPAddress
        $Gateway = $NetworkConfig.IPv4DefaultGateway.NextHop

        Write-Host "IP Address: $IPAddress"
        Write-Host "Default Gateway: $Gateway"

        Add-HealthResult "Network" "IP Address" "$IPAddress" "Healthy"
        Add-HealthResult "Network" "Default Gateway" "$Gateway" "Healthy"

        # Test local gateway connectivity

        $GatewayTest = Test-Connection -ComputerName $Gateway -Count 2 -Quiet

        if ($GatewayTest) {

            $GatewayStatus = "Healthy"
            Write-Host "Gateway connectivity: SUCCESS" -ForegroundColor Green

        }
        else {

            $GatewayStatus = "Warning"
            Write-Host "WARNING: Cannot reach gateway!" -ForegroundColor Red

        }

        Add-HealthResult "Network" "Gateway Connectivity" "$GatewayTest" $GatewayStatus

    }
    else {

        Write-Host "No IPv4 default gateway found." -ForegroundColor Red

        Add-HealthResult "Network" "Default Gateway" "Not found" "Warning"
    }

}
catch {

    Write-Host "Network configuration check failed." -ForegroundColor Red
    Write-HealthLog $_.Exception.Message "ERROR"

    Add-HealthResult "Network" "Network Configuration" $_.Exception.Message "Error"
}

# Test external IP connectivity

try {

    $InternetTest = Test-Connection -ComputerName "1.1.1.1" -Count 2 -Quiet

    if ($InternetTest) {

        $InternetStatus = "Healthy"
        Write-Host "External IP connectivity: SUCCESS" -ForegroundColor Green

    }
    else {

        $InternetStatus = "Warning"
        Write-Host "WARNING: External IP connectivity failed!" -ForegroundColor Red

    }

    Add-HealthResult "Network" "External IP Connectivity" "$InternetTest" $InternetStatus

}
catch {

    Write-Host "External connectivity test failed." -ForegroundColor Red
    Write-HealthLog $_.Exception.Message "ERROR"

    Add-HealthResult "Network" "External IP Connectivity" $_.Exception.Message "Error"
}

# ==========================================================
# 7. CSV REPORT GENERATION
# ==========================================================

Write-Host "`n===================================="
Write-Host "GENERATING HEALTH REPORT"
Write-Host "===================================="

try {

    $Report | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8

    Write-Host "CSV report saved successfully."
    Write-Host "Location: $ReportPath"

}
catch {

    Write-Host "Could not generate CSV report." -ForegroundColor Red
    Write-HealthLog $_.Exception.Message "ERROR"
}

# ==========================================================
# 8. FINAL SUMMARY AND LOGGING
# ==========================================================

Write-Host "`n===================================="
Write-Host "HEALTH CHECK SUMMARY"
Write-Host "===================================="

$HealthyCount = @($Report | Where-Object { $_.Status -eq "Healthy" }).Count
$WarningCount = @($Report | Where-Object { $_.Status -eq "Warning" }).Count
$ErrorCount = @($Report | Where-Object { $_.Status -eq "Error" }).Count
$InformationalCount = @($Report | Where-Object { $_.Status -eq "Informational" }).Count

Write-Host "Healthy Checks: $HealthyCount" -ForegroundColor Green
Write-Host "Warnings: $WarningCount" -ForegroundColor Yellow
Write-Host "Errors: $ErrorCount" -ForegroundColor Red
Write-Host "Informational: $InformationalCount"
Write-Host "Total Results: $($Report.Count)"

# Write warnings and errors to the log

$Problems = @($Report | Where-Object {
    $_.Status -eq "Warning" -or $_.Status -eq "Error"
})

foreach ($Problem in $Problems) {

    Write-HealthLog "$($Problem.Category) - $($Problem.Check): $($Problem.Result)" $Problem.Status.ToUpper()
}

if ($WarningCount -eq 0 -and $ErrorCount -eq 0) {

    Write-Host "`nOverall result: HEALTHY" -ForegroundColor Green

}
else {

    Write-Host "`nOverall result: ATTENTION REQUIRED" -ForegroundColor Yellow

}

Write-Host "`nLog file: $LogPath"
Write-Host "===================================="
Write-Host "HEALTH CHECK COMPLETED"
Write-Host "===================================="
