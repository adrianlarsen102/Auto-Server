# Configure-Network.ps1

# Get all non-virtual, non-loopback adapters (filter out Hyper-V etc.)
$adapters = Get-NetAdapter | Where-Object {
    $_.HardwareInterface -eq $true -and $_.Status -ne "Not Present"
}

if ($adapters.Count -eq 0) {
    Write-Host "No usable network adapters found." -ForegroundColor Red
    exit
}

# Display adapter options
Write-Host "`nAvailable network adapters:`n"
for ($i = 0; $i -lt $adapters.Count; $i++) {
    $adapter = $adapters[$i]
    Write-Host "[$i] $($adapter.Name) - $($adapter.InterfaceDescription) [Status: $($adapter.Status)]"
}

# Ask user to choose one
$choice = Read-Host "Select the adapter number to configure"
if ($choice -notmatch '^\d+$' -or [int]$choice -ge $adapters.Count) {
    Write-Host "Invalid choice." -ForegroundColor Red
    exit
}

$adapter = $adapters[$choice]

# Choose DHCP or static
$mode = Read-Host "Enter 'dhcp' for DHCP or 'static' for static IP"

if ($mode -eq "dhcp") {
    Write-Host "Setting adapter '$($adapter.Name)' to DHCP..."
    Set-NetIPInterface -InterfaceAlias $adapter.Name -Dhcp Enabled -ErrorAction Stop
    Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ResetServerAddresses
    Write-Host "DHCP configuration applied." -ForegroundColor Green
}
elseif ($mode -eq "static") {
    $ipAddress = Read-Host "Enter static IP address (e.g. 192.168.1.100)"
    $subnetMask = Read-Host "Enter subnet mask (e.g. 255.255.255.0)"
    $gateway = Read-Host "Enter default gateway (e.g. 192.168.1.1)"
    $dns = Read-Host "Enter DNS server(s), comma-separated (e.g. 8.8.8.8,8.8.4.4)"

    # Convert subnet mask to prefix length
    function Get-PrefixLength($mask) {
        $binary = ($mask -split '\.') | ForEach-Object {
            [Convert]::ToString($_, 2).PadLeft(8, '0')
        }
        return ($binary -join '').ToCharArray() | Where-Object { $_ -eq '1' } | Measure-Object | Select-Object -ExpandProperty Count
    }

    $prefixLength = Get-PrefixLength $subnetMask

    # Clear existing IPv4 addresses
    Get-NetIPAddress -InterfaceAlias $adapter.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

    # Apply new settings
    New-NetIPAddress -InterfaceAlias $adapter.Name -IPAddress $ipAddress -PrefixLength $prefixLength -DefaultGateway $gateway -ErrorAction Stop
    Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses ($dns -split ',') -ErrorAction Stop

    Write-Host "Static IP configuration applied successfully." -ForegroundColor Green
}
else {
    Write-Host "Invalid input. Please enter 'dhcp' or 'static'." -ForegroundColor Red
    exit
}
