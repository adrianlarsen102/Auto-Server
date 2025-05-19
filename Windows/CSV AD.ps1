# Prompt for IP address of the remote server
$remoteIP = Read-Host "Enter the IP address of the remote Windows Server 2022"

# Prompt for credentials to connect to remote server
$cred = Get-Credential

# Path to CSV on client
$CsvPath = "C:\Users\stor\Downloads\user_dataAD.csv"
# Path to copy CSV on server
$RemoteCsvPath = "C:\Temp\user_dataAD.csv"

# Create a remote session
$session = New-PSSession -ComputerName $remoteIP -Credential $cred

# Copy the CSV file to the remote server
Copy-Item -Path $CsvPath -Destination $RemoteCsvPath -ToSession $session

# Now run the script, referencing the CSV on the server
Invoke-Command -Session $session -ScriptBlock {
    param($CsvPath)

    function Create-ADUsersFromCSV { # Function to create AD users from CSV
        param (
            [string]$CsvPath, # Path to the CSV file
            [string]$LogPath = "C:\Logs\AD_UserCreation_Log.txt", # Path to the log file
            [string]$DefaultPassword = "Kode1234!", # Default password for new users
            [string]$OU = "OU=Brugere,DC=DystopianTech,DC=Local" # Organizational Unit for new users
        )
        $securePassword = ConvertTo-SecureString $DefaultPassword -AsPlainText -Force # Convert password to secure string
        if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) { # Check if Active Directory module is available
            Write-Error "Active Directory module is not available. Please install RSAT: Active Directory tools." # Error message
            exit # script lukker hvis modulet ikke er tilgængeligt
        }
        Import-Module ActiveDirectory # Importere Active Directory modulet
        if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
            Write-Error "This script must be run as an administrator." # Error message
            exit
        }
        if (-not (Test-Path $CsvPath)) { # Tjekker om CSV filen findes
            Write-Error "CSV file not found at path: $CsvPath"
            exit
        }
        "User creation log - $(Get-Date)" | Out-File -FilePath $LogPath # Log filen oprettes
        Import-Csv $CsvPath | ForEach-Object { 
            try {
                $userPrincipalName = "$($_.UserName)@asa.com"
                New-ADUser `
                    -Name $_.FullName `
                    -GivenName $_.FirstName `
                    -Surname $_.LastName `
                    -Initials $_.Initials `
                    -SamAccountName $_.UserName `
                    -UserPrincipalName $userPrincipalName `
                    -AccountPassword $securePassword `
                    -Path $OU `
                    -Enabled $true `
                    -ChangePasswordAtLogon $true `
                    -Department $_.Department `
                    -Title $_.Title
                "SUCCESS: Created user $($_.UserName) - $userPrincipalName" | Out-File -FilePath $LogPath -Append
            } catch {
                "ERROR: Could not create user $($_.UserName) - $_" | Out-File -FilePath $LogPath -Append
            }
        }
    }

    # Use the CsvPath from param, not $using:
    Create-ADUsersFromCSV -CsvPath $CsvPath

} -ArgumentList $RemoteCsvPath