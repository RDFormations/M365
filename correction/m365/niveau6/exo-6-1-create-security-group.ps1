Import-Module (Join-Path $PSScriptRoot '..\lib\M365.ImportHelpers.psm1') -Force

$root  = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$csv   = Join-Path $root 'data\groupes-securite.csv'
$ligne = Import-Csv $csv | Where-Object GroupType -EQ 'Security' | Select-Object -First 1

Connect-M365Tenant -Scopes @('Group.ReadWrite.All')

if (Get-MgGroupByDisplayName $ligne.DisplayName) {
    Write-Host "SKIP : groupe $($ligne.DisplayName) existe déjà" -ForegroundColor Yellow
    return
}

New-MgGroup -BodyParameter (New-MgGroupBodyFromRow $ligne)
Write-Host "OK : $($ligne.DisplayName)" -ForegroundColor Green
