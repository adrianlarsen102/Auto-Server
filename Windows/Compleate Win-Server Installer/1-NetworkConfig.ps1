param($Config)

Rename-Computer -NewName $Config.Hostname -Force

Get-NetAdapter | Set-DnsClientServerAddress -ServerAddresses $Config.DNSServers
