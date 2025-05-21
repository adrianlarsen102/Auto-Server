. "$PSScriptRoot\utils.ps1"

$serverIP = Read-Host "Enter IP of the Server 2025 Core"
$cred = Get-Credential -Message "Enter admin credentials for $serverIP"
$config = Get-Content "$PSScriptRoot\config.json" | ConvertFrom-Json

Write-Host "`nSelect roles to install (comma-separated):"
Write-Host "1 - DHCP Server"
Write-Host "2 - DNS Server"
Write-Host "3 - IIS (Web Server)"
Write-Host "4 - AD DS (Domain Controller)"
Write-Host "5 - Configure Network Settings"

$choices = (Read-Host "Your choices").Split(",") | ForEach-Object { $_.Trim() }

if ($choices -contains "1") {
    Invoke-RemoteScript -ScriptPath "$PSScriptRoot\Install-DHCP.ps1" -TargetIP $serverIP -Cred $cred -Config $config
}
if ($choices -contains "2") {
    Invoke-RemoteScript -ScriptPath "$PSScriptRoot\Install-DNS.ps1" -TargetIP $serverIP -Cred $cred -Config $config
}
if ($choices -contains "3") {
    Invoke-RemoteScript -ScriptPath "$PSScriptRoot\Install-IIS.ps1" -TargetIP $serverIP -Cred $cred -Config $config
}
if ($choices -contains "4") {
    Invoke-RemoteScript -ScriptPath "$PSScriptRoot\Install-ADDS.ps1" -TargetIP $serverIP -Cred $cred -Config $config
}
if ($choices -contains "5") {
    Invoke-RemoteScript -ScriptPath "$PSScriptRoot\1-NetworkConfig.ps1" -TargetIP $serverIP -Cred $cred -Config $config
    Invoke-RemoteScript -ScriptPath "$PSScriptRoot\2-TimeZone.ps1" -TargetIP $serverIP -Cred $cred -Config $config
}
