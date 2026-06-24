Import-Module (Join-Path $PSScriptRoot '..\lib\M365.ImportHelpers.psm1') -Force

$root   = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$outDir = Get-OutputDir $root
$out    = Join-Path $outDir 'sku-inventaire.csv'

Connect-M365Tenant -Scopes @('Organization.Read.All')

Get-MgSubscribedSku -All |
    Select-Object SkuPartNumber, ConsumedUnits,
        @{ N = 'Disponibles'; E = { $_.PrepaidUnits.Enabled - $_.ConsumedUnits } } |
    Export-Csv $out -NoTypeInformation -Encoding UTF8

Write-Host "Export : $out" -ForegroundColor Green
