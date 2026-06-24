param(
    [Parameter(Mandatory)]
    [string]$CheminCsv,
    [switch]$WhatIf
)

Import-Module (Join-Path $PSScriptRoot '..\lib\M365.ImportHelpers.psm1') -Force

$root    = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$outDir  = Get-OutputDir $root
$rapport = Join-Path $outDir 'onboarding-rapport.csv'
$logPath = Get-LogPath $root 'onboarding'
$lignesRapport = [System.Collections.Generic.List[object]]::new()

Connect-M365Tenant

foreach ($ligne in Import-Csv $CheminCsv) {
    $upn = $ligne.UserPrincipalName
    $etapes = [System.Collections.Generic.List[string]]::new()

    try {
        if (-not (Test-LigneUtilisateurValide $ligne)) {
            throw ((Get-ValidationRaison $ligne) -join ' ; ')
        }

        # 1. Utilisateur
        if (Test-MgUserExists $upn) {
            $user = Get-MgUserByUpn $upn
            $etapes.Add('user:SKIP')
        }
        elseif ($WhatIf) {
            $etapes.Add('user:WHATIF')
            $user = $null
        }
        else {
            $user = New-MgUser -BodyParameter (New-MgUserBodyFromRow $ligne)
            $etapes.Add('user:OK')
        }

        if (-not $WhatIf -and -not $user) {
            $user = Get-MgUserByUpn $upn
        }

        # 2. Licence
        if ($WhatIf) {
            $etapes.Add("license:WHATIF($($ligne.SkuPartNumber))")
        }
        else {
            $skuId = Get-SkuId $ligne.SkuPartNumber
            Set-MgUserLicense -UserId $user.Id -AddLicenses @(@{ SkuId = $skuId }) -RemoveLicenses @()
            $etapes.Add('license:OK')
        }

        # 3. Groupe
        $groupe = Get-MgGroupByDisplayName $ligne.GroupName
        if (-not $groupe) { throw "Groupe introuvable : $($ligne.GroupName)" }

        if ($WhatIf) {
            $etapes.Add("group:WHATIF($($ligne.GroupName))")
        }
        else {
            $membres = Get-MgGroupMember -GroupId $groupe.Id
            $deja = $membres | Where-Object { $_.Id -eq $user.Id }
            if (-not $deja) {
                New-MgGroupMember -GroupId $groupe.Id -DirectoryObjectId $user.Id
            }
            $etapes.Add('group:OK')
        }

        $statut = if ($WhatIf) { 'WHATIF' } else { 'OK' }
        Write-ImportLog "$upn — $($etapes -join ', ')" $logPath $statut
    }
    catch {
        $statut = "ERREUR: $($_.Exception.Message)"
        Write-ImportLog "$upn — $statut" $logPath ERREUR
    }

    $lignesRapport.Add([pscustomobject]@{
        UserPrincipalName = $upn
        SkuPartNumber     = $ligne.SkuPartNumber
        GroupName         = $ligne.GroupName
        Resultat          = $statut
        Etapes            = ($etapes -join ' | ')
    })
}

$lignesRapport | Export-Csv $rapport -NoTypeInformation -Encoding UTF8
Write-Host "Rapport : $rapport" -ForegroundColor Green
