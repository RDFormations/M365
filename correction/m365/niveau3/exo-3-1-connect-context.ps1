Import-Module (Join-Path $PSScriptRoot '..\lib\M365.ImportHelpers.psm1') -Force

$ctx = Connect-M365Tenant -Scopes @('Organization.Read.All', 'User.Read.All')

[pscustomobject]@{
    TenantId = $ctx.TenantId
    Account  = $ctx.Account
    Scopes   = $ctx.Scopes -join ', '
} | Format-List
