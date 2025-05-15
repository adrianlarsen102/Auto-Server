# Scriptindstillinger
$csvPath = "C:\Scripts\brugere.csv"         #  stien til CSV-filen
$logPath = "C:\Scripts\opret_brugere_log.txt"
$ouPath = "user,asa,com" #  din OU og domænestruktur
$defaultPassword = "Kode1234!!"            # Standard adgangskode

# Importér CSV
$brugere = Import-Csv -Path $csvPath

# Start log
Add-Content -Path $logPath -Value "==== Log for brugeroprettelse $(Get-Date) ===="

# Opret brugere
foreach ($bruger in $brugere) {
    $userPrincipalName = "$($bruger.'User Name')@ditdomæne.local"
    $samAccountName = $bruger.'User Name'
    $fullName = $bruger.'Full Name'

    try {
        New-ADUser `
            -Name $fullName `
            -GivenName $bruger.'First Name' `
            -Surname $bruger.'Last Name' `
            -Initials $bruger.'Initials' `
            -UserPrincipalName $userPrincipalName `
            -SamAccountName $samAccountName `
            -AccountPassword (ConvertTo-SecureString $defaultPassword -AsPlainText -Force) `
            -Enabled $true `
            -Path $ouPath `
            -ChangePasswordAtLogon $true `
            -Verbose

        Add-Content -Path $logPath -Value "burger hermed Oprettet: $fullName ($samAccountName)"
    } catch {
        Add-Content -Path $logPath -Value "FEJL med burger: $fullName ($samAccountName): $_"
    }
}
