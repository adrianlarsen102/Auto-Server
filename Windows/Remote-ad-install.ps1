# Prompt for IP address of the remote server
$remoteIP = Read-Host "Enter the IP address of the remote Windows Server 2022"

# Prompt for domain name
$domainName = Read-Host "Enter the domain name to create (e.g., corp.example.com)"

# Prompt for DSRM (Directory Services Restore Mode) password
$dsrmPasswordPlain = Read-Host "Enter DSRM password (will be hidden during domain controller setup)"
$safeModePwd = ConvertTo-SecureString $dsrmPasswordPlain -AsPlainText -Force

# Prompt for credentials to connect to remote server
$cred = Get-Credential

# Install AD-Domain-Services feature
Invoke-Command -ComputerName $remoteIP -Credential $cred -ScriptBlock {
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
}

# Promote to Domain Controller
Invoke-Command -ComputerName $remoteIP -Credential $cred -ScriptBlock {
    param (
        $domainNameParam,
        $dsrmPasswordParam
    )

    Import-Module ADDSDeployment

    Install-ADDSForest `
        -DomainName $domainNameParam `
        -SafeModeAdministratorPassword $dsrmPasswordParam `
        -InstallDNS `
        -Force:$true
} -ArgumentList $domainName, $safeModePwd
# Wait for the remote server to finish the promotion
$session = New-PSSession -ComputerName $remoteIP -Credential $cred