# make the notes en danish language

<#
.SYNOPSIS
    Imports users from a CSV file to Active Directory with full logging capabilities.
.DESCRIPTION
    This script creates AD users from a CSV file using WinRM, with detailed logging to both console and log file.
.VERSION
    1.0.4
.NOTES
    File Name      : Import-UsersFromCsvToAD-WithLogging.ps1
    Prerequisite   : PowerShell 5.1+, Active Directory module, WinRM enabled
    CSV Format     : Should include: FirstName,LastName,Username,Password,OU,Department,Title,Email
#>

# Script version
${SCRIPT_VERSION} = "1.0.4"

#region Initialization
Clear-Host # Ryder kosollen
${scriptStartTime} = Get-Date # Start tiden
${logFolder} = "C:\Logs\ADUserImport" # Stien til logfiler
${logFileName} = "ADUserImport_$(${scriptStartTime}.ToString('yyyyMMdd_HHmmss')).log" # Navn på logfilen
${logFilePath} = Join-Path -Path ${logFolder} -ChildPath ${logFileName} #

# Create log directory if it doesn't exist
if (-not (Test-Path -Path ${logFolder})) { # Tjekker om logmappen findes
    New-Item -ItemType Directory -Path ${logFolder} | Out-Null # Opretter logmappen
}

# Function for unified logging
function Write-Log { # Funktion til logning
    param ( # Parametre til logning
        [string]${Message}, # Log besked
        [string]${Level} = "INFO", # Log niveau (INFO, WARN, ERROR, DEBUG)
        [switch]${ConsoleOutput} = $true # Om log beskeden skal vises i konsollen
    )
    
    ${timestamp} = Get-Date -Format "yyyy-MM-dd HH:mm:ss" # Tidsstempel
    ${logEntry} = "[${timestamp}] [${Level}] ${Message}" # Log besked format
    
    # Write to log file
    ${logEntry} | Out-File -FilePath ${logFilePath} -Append # Skriver log besked til filen
    
    # Write to console if requested
    if (${ConsoleOutput}) { # Hvis konsol output er aktiveret
        switch (${Level}) { # Viser log besked i konsollen
            "ERROR" { Write-Host ${logEntry} -ForegroundColor Red } # Fejl
            "WARN"  { Write-Host ${logEntry} -ForegroundColor Yellow } # Advarsel
            "INFO"  { Write-Host ${logEntry} -ForegroundColor Green } # Information
            "DEBUG" { Write-Host ${logEntry} -ForegroundColor Gray } # Debug
            default { Write-Host ${logEntry} } # Standard
        }
    }
}

# Log script start with version information
Write-Log -Message "==============================================" -ConsoleOutput # Separator
Write-Log -Message " Active Directory User Import Tool v${SCRIPT_VERSION}" -ConsoleOutput # Script version
Write-Log -Message " Script started at ${scriptStartTime}" -ConsoleOutput # Start tid
Write-Log -Message " Log file: ${logFilePath}" -ConsoleOutput # Log fil sti
Write-Log -Message "==============================================" -ConsoleOutput # Separator
#endregion

#region User Input
try {
    # Prompt for server information
    ${server} = Read-Host "Enter the Domain Controller IP address or hostname" # Server IP
    if (-not ${server}) { # Tjekker om server IP er angivet
        Write-Log -Message "Server address is required." -Level ERROR -ConsoleOutput # Fejl besked
        exit 1 # Afslutter scriptet
    }
    Write-Log -Message "Target server: ${server}" -ConsoleOutput # Server IP

    # Get credentials
    ${credential} = Get-Credential -Message "Enter your domain administrator credentials" # Henter credentials
    if (-not ${credential}) { # Tjekker om credentials er angivet
        Write-Log -Message "Credentials are required." -Level ERROR -ConsoleOutput # Fejl besked
        exit 1
    }
    Write-Log -Message "Credentials obtained" -Level DEBUG # Konsol output

    # Prompt for CSV file path 
    ${csvPath} = Read-Host "Enter the full path to your CSV file (e.g., C:\Users.csv)"
    if (-not ${csvPath}) {
        Write-Log -Message "CSV file path is required." -Level ERROR -ConsoleOutput
        exit 1
    }
    Write-Log -Message "CSV file path: ${csvPath}" -ConsoleOutput
}
catch {
    Write-Log -Message "Error during user input: $(${_})" -Level ERROR -ConsoleOutput
    exit 1
}
#endregion

#region CSV Validation
try {
    Write-Log -Message "Validating CSV file..." -ConsoleOutput
    if (-not (Test-Path -Path ${csvPath} -PathType Leaf)) {
        throw "CSV file not found at path: ${csvPath}"
    }
    
    ${users} = Import-Csv -Path ${csvPath}
    ${userCount} = ${users}.Count
    Write-Log -Message "Successfully imported ${userCount} user records from CSV" -ConsoleOutput
    
    # Safe debug output of headers (masking passwords)
    ${debugHeaders} = ${users}[0].PSObject.Properties.Name | ForEach-Object {
        if (${_} -eq 'Password') { 'Password[REDACTED]' } else { ${_} }
    }
    Write-Log -Message "CSV headers: $(${debugHeaders} -join ', ')" -Level DEBUG
}
catch {
    Write-Log -Message "CSV validation failed: $(${_})" -Level ERROR -ConsoleOutput
    exit 1
}
#endregion

#region WinRM Session
try {
    Write-Log -Message "Establishing WinRM session to ${server}..." -ConsoleOutput
    ${sessionParams} = @{
        ComputerName = ${server}
        Credential = ${credential}
        SessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
    }
    
    ${session} = New-PSSession @sessionParams -ErrorAction Stop
    Write-Log -Message "Successfully connected to ${server} via WinRM" -ConsoleOutput
    
    # Log AD domain information
    ${domainInfo} = Invoke-Command -Session ${session} -ScriptBlock { Get-ADDomain }
    Write-Log -Message "Connected to domain: $(${domainInfo}.DNSRoot)" -ConsoleOutput
    Write-Log -Message "Domain NetBIOS name: $(${domainInfo}.NetBIOSName)" -Level DEBUG
}
catch {
    Write-Log -Message "WinRM connection failed: $(${_})" -Level ERROR -ConsoleOutput
    exit 1
}
#endregion

#region User Processing
${successCount} = 0
${failCount} = 0
${skippedCount} = 0

Write-Log -Message "Starting user creation process for ${userCount} users..." -ConsoleOutput

foreach (${user} in ${users}) {
    ${currentUser} = ${user}.Username
    try {
        # Validate required fields
        ${requiredFields} = @('FirstName', 'LastName', 'Username', 'Password', 'OU')
        ${missingFields} = ${requiredFields} | Where-Object { -not ${user}.${_} }
        
        if (${missingFields}) {
            ${message} = "User ${currentUser} skipped - missing required fields ($(${missingFields} -join ', '))"
            Write-Log -Message ${message} -Level WARN -ConsoleOutput
            ${skippedCount}++
            continue
        }

        # Prepare user parameters
        ${userParams} = @{
            GivenName = ${user}.FirstName
            Surname = ${user}.LastName
            Name = "$(${user}.FirstName) $(${user}.LastName)"
            DisplayName = "$(${user}.FirstName) $(${user}.LastName)"
            SamAccountName = ${currentUser}
            UserPrincipalName = "${currentUser}@$(${domainInfo}.DNSRoot)"
            Path = ${user}.OU
            Enabled = $true
            AccountPassword = (ConvertTo-SecureString -String ${user}.Password -AsPlainText -Force)
            ChangePasswordAtLogon = $true
            ErrorAction = 'Stop'
        }

        # Add optional fields
        ${optionalFields} = @('Department', 'Title', 'Email', 'Office', 'Phone', 'Mobile')
        foreach (${field} in ${optionalFields}) {
            if (${user}.${field}) { ${userParams}[${field}] = ${user}.${field} }
        }

        Write-Log -Message "Creating user: ${currentUser}..." -Level DEBUG

        # Remote execution block
        ${createUserScript} = {
            param(${userParams})
            try {
                ${newUser} = New-ADUser @userParams -PassThru
                return @{
                    Status = "SUCCESS"
                    Details = "Created user $(${userParams}.SamAccountName) with DN: $(${newUser}.DistinguishedName)"
                }
            }
            catch {
                return @{
                    Status = "FAILED"
                    Details = "Error creating user $(${userParams}.SamAccountName): $(${_})"
                }
            }
        }

        # Execute creation command
        ${result} = Invoke-Command -Session ${session} -ScriptBlock ${createUserScript} -ArgumentList ${userParams}
        
        if (${result}.Status -eq "SUCCESS") {
            ${successCount}++
            Write-Log -Message "Successfully created user: ${currentUser}" -ConsoleOutput
            Write-Log -Message ${result}.Details -Level DEBUG
        } else {
            ${failCount}++
            Write-Log -Message ${result}.Details -Level ERROR -ConsoleOutput
        }
    }
    catch {
        ${failCount}++
        Write-Log -Message "Unexpected error processing user ${currentUser}: $(${_})" -Level ERROR -ConsoleOutput
    }
}
#endregion

#region Cleanup and Reporting
# Close WinRM session
try {
    Remove-PSSession -Session ${session} -ErrorAction Stop
    Write-Log -Message "WinRM session closed successfully" -Level DEBUG
} catch {
    Write-Log -Message "Failed to clean up WinRM session: $(${_})" -Level WARN -ConsoleOutput
}

# Calculate script duration
${scriptEndTime} = Get-Date
${duration} = ${scriptEndTime} - ${scriptStartTime}
${durationString} = "{0:hh\:mm\:ss}" -f ${duration}

# Final report
Write-Log -Message "==============================================" -ConsoleOutput
Write-Log -Message " USER IMPORT SUMMARY (v${SCRIPT_VERSION})" -ConsoleOutput
Write-Log -Message "==============================================" -ConsoleOutput
Write-Log -Message " Start time:          ${scriptStartTime}" -ConsoleOutput
Write-Log -Message " End time:            ${scriptEndTime}" -ConsoleOutput
Write-Log -Message " Duration:            ${durationString}" -ConsoleOutput
Write-Log -Message " Total users in CSV:  ${userCount}" -ConsoleOutput
Write-Log -Message " Successfully created: ${successCount}" -Level INFO -ConsoleOutput
Write-Log -Message " Failed to create:     ${failCount}" -Level ERROR -ConsoleOutput
Write-Log -Message " Skipped (invalid):    ${skippedCount}" -Level WARN -ConsoleOutput
Write-Log -Message " Log file location:    ${logFilePath}" -ConsoleOutput
Write-Log -Message "==============================================" -ConsoleOutput

# Exit with appropriate code
if (${failCount} -gt 0) {
    exit 1
}
exit 0
#endregion