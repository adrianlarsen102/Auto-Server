Write-Host "=== SYSTEM STATUS FOR $(hostname) ===`n"

Write-Host "-- CPU Usage --"
(Get-WmiObject win32_processor | Measure-Object -Property LoadPercentage -Average).Average | ForEach-Object {
    Write-Host "$_ % used"
}
Write-Host ""

Write-Host "-- Memory Usage --"
$os = Get-WmiObject Win32_OperatingSystem
$total = [math]::Round($os.TotalVisibleMemorySize / 1024, 2)
$free = [math]::Round($os.FreePhysicalMemory / 1024, 2)
Write-Host "Total: $total MB | Free: $free MB"
Write-Host ""

Write-Host "-- Disk Usage --"
Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    $freeGB = [math]::Round($_.FreeSpace / 1GB, 2)
    $sizeGB = [math]::Round($_.Size / 1GB, 2)
    Write-Host "$($_.DeviceID): $freeGB GB free of $sizeGB GB"
}
Write-Host ""

Write-Host "-- Uptime --"
$uptime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
Write-Host "Last boot time: $uptime"