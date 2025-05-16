param (
    [string]$ServerName = "10.14.2.87"
)

$remoteScript = {
    $results = @()

    $results += "=== SYSTEM STATUS FOR $($env:COMPUTERNAME) ===`n"

    # CPU Usage
    $cpuLoad = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
    $results += "-- CPU Usage --"
    $results += "$cpuLoad % used`n"

    # Memory Usage
    $os = Get-CimInstance Win32_OperatingSystem
    $totalMem = [math]::Round($os.TotalVisibleMemorySize / 1024, 2)
    $freeMem = [math]::Round($os.FreePhysicalMemory / 1024, 2)
    $results += "-- Memory Usage --"
    $results += "Total: $totalMem MB | Free: $freeMem MB`n"

    # Disk Usage
    $results += "-- Disk Usage --"
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
        $free = [math]::Round($_.FreeSpace / 1GB, 2)
        $size = [math]::Round($_.Size / 1GB, 2)
        $results += "$($_.DeviceID): $free GB free of $size GB"
    }
    $results += ""

    # Uptime
    $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $results += "-- Uptime --"
    $results += "Last boot time: $boot"

    $results -join "`n"
}

Invoke-Command -ComputerName $ServerName -Credential (Get-Credential) -ScriptBlock $remoteScript
