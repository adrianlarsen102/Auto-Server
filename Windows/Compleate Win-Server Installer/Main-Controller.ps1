<#
.SYNOPSIS
    Enterprise Deployment Controller v2.0
.NOTES
    Version: 2.0.0
    Requires: PowerShell 5.1+
#>

param (
    [string]$ConfigPath = ".\config.json",
    [switch]$WhatIf
)

#region Initialization
$ErrorActionPreference = "Stop"
$script:StartTime = Get-Date
$script:DeploymentVersion = $null

# Load modules
. .\Windows\Compleate Win-Server Installer\Modules\Logging.ps1
. .\Windows\Compleate Win-Server Installer\Modules\Configuration-Helpers.ps1
. .\Windows\Compleate Win-Server Installer\Modules\ADDS-Installer.ps1
. .\Windows\Compleate Win-Server Installer\Modules\DNS-Installer.ps1
. .\Windows\Compleate Win-Server Installer\Modules\DHCP-Installer.ps1
. .\Windows\Compleate Win-Server Installer\Modules\IIS-Installer.ps1

# Load and validate configuration
try {
    $config = Get-Content $ConfigPath | ConvertFrom-Json -ErrorAction Stop
    $script:DeploymentVersion = $config.Version
    Write-Log -Level Info -Message "Loaded configuration (Version $($config.Version)) from $ConfigPath"
    
    # Initialize logging
    Initialize-Logging -LogPath $config.Logging.LogPath -LogLevel $config.Logging.LogLevel
}
catch {
    Write-Log -Level Error -Message "Configuration load failed: $_"
    exit 1
}

# Get credentials
$credential = Get-Credential -Message "Enter domain admin credentials"
Write-Log -Level Info -Message "Credentials acquired for deployment"
#endregion

#region ADDS Deployment
if ($config.ADDS.Install -and (-not $WhatIf)) {
    try {
        Write-Log -Level Info -Message "Starting ADDS deployment"
        
        $safeModePwd = Read-Host "Enter Safe Mode Recovery Password" -AsSecureString
        $addsParams = @{
            DomainName        = $config.ADDS.DomainName
            SafeModePassword  = $safeModePwd
            NetbiosName       = $config.ADDS.NetBIOSName
            WhatIf            = $WhatIf
        }
        
        Invoke-RemoteInstallation -ServerName $config.Servers.PrimaryServer `
                                 -Credential $credential `
                                 -ScriptPath ".\Modules\ADDS-Installer.ps1" `
                                 -Arguments $addsParams
        
        Write-Log -Level Info -Message "ADDS deployment completed successfully"
    }
    catch {
        Write-Log -Level Error -Message "ADDS deployment failed: $_"
        exit 1
    }
}
#endregion

#region Post-Deployment Validation
try {
    Write-Log -Level Info -Message "Starting post-deployment validation"
    
    # Verify domain controller promotion
    if ($config.ADDS.Install) {
        $dcStatus = Invoke-Command -ComputerName $config.Servers.PrimaryServer -Credential $credential -ScriptBlock {
            Get-ADDomainController -Identity $env:COMPUTERNAME
        }
        Write-Log -Level Info -Message "Domain Controller status: $($dcStatus.Enabled)"
    }
    
    Write-Log -Level Info -Message "Deployment completed in $((Get-Date) - $script:StartTime)"
}
catch {
    Write-Log -Level Error -Message "Post-deployment check failed: $_"
    exit 1
}
#endregion