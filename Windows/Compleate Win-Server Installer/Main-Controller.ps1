<#
.SYNOPSIS
    Installs ADDS, DHCP, DNS, IIS roles and creates an AD admin user on a remote Windows Server 2022 via WinRM.
.DESCRIPTION
    This script connects to a remote Windows Server 2022 via WinRM and:
    - Installs Active Directory Domain Services (ADDS), promotes to DC if domain name provided
    - Installs DHCP Server
    - Installs DNS Server
    - Installs IIS (Web Server)
    - Creates a new AD administrative user with all permissions if domain is created
.NOTES
    File Name      : Install-ServerRolesWithAdmin.ps1
    Prerequisite   : PowerShell 5.1 or later, WinRM enabled on target server
    Copyright     : (c) 2023, All rights reserved
#>

# Prompt for credentials
$credential = Get-Credential -Message "Enter administrator credentials for the remote server"

# Prompt for server information
$computerName = Read-Host -Prompt "Enter the hostname or IP address of the remote server"
$domainName = Read-Host -Prompt "Enter the domain name to create (e.g., corp.example.com) or leave blank if joining existing domain"
$safeModePassword = Read-Host -Prompt "Enter the Safe Mode Administrator Password (for ADDS installation)" -AsSecureString

# Only ask for admin user details if we're creating a new domain
if (-not [string]::IsNullOrEmpty($domainName)) {
    $adminUsername = Read-Host -Prompt "Enter username for the new AD administrator account"
    $adminPassword = Read-Host -Prompt "Enter password for the new AD administrator account" -AsSecureString
    $adminFullName = Read-Host -Prompt "Enter full name for the new AD administrator account"
    $adminEmail = Read-Host -Prompt "Enter email address for the new AD administrator account (optional)"
}

# Create a new PS session to the remote server
try {
    $session = New-PSSession -ComputerName $computerName -Credential $credential -ErrorAction Stop
    Write-Host "Successfully connected to $computerName" -ForegroundColor Green
}
catch {
    Write-Host "Failed to connect to $computerName : $_" -ForegroundColor Red
    exit
}

# Script block to execute on the remote server
$installScript = {
    param (
        $DomainName,
        $SafeModePassword,
        $AdminUsername,
        $AdminPassword,
        $AdminFullName,
        $AdminEmail
    )

    # Function to check if a role is already installed
    function Test-RoleInstalled {
        param ($RoleName)
        $feature = Get-WindowsFeature -Name $RoleName
        return $feature.Installed
    }

    # Install DNS Server if not already installed
    if (-not (Test-RoleInstalled -RoleName "DNS")) {
        Write-Host "Installing DNS Server..." -ForegroundColor Cyan
        Install-WindowsFeature -Name "DNS" -IncludeManagementTools
        Write-Host "DNS Server installed successfully." -ForegroundColor Green
    } else {
        Write-Host "DNS Server is already installed." -ForegroundColor Yellow
    }

    # Install DHCP Server if not already installed
    if (-not (Test-RoleInstalled -RoleName "DHCP")) {
        Write-Host "Installing DHCP Server..." -ForegroundColor Cyan
        Install-WindowsFeature -Name "DHCP" -IncludeManagementTools
        Write-Host "DHCP Server installed successfully." -ForegroundColor Green
        
        # Add DHCP Server security groups
        Add-DhcpServerSecurityGroup -Verbose
        Write-Host "DHCP security groups configured." -ForegroundColor Green
    } else {
        Write-Host "DHCP Server is already installed." -ForegroundColor Yellow
    }

    # Install IIS if not already installed
    if (-not (Test-RoleInstalled -RoleName "Web-Server")) {
        Write-Host "Installing IIS (Web Server)..." -ForegroundColor Cyan
        Install-WindowsFeature -Name "Web-Server" -IncludeManagementTools
        Write-Host "IIS installed successfully." -ForegroundColor Green
    } else {
        Write-Host "IIS is already installed." -ForegroundColor Yellow
    }

    # Install ADDS if not already installed
    if (-not (Test-RoleInstalled -RoleName "AD-Domain-Services")) {
        Write-Host "Installing Active Directory Domain Services..." -ForegroundColor Cyan
        Install-WindowsFeature -Name "AD-Domain-Services" -IncludeManagementTools
        
        if (-not [string]::IsNullOrEmpty($DomainName)) {
            Write-Host "Promoting server to Domain Controller..." -ForegroundColor Cyan
            
            # Import ADDSDeployment module
            Import-Module ADDSDeployment
            
            # Promote to domain controller
            Install-ADDSForest `
                -DomainName $DomainName `
                -SafeModeAdministratorPassword $SafeModePassword `
                -InstallDns:$true `
                -NoRebootOnCompletion:$false `
                -Force:$true
            
            Write-Host "Server promoted to Domain Controller successfully." -ForegroundColor Green
            
            # Wait for AD services to be fully initialized
            Start-Sleep -Seconds 30
            
            # Create the new admin user
            try {
                Write-Host "Creating new AD administrator account: $AdminUsername" -ForegroundColor Cyan
                
                # Convert secure string to plain text for AD user creation
                $adminPasswordText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdminPassword)
                )
                
                # Create organizational unit for admin accounts if it doesn't exist
                $ouName = "AdminAccounts"
                $ouPath = "OU=$ouName,DC=$($DomainName.Split('.')[0]),DC=$($DomainName.Split('.')[1])"
                
                if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ouName'" -ErrorAction SilentlyContinue)) {
                    New-ADOrganizationalUnit -Name $ouName -ProtectedFromAccidentalDeletion $true
                    Write-Host "Created AdminAccounts OU." -ForegroundColor Green
                }
                
                # Create the user
                $userParams = @{
                    SamAccountName = $AdminUsername
                    Name = $AdminFullName
                    GivenName = $AdminFullName.Split(' ')[0]
                    Surname = $AdminFullName.Split(' ')[-1]
                    DisplayName = $AdminFullName
                    UserPrincipalName = "$AdminUsername@$DomainName"
                    EmailAddress = $AdminEmail
                    Path = $ouPath
                    AccountPassword = ConvertTo-SecureString $adminPasswordText -AsPlainText -Force
                    Enabled = $true
                    PasswordNeverExpires = $true
                    ChangePasswordAtLogon = $false
                }
                
                New-ADUser @userParams
                Write-Host "User $AdminUsername created successfully." -ForegroundColor Green
                
                # Add user to Domain Admins, Enterprise Admins, and Schema Admins groups
                Add-ADGroupMember -Identity "Domain Admins" -Members $AdminUsername
                Add-ADGroupMember -Identity "Enterprise Admins" -Members $AdminUsername
                Add-ADGroupMember -Identity "Schema Admins" -Members $AdminUsername
                Add-ADGroupMember -Identity "Administrators" -Members $AdminUsername
                
                Write-Host "User $AdminUsername added to all administrative groups." -ForegroundColor Green
                
                # Clear the plain text password from memory
                $adminPasswordText = $null
                [GC]::Collect()
                
            } catch {
                Write-Host "Error creating admin user: $_" -ForegroundColor Red
            }
        } else {
            Write-Host "ADDS installed but not configured (no domain name provided)." -ForegroundColor Yellow
        }
    } else {
        Write-Host "ADDS is already installed." -ForegroundColor Yellow
    }

    # Final message
    Write-Host "All requested roles have been processed." -ForegroundColor Green
    Write-Host "A server restart may be required for all changes to take effect." -ForegroundColor Yellow
}

# Execute the script block on the remote server
try {
    $scriptParams = @{
        DomainName = $domainName
        SafeModePassword = $safeModePassword
    }
    
    if (-not [string]::IsNullOrEmpty($domainName)) {
        $scriptParams.Add("AdminUsername", $adminUsername)
        $scriptParams.Add("AdminPassword", $adminPassword)
        $scriptParams.Add("AdminFullName", $adminFullName)
        $scriptParams.Add("AdminEmail", $adminEmail)
    }
    
    Invoke-Command -Session $session -ScriptBlock $installScript -ArgumentList $scriptParams.Values
    Write-Host "Installation completed successfully." -ForegroundColor Green
}
catch {
    Write-Host "Error during installation: $_" -ForegroundColor Red
}
finally {
    # Clean up the session
    if ($session) {
        Remove-PSSession -Session $session
    }
}

# Restart reminder
Write-Host "If any roles were installed, please restart the server when possible." -ForegroundColor Yellow
