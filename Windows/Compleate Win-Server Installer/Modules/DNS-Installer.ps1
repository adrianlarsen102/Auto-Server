<#
.SYNOPSIS
    DNS Server Deployment Module v2.1
.NOTES
    Version: 2.1.0
#>

param (
    [hashtable]$Config,
    [switch]$WhatIf
)

# Import Logging
. .\Logging.ps1

try {
    Write-Log -Level Info -Message "Starting DNS Server configuration."

    # install DNS role if needed
    if (-not (Get-WindowsFeature -Name DNS).Installed) {
        Write-Log -Level Info -Message "Installing DNS Server role."
        if (-not $WhatIf) {
            Install-WindowsFeature -Name DNS -IncludeManagementTools
        }
    }

    if (-not $WhatIf) {
        # Configure forwarders
        if ($Config.Forwarders -and $Config.Forwarders.Count -gt 0) {
            Write-Log -Level Info -Message "Setting DNS forwarders: $($Config.Forwarders -join ', ')"
            Set-DnsServerForwarder -IPAddress $Config.Forwarders -PassThru | Out-Null
        }

        # Configure zones
        foreach ($zone in $Config.Zones) {
            if (-not (Get-DnsServerZone -Name $zone.Name -ErrorAction SilentlyContinue)) {
                Write-Log -Level Info -Message "Creating DNS zone: $($zone.Name)"
                $zoneParams = @{
                    Name = $zone.Name
                    ZoneFile = "$($zone.Name).dns"
                    DynamicUpdate = $zone.DynamicUpdate
                }
                Add-DnsServerPrimaryZone @zoneParams
            }
        }
    }
    else {
        Write-Log -Level Warning -Message "WhatIf: Would configure DNS with $($Config.Forwarders.Count) forwarders and $($Config.Zones.Count) zones"
    }

    return @{Success=$true; Message="DNS Configuration completed."}
}