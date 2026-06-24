Import-Module (Join-Path $PSScriptRoot '..\lib\M365.ImportHelpers.psm1') -Force

$root   = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$outDir = Get-OutputDir $root
$out    = Join-Path $outDir 'admins-sans-mfa.csv'

Connect-M365Tenant -Scopes @(
    'User.Read.All', 'UserAuthenticationMethod.Read.All', 'RoleManagement.Read.Directory'
)

$adminUpns = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

Get-MgDirectoryRole -All | ForEach-Object {
    Get-MgDirectoryRoleMember -DirectoryRoleId $_.Id -All | ForEach-Object {
        if ($_.AdditionalProperties.userPrincipalName) {
            [void]$adminUpns.Add($_.AdditionalProperties.userPrincipalName)
        }
    }
}

$rapport = foreach ($upn in $adminUpns) {
    $user = Get-MgUserByUpn $upn
    $methodes = Get-MgUserAuthenticationMethod -UserId $user.Id -ErrorAction SilentlyContinue
    $types = @($methodes | ForEach-Object { $_.AdditionalProperties.'@odata.type' })
    $mfa = $types | Where-Object { $_ -notmatch 'passwordAuthenticationMethod' }

    [pscustomobject]@{
        UPN           = $upn
        MfaEnregistre = if ($mfa) { 'Oui' } else { 'Non' }
        Methodes      = (($types -replace '#microsoft.graph.', '') -join '; ')
    }
}

$rapport | Where-Object MfaEnregistre -EQ 'Non' |
    Export-Csv $out -NoTypeInformation -Encoding UTF8

$rapport | Where-Object MfaEnregistre -EQ 'Non' | Format-Table -AutoSize
Write-Host "Export admins sans MFA : $out" -ForegroundColor Yellow
