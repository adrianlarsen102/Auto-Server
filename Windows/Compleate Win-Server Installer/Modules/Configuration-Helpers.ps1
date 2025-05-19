<#
.SYNOPSIS
    Configuration and deployment utilities v2.0
#>

function Invoke-RemoteInstallation {
    param (
        [string]$ServerName,
        [pscredential]$Credential,
        [string]$ScriptPath,
        [hashtable]$Arguments,
        [int]$RetryCount = 3
    )

    $attemopt = 0
    $success = $false

    while (-not $success -and $attempt -lt $RetryCount) {
        $attempt++
        try {
            Write-Log -Level Verbose -Message "Attempt $attempt Connecting to $ServerName"

            $sessionParams = @{
                ComputerName = $ServerName
                Credential = $Credential
                ErrorAction = 'Stop'
            }

            $session = New-PSSession @sessionParams

            $invokeParams = @{
                Session = $session
                FilePath = $ScriptPath
                ArgumentList = $Arguments
            }

            $result = Invoke-Command @invokeParams
            Remove-PSSession $session

            if (-not $result.Success) {
                throw $result.Message
            }

            $success = $true
            Write-Log -Level Info -Message "Remote execution successful on $ServerName"
        }
        catch {
            Write-Log -Level Warning -Message "Attempt $attempt failed: $_"
            if ($attempt -lt $RetryCount) {
                Start-Sleep -Seconds 5
            }
            else {
                throw "All retry attempts failed for $ServerName"
            }
        }
    }

    return $result
}

function Test-DeploymentPrerequisites {
    param (
        [string[]]$Servers,
        [pscredential]$Credential
    )

    $results = @()
    foreach ($Server in $Servers) {
        try {
            $os = Invoke-Command -ComputerName $server -Credential $Credential -ScriptBlock {
                Get-CimInstance -ClassName Win32_OperatingSystem
            }

            $results += [PSCustomObject]@{
                Server = $Server
                OSVersion = $os.Version
                PSVersion = $PSVersionTable.PSVersion
                 WinRMStatus = (Test-WSMan -ComputerName $server -ErrorAction SilentlyContinue) -ne $null
            }
        }
        catch {
            $results += [PSCustomObject]@{
                Server = $Server
                Error = $_.Exception.Message
            }
        }
    }

    return $results
}