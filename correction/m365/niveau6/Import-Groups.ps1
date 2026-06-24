param(
    [string]$CheminGroupes = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')) 'data\groupes-securite.csv'),
    [string]$CheminMembres  = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')) 'data\membres-groupes.csv'),
    [switch]$WhatIf
)

Import-Module (Join-Path $PSScriptRoot '..\lib\M365.ImportHelpers.psm1') -Force

$root    = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$logPath = Get-LogPath $root 'import-groups'

Connect-M365Tenant -Scopes @('Group.ReadWrite.All', 'User.Read.All')

# Phase A — groupes
foreach ($g in Import-Csv $CheminGroupes) {
    try {
        if (Get-MgGroupByDisplayName $g.DisplayName) {
            Write-ImportLog "SKIP groupe $($g.DisplayName)" $logPath SKIP
            continue
        }
        if ($WhatIf) {
            Write-ImportLog "WHATIF groupe $($g.DisplayName)" $logPath WHATIF
            continue
        }
        New-MgGroup -BodyParameter (New-MgGroupBodyFromRow $g)
        Write-ImportLog "OK groupe $($g.DisplayName)" $logPath OK
    }
    catch {
        Write-ImportLog "ERREUR groupe $($g.DisplayName) : $($_.Exception.Message)" $logPath ERREUR
    }
}

# Phase B — membres
foreach ($m in Import-Csv $CheminMembres) {
    try {
        $groupe = Get-MgGroupByDisplayName $m.GroupName
        if (-not $groupe) {
            if ($WhatIf) {
                Write-ImportLog "WHATIF membre $($m.MemberUPN) → $($m.GroupName)" $logPath WHATIF
                continue
            }
            throw "Groupe introuvable : $($m.GroupName)"
        }

        $user = Get-MgUserByUpn $m.MemberUPN
        $membreIds = @(Get-MgGroupMember -GroupId $groupe.Id -All | Select-Object -ExpandProperty Id)
        if ($membreIds -contains $user.Id) {
            Write-ImportLog "SKIP membre $($m.MemberUPN) → $($m.GroupName)" $logPath SKIP
            continue
        }

        if ($WhatIf) {
            Write-ImportLog "WHATIF membre $($m.MemberUPN) → $($m.GroupName)" $logPath WHATIF
            continue
        }

        New-MgGroupMember -GroupId $groupe.Id -DirectoryObjectId $user.Id
        Write-ImportLog "OK membre $($m.MemberUPN) → $($m.GroupName)" $logPath OK
    }
    catch {
        Write-ImportLog "ERREUR membre $($m.MemberUPN) : $($_.Exception.Message)" $logPath ERREUR
    }
}
