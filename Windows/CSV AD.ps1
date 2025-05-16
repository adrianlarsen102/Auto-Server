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

    function Create-ADUsersFromCSV {
        param (
            [string]$CsvPath,
            [string]$LogPath = "C:\Logs\AD_UserCreation_Log.txt",
            [string]$DefaultPassword = "Kode1234!",
            [string]$OU = "OU=Brugere,DC=DystopianTech,DC=Local"
        )
        $securePassword = ConvertTo-SecureString $DefaultPassword -AsPlainText -Force
        if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
            Write-Error "Active Directory module is not available. Please install RSAT: Active Directory tools."
            exit
        }
        Import-Module ActiveDirectory
        if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
            Write-Error "This script must be run as an administrator."
            exit
        }
        if (-not (Test-Path $CsvPath)) {
            Write-Error "CSV file not found at path: $CsvPath"
            exit
        }
        "User creation log - $(Get-Date)" | Out-File -FilePath $LogPath
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