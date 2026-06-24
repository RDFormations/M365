param(
    [string]$CheminCsv = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')) 'data-lab\nouveaux-utilisateurs.csv'),
    [switch]$WhatIf
)

Import-Module (Join-Path $PSScriptRoot '..\lib\M365.ImportHelpers.psm1') -Force

$root    = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$logPath = Get-LogPath $root 'import-users'

Connect-M365Tenant -Scopes @('User.ReadWrite.All')

$stats = Invoke-SafePerLine -Items (Import-Csv $CheminCsv) -LogPath $logPath -Action {
    param($ligne)

    if (-not (Test-LigneUtilisateurValide $ligne)) {
        $r = (Get-ValidationRaison $ligne) -join ' ; '
        Write-ImportLog "REJET $($ligne.UserPrincipalName) : $r" $logPath ERREUR
        return 'ERREUR'
    }

    if (Test-MgUserExists $ligne.UserPrincipalName) {
        Write-ImportLog "SKIP $($ligne.UserPrincipalName)" $logPath SKIP
        return 'SKIP'
    }

    if ($WhatIf) {
        Write-ImportLog "WHATIF créer $($ligne.UserPrincipalName)" $logPath WHATIF
        return 'WHATIF'
    }

    New-MgUser -BodyParameter (New-MgUserBodyFromRow $ligne) | Out-Null
    Write-ImportLog "OK $($ligne.UserPrincipalName)" $logPath OK
    return 'OK'
}

Write-Host "`nRésumé : OK=$($stats.OK) SKIP=$($stats.SKIP) ERREUR=$($stats.ERREUR) WHATIF=$($stats.WHATIF)" -ForegroundColor Cyan
