#.ALIAS adtools-group-users
<#
.SYNOPSIS
    List users in an AD group.

.DESCRIPTION
    Searches AD for a group by CN and returns member information.

.PARAMETER GroupName
    The CN of the AD group.

.EXAMPLE
    adtools-group-users HelpDesk

.EXAMPLE
    adtools-group-users HelpDesk -r > members.csv
#>

param(
    [Parameter(Position = 0)]
    [string]$GroupName,

    [Alias('r')]
    [switch]$Raw,

    [Alias('nc')]
    [switch]$NoColor,

    [Alias('help')]
    [switch]$h
)

if ($h -or -not $GroupName) {
    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
    Write-Host "Usage: $scriptName <GroupName> [-r|-Raw] [-nc|-NoColor]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "List users in an AD group."
    Write-Host ""
    Write-Host "Arguments:"
    Write-Host "  GroupName    The CN of the AD group"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -r, -Raw      Output as quoted CSV for piping"
    Write-Host "  -nc, -NoColor Disable colored output"
    Write-Host "  -h, -Help     Show this help"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  $scriptName HelpDesk"
    Write-Host "  $scriptName HelpDesk -r > members.csv"
    exit 0
}

$ErrorActionPreference = 'Stop'

$groupFilter = "(&(objectClass=group)(cn=$GroupName))"
$groupSearcher = [System.DirectoryServices.DirectorySearcher]::new($groupFilter)

try {
    $groupResults = $groupSearcher.FindAll()
}
finally {
    $groupSearcher.Dispose()
}

if ($groupResults.Count -eq 0) {
    Write-Error "No groups found matching '$GroupName'"
    exit 1
}

$allGroups = @()

foreach ($group in $groupResults) {
    $groupDn = $group.Path.Substring("LDAP://".Length)
    $userFilter = "(&(objectCategory=User)(memberOf=$groupDn))"
    $userSearcher = [System.DirectoryServices.DirectorySearcher]::new($userFilter)
    $userSearcher.PropertiesToLoad.AddRange(@('samaccountname', 'displayname', 'mail', 'distinguishedname'))

    try {
        $userResults = $userSearcher.FindAll()
    }
    finally {
        $userSearcher.Dispose()
    }

    # Parse group name from DN
    $groupName = ($groupDn -split ',')[0] -replace '^CN=', ''

    # Parse members into objects with AD properties
    $memberObjects = @()
    foreach ($result in $userResults) {
        $props = $result.Properties
        $memberObjects += [PSCustomObject]@{
            Username          = "$($props['samaccountname'])"
            DisplayName       = "$($props['displayname'])"
            Email             = "$($props['mail'])"
            DistinguishedName = "$($props['distinguishedname'])"
        }
    }

    $allGroups += [PSCustomObject]@{
        GroupName              = $groupName
        GroupDistinguishedName = $groupDn
        MemberCount            = $userResults.Count
        Members                = $memberObjects
    }
}

if ($Raw) {
    # Output as quoted CSV
    $allMembers = foreach ($grp in $allGroups) {
        foreach ($member in $grp.Members) {
            [PSCustomObject]@{
                GroupName   = $grp.GroupName
                Username    = $member.Username
                DisplayName = $member.DisplayName
                Email       = $member.Email
            }
        }
    }
    $allMembers | ConvertTo-Csv -NoTypeInformation
    exit 0
}

# Visual output
if ($NoColor) {
    $esc = ''; $reset = ''; $bold = ''; $dim = ''
    $cyan = ''; $yellow = ''; $green = ''; $magenta = ''; $blue = ''
} else {
    $esc = [char]27
    $reset = "$esc[0m"
    $bold = "$esc[1m"
    $dim = "$esc[2m"
    $cyan = "$esc[36m"
    $yellow = "$esc[33m"
    $green = "$esc[32m"
    $magenta = "$esc[35m"
    $blue = "$esc[34m"
}

foreach ($grp in $allGroups) {
    Write-Host ""
    Write-Host "$bold$cyan󰡉  Group: $yellow$($grp.GroupName)$reset"
    Write-Host "$dim$("─" * 70)$reset"
    Write-Host "  $blue  Members: $bold$($grp.MemberCount)$reset"
    
    if ($grp.Members.Count -gt 0) {
        Write-Host ""
        # Calculate column widths (max 25 for username, 50 for display name)
        $maxUser = ($grp.Members | ForEach-Object { $_.Username.Length } | Measure-Object -Maximum).Maximum
        $maxUser = [Math]::Max([Math]::Min($maxUser, 25), 10)
        $maxName = ($grp.Members | ForEach-Object { $_.DisplayName.Length } | Measure-Object -Maximum).Maximum
        $maxName = [Math]::Max([Math]::Min($maxName, 50), 12)
        
        # Header
        Write-Host "    $dim$("Username".PadRight($maxUser))  $("Display Name".PadRight($maxName))  Email$reset"
        Write-Host "    $dim$("─" * $maxUser)  $("─" * $maxName)  $("─" * 40)$reset"
        
        foreach ($member in $grp.Members | Sort-Object Username) {
            $user = $member.Username.PadRight($maxUser)
            $name = if ($member.DisplayName.Length -gt $maxName) { 
                $member.DisplayName.Substring(0, $maxName - 3) + "..." 
            } else { 
                $member.DisplayName.PadRight($maxName) 
            }
            $email = if ($member.Email) { $member.Email } else { $dim + "(none)" + $reset }
            Write-Host "    $green$user$reset  $bold$name$reset  $blue$email$reset"
        }
    }
    
    Write-Host ""
    Write-Host "$dim$("─" * 70)$reset"
    Write-Host ""
}
