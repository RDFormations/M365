$root  = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$csv   = Join-Path $root 'data\attribution-licences.csv'
$outDir = Join-Path $root 'output'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
$out   = Join-Path $outDir 'e3-a-attribuer.csv'

Import-Csv $csv |
    Where-Object SkuPartNumber -EQ 'ENTERPRISEPACK' |
    Export-Csv $out -NoTypeInformation -Encoding UTF8

Write-Host "Export : $out" -ForegroundColor Green
