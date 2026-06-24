$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$csv  = Join-Path $root 'data\nouveaux-utilisateurs.csv'

Import-Csv $csv |
    Select-Object DisplayName, Department, UserPrincipalName |
    Format-Table -AutoSize
