Import-Module (Join-Path $PSScriptRoot '..\lib\M365.ImportHelpers.psm1') -Force

$root   = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$outDir = Get-OutputDir $root
$out    = Join-Path $outDir 'mfa-status.csv'

Connect-M365Tenant -Scopes @('User.Read.All', 'UserAuthenticationMethod.Read.All')

$rapport = foreach ($user in Get-MgUser -Filter "accountEnabled eq true" -All) {
    $methodes = Get-MgUserAuthenticationMethod -UserId $user.Id -ErrorAction SilentlyContinue
    $noms = @($methodes | ForEach-Object { $_.AdditionalProperties.'@odata.type' } | ForEach-Object {
        $_ -replace '#microsoft.graph.', ''
    })
    $mfa = $noms | Where-Object { $_ -notmatch 'passwordAuthenticationMethod' }

    [pscustomobject]@{
        UPN           = $user.UserPrincipalName
        MfaEnregistre = if ($mfa) { 'Oui' } else { 'Non' }
        Methodes      = ($noms -join '; ')
    }
}

$rapport | Export-Csv $out -NoTypeInformation -Encoding UTF8
$rapport | Where-Object MfaEnregistre -EQ 'Non' | Format-Table -AutoSize
Write-Host "Export : $out" -ForegroundColor Green
