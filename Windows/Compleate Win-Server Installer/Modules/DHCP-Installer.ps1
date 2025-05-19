<#
.SYNOPSIS
    DHCP Server Deployment Module v2.1
.NOTES
    Version: 2.1.0
#>

param (
    [hashtable]$Config,
    [switch]$WhatIf
)

# Import logging
. .\Logging.ps1

try {
    Write-Log -Level Info -Message "Starting DHCP server configuration"

    # Install DHCP role if needed
    if (-not (Get-WindowsFeature -Name DHCP).Installed) {
        Write-Log -Level Info -Message "Installing DHCP server role"
        if (-not $WhatIf) {
            Install-WindowsFeature -Name DHCP -IncludeManagementTools
            Add-DhcpServerSecurityGroup | Out-Null
        }
    }

    if (-not $WhatIf) {
        # Authorize in AD if needed
        if (-not (Get-DhcpServerInDC -ErrorAction SilentlyContinue)) {
            Write-Log -Level Info -Message "Authorizing DHCP server in Active Directory"
            Add-DhcpServerInDC
        }

        # Configure scopes
        foreach ($scope in $Config.Scopes) {
            if (-not (Get-DhcpServerv4Scope -ScopeId $scope.Subnet -ErrorAction SilentlyContinue)) {
                Write-Log -Level Info -Message "Creating DHCP scope: $($scope.Name)"
                
                $scopeParams = @{
                    Name = $scope.Name
                    StartRange = $scope.StartRange
                    EndRange = $scope.EndRange
                    SubnetMask = $scope.SubnetMask
                    LeaseDuration = (New-TimeSpan -Days $scope.LeaseDays)
                }
                Add-DhcpServerv4Scope @scopeParams

                # Set scope options
                if ($scope.Options) {
                    Write-Log -Level Info -Message "Setting DHCP options for scope $($scope.Name)"
                    Set-DhcpServerv4OptionValue -ScopeId $scope.Subnet `
                        -Router $scope.Options.Router `
                        -DnsServer $scope.Options.DnsServers `
                        -DnsDomain $scope.Options.DomainName
                }
            }
        }
    }
    else {
        Write-Log -Level Warning -Message "WhatIf: Would configure $($Config.Scopes.Count) DHCP scopes"
    }

    return @{Success=$true; Message="DHCP configuration completed"}
}
catch {
    Write-Log -Level Error -Message "DHCP configuration failed: $_"
    return @{Success=$false; Message=$_}
}