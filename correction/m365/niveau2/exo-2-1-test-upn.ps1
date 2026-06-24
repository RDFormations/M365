Import-Module (Join-Path $PSScriptRoot '..\lib\M365.ImportHelpers.psm1') -Force

$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')

@(
    (Join-Path $root 'data\nouveaux-utilisateurs.csv')
    (Join-Path $root 'data\utilisateurs-invalides.csv')
) | ForEach-Object {
    Write-Host "`n=== $_ ===" -ForegroundColor Cyan
    Import-Csv $_ | ForEach-Object {
        $ok = Test-UpnValide $_.UserPrincipalName
        $statut = if ($ok) { 'OK' } else { 'KO' }
        Write-Host ("{0,-35} {1}" -f $_.UserPrincipalName, $statut)
    }
}
