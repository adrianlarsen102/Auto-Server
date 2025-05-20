<#
.SYNOPSIS
    IIS Server Deployment Module v2.1
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
    Write-Log -Level Info -Message "Starting IIS configuration"

    # Install IIS if needed
    if (-not (Get-WindowsFeature -Name Web-Server).Installed) {
        Write-Log -Level Info -Message "Installing IIS"
        if (-not $WhatIf) {
            Install-WindowsFeature -Name Web-Server -IncludeManagementTools
        }
    }

    if (-not $WhatIf) {
        # Configure websites
        foreach ($site in $Config.Websites) {
            $siteExists = Get-Website -Name $site.Name -ErrorAction SilentlyContinue
            
            if (-not $siteExists) {
                Write-Log -Level Info -Message "Creating website: $($site.Name)"
                
                # Create physical path
                if (-not (Test-Path $site.PhysicalPath)) {
                    New-Item -ItemType Directory -Path $site.PhysicalPath -Force | Out-Null
                    Write-Log -Level Verbose -Message "Created directory: $($site.PhysicalPath)"
                }

                # Create website
                $websiteParams = @{
                    Name = $site.Name
                    PhysicalPath = $site.PhysicalPath
                    Force = $true
                }

                # Handle bindings
                foreach ($binding in $site.Bindings) {
                    if ($binding.Protocol -eq "https") {
                        if (-not (Test-Path "Cert:\LocalMachine\My\$($binding.CertificateThumbprint)")) {
                            throw "SSL certificate not found: $($binding.CertificateThumbprint)"
                        }
                        $websiteParams += @{
                            Ssl = $true
                            Port = $binding.Port
                            CertificateThumbprint = $binding.CertificateThumbprint
                        }
                    }
                    else {
                        $websiteParams += @{
                            Port = $binding.Port
                        }
                    }
                }

                New-Website @websiteParams
            }
        }
    }
    else {
        Write-Log -Level Warning -Message "WhatIf: Would configure $($Config.Websites.Count) websites"
    }

    return @{Success=$true; Message="IIS configuration completed"}
}
catch {
    Write-Log -Level Error -Message "IIS configuration failed: $_"
    return @{Success=$false; Message=$_}
}