# Exécution bout en bout — correction M365
$ErrorActionPreference = 'Continue'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$corr = Join-Path $root 'correction/m365'
$logFile = Join-Path $root "logs/run-all-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Log($msg, $color = 'White') {
    $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $msg
    Add-Content $logFile $line
    Write-Host $line -ForegroundColor $color
}

New-Item -ItemType Directory -Path (Split-Path $logFile) -Force | Out-Null
Log "=== RUN ALL — début ===" Cyan

$steps = @(
    @{ Name = '1.1 inventaire';           Script = Join-Path $corr 'niveau1/exo-1-1-inventaire.ps1' }
    @{ Name = '1.2 comptage';             Script = Join-Path $corr 'niveau1/exo-1-2-comptage-departement.ps1' }
    @{ Name = '1.3 filtre E3';            Script = Join-Path $corr 'niveau1/exo-1-3-filtrer-licences-e3.ps1' }
    @{ Name = '2.1 test UPN';             Script = Join-Path $corr 'niveau2/exo-2-1-test-upn.ps1' }
    @{ Name = '2.3 validation invalides'; Script = Join-Path $corr 'niveau2/Validate-UsersCsv.ps1'; Args = @{ CheminCsv = Join-Path $root 'data-lab/utilisateurs-invalides.csv' } }
    @{ Name = '3.1 connect';              Script = Join-Path $corr 'niveau3/exo-3-1-connect-context.ps1' }
    @{ Name = '3.2 SKU';                  Script = Join-Path $corr 'niveau3/exo-3-2-inventaire-sku.ps1' }
    @{ Name = '3.3 statut';               Script = Join-Path $corr 'niveau3/exo-3-3-statut-utilisateurs.ps1'; Args = @{ CheminCsv = Join-Path $root 'data-lab/nouveaux-utilisateurs.csv' } }
)

# Patch 3.3 to accept custom csv - actually 3.3 hardcodes path. Run as-is with contoso or we need to fix 3.3

$results = [System.Collections.Generic.List[object]]::new()

foreach ($s in $steps) {
    Log "--- $($s.Name) ---" Yellow
    try {
        if ($s.Args) {
            $scriptArgs = $s.Args
            $out = & $s.Script @scriptArgs 2>&1 | Out-String
        } else {
            $out = & $s.Script 2>&1 | Out-String
        }
        $last = ($out -split "`n" | Where-Object { $_.Trim() } | Select-Object -Last 3) -join ' | '
        Log "OK — $last" Green
        $results.Add([pscustomobject]@{ Etape = $s.Name; Statut = 'OK'; Detail = $last })
    }
    catch {
        Log "ERREUR — $($_.Exception.Message)" Red
        $results.Add([pscustomobject]@{ Etape = $s.Name; Statut = 'ERREUR'; Detail = $_.Exception.Message })
    }
}

Log "=== LAB E2E — Invoke-M365Provisioning All ===" Cyan
$orch = Join-Path $corr 'niveau9/scripts/Invoke-M365Provisioning.ps1'
try {
    $out = & $orch -Action All -DataPath (Join-Path $root 'data-lab') 2>&1 | Out-String
    $last = ($out -split "`n" | Where-Object { $_ -match 'OK|ERREUR|SKIP|Résumé|Terminé|Rapport' } | Select-Object -Last 15) -join "`n"
    Log $last Green
    $results.Add([pscustomobject]@{ Etape = '9 orchestrateur All'; Statut = 'OK'; Detail = ($last -replace "`n", ' ') })
}
catch {
    Log "ERREUR orchestrateur — $($_.Exception.Message)" Red
    $results.Add([pscustomobject]@{ Etape = '9 orchestrateur All'; Statut = 'ERREUR'; Detail = $_.Exception.Message })
}

Log "=== Onboarding capstone ===" Cyan
try {
    $out = & (Join-Path $corr 'niveau7/New-OnboardingUser.ps1') -CheminCsv (Join-Path $root 'data-lab/onboarding-complet.csv') 2>&1 | Out-String
    $last = ($out -split "`n" | Select-Object -Last 5) -join ' | '
    Log "OK — $last" Green
    $results.Add([pscustomobject]@{ Etape = '7 onboarding'; Statut = 'OK'; Detail = $last })
}
catch {
    Log "ERREUR — $($_.Exception.Message)" Red
    $results.Add([pscustomobject]@{ Etape = '7 onboarding'; Statut = 'ERREUR'; Detail = $_.Exception.Message })
}

Log "=== Offboard ===" Cyan
try {
    $out = & (Join-Path $corr 'niveau8/Process-Departs.ps1') -CheminCsv (Join-Path $root 'data-lab/departs.csv') 2>&1 | Out-String
    $last = ($out -split "`n" | Select-Object -Last 5) -join ' | '
    Log "OK — $last" Green
    $results.Add([pscustomobject]@{ Etape = '8 offboard'; Statut = 'OK'; Detail = $last })
}
catch {
    Log "ERREUR — $($_.Exception.Message)" Red
    $results.Add([pscustomobject]@{ Etape = '8 offboard'; Statut = 'ERREUR'; Detail = $_.Exception.Message })
}

Log "=== MFA audit (lecture) ===" Cyan
try {
    $out = & (Join-Path $corr 'niveau8/Export-MfaStatus.ps1') 2>&1 | Out-String
    $last = ($out -split "`n" | Select-Object -Last 3) -join ' | '
    Log "OK — $last" Green
    $results.Add([pscustomobject]@{ Etape = '8.3 MFA status'; Statut = 'OK'; Detail = $last })
}
catch {
    Log "ERREUR — $($_.Exception.Message)" Red
    $results.Add([pscustomobject]@{ Etape = '8.3 MFA status'; Statut = 'ERREUR'; Detail = $_.Exception.Message })
}

Log "=== RÉSUMÉ ===" Cyan
$results | Format-Table -AutoSize
$results | Export-Csv (Join-Path $root 'output/run-all-resultats.csv') -NoTypeInformation -Encoding UTF8
Log "Log complet : $logFile" Cyan
Log "=== FIN ===" Cyan
