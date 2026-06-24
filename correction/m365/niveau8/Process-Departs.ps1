param(
    [string]$CheminCsv = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')) 'data\departs.csv'),
    [switch]$WhatIf
)

Import-Module (Join-Path $PSScriptRoot '..\lib\M365.ImportHelpers.psm1') -Force

$root    = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$logPath = Get-LogPath $root 'offboard'

Connect-M365Tenant -Scopes @('User.ReadWrite.All')

foreach ($ligne in Import-Csv $CheminCsv) {
    $upn = $ligne.UserPrincipalName
    try {
        if (-not (Test-MgUserExists $upn)) {
            Write-ImportLog "SKIP $upn — introuvable" $logPath SKIP
            continue
        }

        $user = Get-MgUserByUpn $upn

        if ($ligne.RevoquerSessions -eq 'Oui') {
            if ($WhatIf) {
                Write-ImportLog "WHATIF révoquer sessions $upn" $logPath WHATIF
            }
            else {
                Revoke-MgUserSignInSession -UserId $user.Id | Out-Null
                Write-ImportLog "OK sessions révoquées $upn" $logPath OK
            }
        }

        if ($ligne.BloquerCompte -eq 'Oui') {
            if ($WhatIf) {
                Write-ImportLog "WHATIF bloquer $upn" $logPath WHATIF
            }
            else {
                Update-MgUser -UserId $user.Id -AccountEnabled:$false
                Write-ImportLog "OK compte bloqué $upn ($($ligne.Motif))" $logPath OK
            }
        }
    }
    catch {
        Write-ImportLog "ERREUR $upn : $($_.Exception.Message)" $logPath ERREUR
    }
}
