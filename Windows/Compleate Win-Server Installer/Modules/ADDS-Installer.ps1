<#
.SYNOPSIS
    Active Directory Deployment Module
#>

param (
    [string]$DomainName,
    [securestring]$SafeModePassword,
    [string]$NetBIOSName,
    [switch]$WhatIf
)

# Import Logging Module
. .\Logging.psm1

try {
    Write-Log -Level Info -Message "Beginning ADDS installation process."

    if (-not (Get-WindowsFeature -Name AD-Domain-Services).Installed) {
        Write-Log -Level Info -Message "Installing AD-Domain-Services feature."
        if (-not $WhatIf) {
            Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
        }
    }

    if (-not $WhatIf) {
        Write-Log -Level Info -Message "Promoting server to Domain Controller."
        Install-ADDSForest `
            -DomainName $DomainName `
            -SafeModeAdministratorPassword $SafeModePassword `
            -NetBIOSName $NetBIOSName `
            -InstallDNS:$true `
            -Force:$true

        Write-Log -Level Info -Message "Domain Controller promotion successful"
    } else {
        Write-Log -Level Info -Message "WhatIf: Would promote server to Domain Controller"
    }

    return @{Success=$true}
}
catch {
    write-log -Level Error -Message "ADDS installation failed: $_"
    return @{Success=$false; Message=$_}
}