$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$csv  = Join-Path $root 'data\nouveaux-utilisateurs.csv'

Import-Csv $csv |
    Group-Object Department |
    ForEach-Object { "{0} : {1}" -f $_.Name, $_.Count }
