Import-Module (Join-Path $PSScriptRoot '..\lib\M365.ImportHelpers.psm1') -Force

$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$csv  = Join-Path $root 'data\nouveaux-utilisateurs.csv'
$ligne = Import-Csv $csv | Select-Object -First 1

Connect-M365Tenant -Scopes @('User.ReadWrite.All')

if (Test-MgUserExists $ligne.UserPrincipalName) {
    Write-Host "SKIP : $($ligne.UserPrincipalName) existe déjà" -ForegroundColor Yellow
    return
}

New-MgUser -BodyParameter (New-MgUserBodyFromRow $ligne)
Write-Host "OK : $($ligne.UserPrincipalName) créé" -ForegroundColor Green
