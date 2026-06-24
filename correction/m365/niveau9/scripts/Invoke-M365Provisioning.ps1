param(
    [ValidateSet('Users', 'Licenses', 'Groups', 'Offboard', 'All')]
    [string]$Action = 'All',
    [string]$DataPath,
    [switch]$WhatIf
)

$scriptsRoot = $PSScriptRoot
. (Join-Path $scriptsRoot 'config.ps1')

if ($DataPath) { $M365Config.DataPath = $DataPath }

Import-Module (Join-Path $scriptsRoot '..\..\lib\M365.ImportHelpers.psm1') -Force

$logPath = Get-LogPath $Script:DataRoot "provision-$Action"
Write-ImportLog "Démarrage Action=$Action WhatIf=$WhatIf" $logPath INFO

Connect-M365Tenant -Scopes $M365Config.Scopes

$m365Root = Resolve-Path (Join-Path $scriptsRoot '..\..')

$actions = @{
    Users    = { & (Join-Path $m365Root 'niveau4\Import-Users.ps1') -CheminCsv (Get-M365CsvPath Users) -WhatIf:$WhatIf }
    Licenses = { & (Join-Path $m365Root 'niveau5\Assign-Licenses.ps1') -CheminCsv (Get-M365CsvPath Licenses) -WhatIf:$WhatIf }
    Groups   = {
        & (Join-Path $m365Root 'niveau6\Import-Groups.ps1') `
            -CheminGroupes (Get-M365CsvPath Groups) `
            -CheminMembres (Get-M365CsvPath Members) `
            -WhatIf:$WhatIf
    }
    Offboard = { & (Join-Path $m365Root 'niveau8\Process-Departs.ps1') -CheminCsv (Get-M365CsvPath Offboard) -WhatIf:$WhatIf }
}

$sequence = if ($Action -eq 'All') { @('Users', 'Licenses', 'Groups','Offboard') } else { @($Action) }

foreach ($etape in $sequence) {
    Write-ImportLog "=== Étape $etape ===" $logPath INFO
    & $actions[$etape]
}

Write-ImportLog "Terminé Action=$Action" $logPath INFO
