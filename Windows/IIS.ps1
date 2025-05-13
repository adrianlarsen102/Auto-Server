# Install IIS on Windows Server 2022
Write-Host "Starting IIS installation on Windows Server 2022..."

# Install the Web Server (IIS) role with management tools
Install-WindowsFeature -Name Web-Server -IncludeManagementTools -Verbose

# Check if IIS was installed successfully
if ((Get-WindowsFeature -Name Web-Server).InstallState -eq 'Installed') {
    Write-Host "IIS installation completed successfully."
} else {
    Write-Host "IIS installation failed. Please check for errors."
}

# Enable the default website
Write-Host "Enabling the default website..."
Set-ItemProperty -Path "IIS:\Sites\Default Web Site" -Name "state" -Value "Started"

# Check if the default website was started successfully
if ((Get-ItemProperty -Path "IIS:\Sites\Default Web Site").state -eq 'Started') {
    Write-Host "Default website started successfully."
} else {
    Write-Host "Failed to start the default website. Please check for errors."
}