function Invoke-RemoteScript {
    param (
        [string]$ScriptPath,
        [string]$TargetIP,
        [PSCredential]$Cred,
        [psobject]$Config
    )

    $scriptBlock = Get-Content $ScriptPath -Raw
    Invoke-Command -ComputerName $TargetIP `
                   -Credential $Cred `
                   -ScriptBlock ([ScriptBlock]::Create($scriptBlock)) `
                   -ArgumentList $Config
}
