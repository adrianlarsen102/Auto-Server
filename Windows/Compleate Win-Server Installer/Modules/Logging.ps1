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

