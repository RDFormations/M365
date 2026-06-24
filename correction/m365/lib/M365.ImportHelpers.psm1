function Test-UpnValide {
    param([string]$Upn)
    $Upn -match '^[^@]+@[^@]+\.[^@]+$'
}

function Test-UsageLocationValide {
    param([string]$UsageLocation, [string]$Attendu = 'FR')
    -not [string]::IsNullOrWhiteSpace($UsageLocation) -and $UsageLocation -eq $Attendu
}

function Test-MotDePasseValide {
    param([string]$MotDePasse, [int]$LongueurMin = 8)
    $MotDePasse.Length -ge $LongueurMin
}

function Get-ValidationRaison {
    param($Ligne)
    @(
        { if (-not (Test-UpnValide $Ligne.UserPrincipalName)) { 'UPN invalide' } }
        { if (-not (Test-UsageLocationValide $Ligne.UsageLocation)) { 'UsageLocation invalide ou vide' } }
        { if (-not (Test-MotDePasseValide $Ligne.TempPassword)) { 'Mot de passe trop court (< 8)' } }
    ) | ForEach-Object { & $_ } | Where-Object { $_ }
}

function Test-LigneUtilisateurValide {
    param($Ligne)
    -not (Get-ValidationRaison $Ligne)
}

function Write-ImportLog {
    param(
        [string]$Message,
        [string]$LogPath,
        [ValidateSet('INFO', 'OK', 'SKIP', 'ERREUR', 'WHATIF')]
        [string]$Niveau = 'INFO'
    )
    $ligne = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Niveau, $Message
    $dir = Split-Path $LogPath -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Add-Content -Path $LogPath -Value $ligne -Encoding UTF8
    $couleur = @{ INFO = 'Cyan'; OK = 'Green'; SKIP = 'Yellow'; ERREUR = 'Red'; WHATIF = 'Magenta' }[$Niveau]
    Write-Host $ligne -ForegroundColor $couleur
}

function Get-DataRoot {
    param([string]$FromScriptRoot = $PSScriptRoot)
    Resolve-Path (Join-Path $FromScriptRoot '..\..\..') | Select-Object -ExpandProperty Path
}

function Get-OutputDir {
    param([string]$DataRoot = (Get-DataRoot))
    $out = Join-Path $DataRoot 'output'
    if (-not (Test-Path $out)) { New-Item -ItemType Directory -Path $out -Force | Out-Null }
    $out
}

function Get-LogPath {
    param([string]$DataRoot = (Get-DataRoot), [string]$Prefix = 'import')
    $logs = Join-Path $DataRoot 'logs'
    if (-not (Test-Path $logs)) { New-Item -ItemType Directory -Path $logs -Force | Out-Null }
    Join-Path $logs ("{0}-{1}.log" -f $Prefix, (Get-Date -Format 'yyyyMMdd'))
}

function Connect-M365Tenant {
    param([string[]]$Scopes)
    $defaut = @(
        'User.ReadWrite.All', 'Group.ReadWrite.All', 'Organization.Read.All',
        'UserAuthenticationMethod.Read.All', 'RoleManagement.Read.Directory'
    )
    $scopesEffectifs = if ($Scopes) { $Scopes } else { $defaut }
    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes $scopesEffectifs -NoWelcome
    }
    Get-MgContext
}

function Test-MgUserExists {
    param([string]$UserPrincipalName)
    $filtre = "userPrincipalName eq '$UserPrincipalName'"
    [bool](Get-MgUser -Filter $filtre -ErrorAction SilentlyContinue)
}

function Get-MgUserByUpn {
    param([string]$UserPrincipalName)
    Get-MgUser -Filter "userPrincipalName eq '$UserPrincipalName'" -Property UsageLocation, Id, UserPrincipalName, AccountEnabled -ErrorAction Stop
}

function Get-SkuId {
    param([string]$SkuPartNumber)
    $sku = Get-MgSubscribedSku -All | Where-Object SkuPartNumber -EQ $SkuPartNumber | Select-Object -First 1
    if (-not $sku) { throw "SKU introuvable : $SkuPartNumber" }
    $sku.SkuId
}

function New-MgUserBodyFromRow {
    param($Ligne)
    $mailNick = ($Ligne.UserPrincipalName -split '@')[0]
    @{
        DisplayName       = $Ligne.DisplayName
        UserPrincipalName = $Ligne.UserPrincipalName
        MailNickname      = $mailNick
        UsageLocation     = $Ligne.UsageLocation
        AccountEnabled    = $true
        Department        = $Ligne.Department
        JobTitle          = $Ligne.JobTitle
        PasswordProfile   = @{
            Password                      = $Ligne.TempPassword
            ForceChangePasswordNextSignIn = $true
        }
    }
}

function New-MgGroupBodyFromRow {
    param($Ligne)
    $builders = @{
        Security = {
            @{
                DisplayName     = $Ligne.DisplayName
                Description     = $Ligne.Description
                MailNickname    = $Ligne.MailNickname
                MailEnabled     = $false
                SecurityEnabled = $true
            }
        }
        M365     = {
            @{
                DisplayName     = $Ligne.DisplayName
                Description     = $Ligne.Description
                MailNickname    = $Ligne.MailNickname
                MailEnabled     = $true
                SecurityEnabled = $false
                GroupTypes      = @('Unified')
            }
        }
    }
    $type = $Ligne.GroupType
    if (-not $builders.ContainsKey($type)) { throw "GroupType inconnu : $type" }
    & $builders[$type]
}

function Get-MgGroupByDisplayName {
    param([string]$DisplayName)
    Get-MgGroup -Filter "displayName eq '$DisplayName'" -ErrorAction SilentlyContinue | Select-Object -First 1
}

function Invoke-SafePerLine {
    param(
        [array]$Items,
        [scriptblock]$Action,
        [string]$LogPath
    )
    $stats = @{ OK = 0; SKIP = 0; ERREUR = 0; WHATIF = 0 }
    foreach ($item in $Items) {
        try {
            $result = & $Action $item
            switch ($result) {
                'SKIP'   { $stats.SKIP++ }
                'WHATIF' { $stats.WHATIF++ }
                'ERREUR' { $stats.ERREUR++ }
                default  { $stats.OK++ }
            }
        }
        catch {
            $stats.ERREUR++
            $msg = $_.Exception.Message
            if ($LogPath) { Write-ImportLog $msg $LogPath ERREUR }
            else { Write-Host "ERREUR : $msg" -ForegroundColor Red }
        }
    }
    $stats
}

Export-ModuleMember -Function @(
    'Test-UpnValide', 'Test-UsageLocationValide', 'Test-MotDePasseValide',
    'Get-ValidationRaison', 'Test-LigneUtilisateurValide', 'Write-ImportLog',
    'Get-DataRoot', 'Get-OutputDir', 'Get-LogPath', 'Connect-M365Tenant',
    'Test-MgUserExists', 'Get-MgUserByUpn', 'Get-SkuId',
    'New-MgUserBodyFromRow', 'New-MgGroupBodyFromRow', 'Get-MgGroupByDisplayName',
    'Invoke-SafePerLine'
)
