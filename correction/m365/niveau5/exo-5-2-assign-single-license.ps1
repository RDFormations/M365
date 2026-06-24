Import-Module (Join-Path $PSScriptRoot '..\lib\M365.ImportHelpers.psm1') -Force

$root  = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$csv   = Join-Path $root 'data\attribution-licences.csv'
$ligne = Import-Csv $csv | Select-Object -First 1

Connect-M365Tenant -Scopes @('User.ReadWrite.All', 'Organization.Read.All')

$user  = Get-MgUserByUpn $ligne.UserPrincipalName
$skuId = Get-SkuId $ligne.SkuPartNumber

$params = @{
    UserId         = $user.Id
    AddLicenses    = @(@{ SkuId = $skuId })
    RemoveLicenses = @()
}

Set-MgUserLicense @params
Write-Host "Licence $($ligne.SkuPartNumber) assignée à $($ligne.UserPrincipalName)" -ForegroundColor Green
