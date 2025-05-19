<#
.SYNOPSIS
    Unified Logging Module.
#>

enum LogLevel {
    Error = 1
    Warning = 2
    Info = 3
    Verbose = 4
}

$script:LogConfiguration = @{
    LogFilePath = "C:\DeploymentLogs"
    LogLevel = [LogLevel]::Info
    LogFile = ""
}

function Initialize-Logging {
    param (
        [string]$LogPath,
        [string]$LogLevel
    )

    $script:LogConfiguration.$LogPath = $LogPath
    $script:LogConfiguration.$LogLevel = [LogLevel]$LogLevel
    $script:LogConfiguration.LogFile = Join-Path $LogPath "Deployment_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
    }
}

function Write-Log {
    param (
        [LogLevel]$Level,
        [string]$Message,
        [object]$Exeception
    )

    if ($Level -gt $script:LogConfiguration.LogLevel) { return }

    $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    if ($Exeception) {
        $logEntry += "`nException: $($Exeception | Out-String)"
    }

    # Write to file
    $logEntry | Out-File -FilePath $script:LogConfiguration.LogFile -Append -Encoding UTF8

    # Write to console with colors
    switch ($Level) {
        "Error" { Write-Host $logEntry -ForegroundColor Red }
        "Warning" { Write-Host $logEntry -ForegroundColor Yellow }
        "Info" { Write-Host $logEntry -ForegroundColor Green }
        default { Write-Host $logEntry }
    }
    
}