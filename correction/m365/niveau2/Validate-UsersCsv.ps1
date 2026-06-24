param(
    [Parameter(Mandatory)]
    [string]$CheminCsv
)

Import-Module (Join-Path $PSScriptRoot '..\lib\M365.ImportHelpers.psm1') -Force

$root   = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$outDir = Get-OutputDir $root
$rejets = Join-Path $outDir 'rejets-validation.csv'

$lignes   = Import-Csv $CheminCsv
$invalides = foreach ($l in $lignes) {
    $raisons = Get-ValidationRaison $l
    if ($raisons) {
        [pscustomobject]@{
            DisplayName       = $l.DisplayName
            UserPrincipalName = $l.UserPrincipalName
            UsageLocation     = $l.UsageLocation
            TempPassword      = $l.TempPassword
            Raison            = ($raisons -join ' ; ')
        }
    }
}

$nbRejetes = @($invalides).Count
$nbValides = $lignes.Count - $nbRejetes

if ($invalides) {
    $invalides | Export-Csv $rejets -NoTypeInformation -Encoding UTF8
    Write-Host "Rejets exportés : $rejets" -ForegroundColor Yellow
}

Write-Host ("Résumé : {0} valides / {1} rejetées" -f $nbValides, $nbRejetes) -ForegroundColor Cyan
