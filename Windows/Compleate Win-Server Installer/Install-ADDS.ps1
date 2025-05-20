param($Config)

$securePass = ConvertTo-SecureString $Config.SafeModePassword -AsPlainText -Force

Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

Install-ADDSForest `
    -DomainName $Config.Domain `
    -SafeModeAdministratorPassword $securePass `
    -InstallDns `
    -Force
