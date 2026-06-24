param(
    [string]$CheminCsv = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')) 'data\attribution-licences.csv'),
    [switch]$WhatIf
)

Import-Module (Join-Path $PSScriptRoot '..\lib\M365.ImportHelpers.psm1') -Force

$root    = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$outDir  = Get-OutputDir $root
$rapport = Join-Path $outDir 'rapport-licences.csv'
$logPath = Get-LogPath $root 'assign-licenses'
$resultats = [System.Collections.Generic.List[object]]::new()

Connect-M365Tenant -Scopes @('User.ReadWrite.All', 'Organization.Read.All')

foreach ($ligne in Import-Csv $CheminCsv) {
    $upn = $ligne.UserPrincipalName
    try {
        if (-not (Test-MgUserExists $upn)) {
            throw "Utilisateur introuvable : $upn"
        }

        $user = Get-MgUserByUpn $upn
        if ([string]::IsNullOrWhiteSpace($user.UsageLocation)) {
            Update-MgUser -UserId $user.Id -UsageLocation 'FR'
            $user = Get-MgUserByUpn $upn
        }
        if ([string]::IsNullOrWhiteSpace($user.UsageLocation)) {
            throw "UsageLocation manquant pour $upn — licence impossible"
        }

        $skuId = Get-SkuId $ligne.SkuPartNumber
        $disabled = @()
        if ($ligne.DisabledPlans) {
            $disabled = $ligne.DisabledPlans -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        }

        if ($WhatIf) {
            Write-ImportLog "WHATIF licence $($ligne.SkuPartNumber) → $upn" $logPath WHATIF
            $resultat = 'WHATIF'
        }
        else {
            Set-MgUserLicense -UserId $user.Id -AddLicenses @(
                @{ SkuId = $skuId; DisabledPlans = $disabled }
            ) -RemoveLicenses @() -ErrorAction Stop
            Write-ImportLog "OK licence $($ligne.SkuPartNumber) → $upn" $logPath OK
            $resultat = 'OK'
        }
    }
    catch {
        $resultat = "ERREUR: $($_.Exception.Message)"
        Write-ImportLog "$upn — $resultat" $logPath ERREUR
    }

    $resultats.Add([pscustomobject]@{
        UserPrincipalName = $upn
        SkuPartNumber     = $ligne.SkuPartNumber
        Resultat          = $resultat
    })
}

$resultats | Export-Csv $rapport -NoTypeInformation -Encoding UTF8
Write-Host "Rapport : $rapport" -ForegroundColor Green
