$Script:DataRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')

$Script:M365Config = @{
    DataPath = Join-Path $Script:DataRoot 'data-lab'
    LogPath  = Join-Path $Script:DataRoot 'logs'
    Output   = Join-Path $Script:DataRoot 'output'
    Scopes   = @(
        'User.ReadWrite.All'
        'Group.ReadWrite.All'
        'Organization.Read.All'
        'UserAuthenticationMethod.Read.All'
        'RoleManagement.Read.Directory'
    )
    CsvFiles = @{
        Users    = 'nouveaux-utilisateurs.csv'
        Licenses = 'attribution-licences.csv'
        Groups   = 'groupes-securite.csv'
        Members  = 'membres-groupes.csv'
        Offboard = 'departs.csv'
        Onboard  = 'onboarding-complet.csv'
    }
}

function Get-M365CsvPath {
    param([Parameter(Mandatory)][string]$Key)
    Join-Path $M365Config.DataPath $M365Config.CsvFiles[$Key]
}
