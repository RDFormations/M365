$upns = @(
    'tp.import.test01@redstoneformations.fr'
    'tp.import.test02@redstoneformations.fr'
    'tp.onboard.test@redstoneformations.fr'
)
$rows = foreach ($u in $upns) {
    $x = Get-MgUser -Filter "userPrincipalName eq '$u'" -Property DisplayName, AccountEnabled, UsageLocation -ErrorAction SilentlyContinue
    if ($x) {
        [pscustomobject]@{ UPN = $x.UserPrincipalName; Actif = $x.AccountEnabled; Pays = $x.UsageLocation }
    }
    else {
        [pscustomobject]@{ UPN = $u; Actif = '-'; Pays = 'introuvable' }
    }
}
$rows | Format-Table -AutoSize

$g = Get-MgGroup -Filter "displayName eq 'TP-LAB-Securite'" -ErrorAction SilentlyContinue
if ($g) {
    $count = (Get-MgGroupMember -GroupId $g.Id -All).Count
    Write-Host "Groupe TP-LAB-Securite : $count membres"
}
