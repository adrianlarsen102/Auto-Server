# Install the AD DS feature
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Import the ADDSDeployment module
Import-Module ADDSDeployment

# Define variables for the domain configuration
$DomainName = "DystopianTech.Local"  # Replace with your desired domain name
$SafeModePassword = (ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force)  # Replace with a secure password

# Promote the server to a domain controller and create a new forest
Install-ADDSForest `
    -DomainName $DomainName `
    -SafeModeAdministratorPassword $SafeModePassword `
    -Force `
    -InstallDNS

Write-Host "Active Directory Domain Services installation and configuration completed successfully."