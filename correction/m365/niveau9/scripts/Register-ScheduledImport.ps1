param(
    [string]$ScriptPath = (Join-Path $PSScriptRoot 'Invoke-M365Provisioning.ps1'),
    [string]$TaskName   = 'M365-ImportUsers-Nightly',
    [string]$Heure      = '02:00'
)

$action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument "-NoProfile -File `"$ScriptPath`" -Action Users"
$trigger = New-ScheduledTaskTrigger -Daily -At $Heure
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Description 'Import utilisateurs M365 depuis CSV (lab)'

Write-Host @"
Tâche planifiée : $TaskName
Heure           : $Heure
Script          : $ScriptPath

Prérequis :
- Compte de service ou SYSTEM avec module Microsoft.Graph installé
- Authentification : certificat ou secret stocké (Connect-MgGraph -ClientId ...)
- Ne pas utiliser en production sans revue sécurité
"@ -ForegroundColor Cyan
