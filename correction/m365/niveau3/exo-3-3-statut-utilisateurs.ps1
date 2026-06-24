param(
    [string]$CheminCsv
)

Import-Module (Join-Path $PSScriptRoot '..\lib\M365.ImportHelpers.psm1') -Force

$root   = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$csv    = if ($CheminCsv) { $CheminCsv } else { Join-Path $root 'data\nouveaux-utilisateurs.csv' }
$outDir = Get-OutputDir $root
$out    = Join-Path $outDir 'statut-utilisateurs.csv'

Connect-M365Tenant -Scopes @('User.Read.All')

$rapport = Import-Csv $csv | ForEach-Object {
    $existe = Test-MgUserExists $_.UserPrincipalName
    [pscustomobject]@{
        UserPrincipalName = $_.UserPrincipalName
        Statut            = if ($existe) { 'Existe' } else { 'A creer' }
    }
}

$rapport | Export-Csv $out -NoTypeInformation -Encoding UTF8
$rapport | Format-Table -AutoSize
Write-Host "Export : $out" -ForegroundColor Green
