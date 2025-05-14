Import-Module ActiveDirectory

$csvPath = "C:\Scripts\users.csv"
$logFile = "C:\Logs\user_creation_log.txt"

if (!(Test-Path $logFile)) {
    New-Item -Path $logFile -ItemType File -Force
}

Import-Csv $csvPath | ForEach-Object {
    $name = $_.FullName
    $username = $_.UserName
    $password = (ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force)

    try {
        New-ADUser -Name $name `
                   -GivenName $_.FirstName `
                   -Surname $_.LastName `
                   -SamAccountName $username `
                   -UserPrincipalName "$username@dystopiantech.local" `
                   -AccountPassword $password `
                   -Enabled $true `
                   -Path "OU=Employees,DC=dystopiantech,DC=local"
        Add-Content $logFile "$(Get-Date -Format u): SUCCESS - $username oprettet."
    } catch {
        Add-Content $logFile "$(Get-Date -Format u): ERROR - $username kunne ikke oprettes. $_"
    }
}