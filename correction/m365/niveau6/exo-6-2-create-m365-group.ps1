Import-Module (Join-Path $PSScriptRoot '..\lib\M365.ImportHelpers.psm1') -Force

$root  = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$csv   = Join-Path $root 'data\groupes-securite.csv'
$ligne = Import-Csv $csv | Where-Object DisplayName -EQ 'TEAM-Projet-Migration'

Connect-M365Tenant -Scopes @('Group.ReadWrite.All')

if (Get-MgGroupByDisplayName $ligne.DisplayName) {
    Write-Host "SKIP : $($ligne.DisplayName)" -ForegroundColor Yellow
    return
}

New-MgGroup -BodyParameter (New-MgGroupBodyFromRow $ligne)
Write-Host "OK : $($ligne.DisplayName)" -ForegroundColor Green
