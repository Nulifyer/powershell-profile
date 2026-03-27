#.ALIAS adtools-user-info
<#
.SYNOPSIS
    Get all AD properties for a user.

.DESCRIPTION
    Performs LDAP lookup and returns all property/value pairs for a user.

.PARAMETER Username
    The user's samAccountName.

.PARAMETER All
    Show all properties including empty and system ones.

.EXAMPLE
    adtools-user-info jdoe

.EXAMPLE
    adtools-user-info jdoe -r | Where-Object Property -like '*mail*'
#>

param(
    [Parameter(Position = 0)]
    [string]$Username,

    [Alias('a')]
    [switch]$All,

    [Alias('g')]
    [switch]$Groups,

    [Alias('dr')]
    [switch]$DirectReports,

    [Alias('r')]
    [switch]$Raw,

    [Alias('nc')]
    [switch]$NoColor,

    [Alias('help')]
    [switch]$h
)

if ($h -or -not $Username) {
    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
    Write-Host "Usage: $scriptName <Username|Email> [-a|-All] [-g|-Groups] [-dr|-DirectReports] [-r|-Raw] [-nc|-NoColor]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Get all AD properties for a user."
    Write-Host ""
    Write-Host "Arguments:"
    Write-Host "  Username    The user's samAccountName or email address (auto-detected)"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -a, -All           Show all properties (including empty/system)"
    Write-Host "  -g, -Groups        Also show group memberships (calls adtools-user-groups)"
    Write-Host "  -dr, -DirectReports Show direct reports (people who report to this user)"
    Write-Host "  -r, -Raw           Output as quoted CSV for piping"
    Write-Host "  -nc, -NoColor      Disable colored output"
    Write-Host "  -h, -Help          Show this help"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  $scriptName jdoe"
    Write-Host "  $scriptName jdoe@company.com"
    Write-Host "  $scriptName jdoe -g"
    Write-Host "  $scriptName jdoe -r > user.csv"
    exit 0
}

$ErrorActionPreference = 'Stop'

# Auto-detect email vs username
if ($Username -like '*@*') {
    $filter = "(&(objectCategory=User)(mail=$Username))"
} else {
    $filter = "(&(objectCategory=User)(samAccountName=$Username))"
}
$searcher = [System.DirectoryServices.DirectorySearcher]::new($filter)

try {
    $result = $searcher.FindOne()
}
finally {
    $searcher.Dispose()
}

if (-not $result) {
    $searchType = if ($Username -like '*@*') { 'email' } else { 'username' }
    Write-Error "No AD user found with $searchType`: '$Username'"
    exit 1
}

$entry = $result.GetDirectoryEntry()

# Helper to convert AD COM objects based on their actual type
function Convert-ComObject($obj) {
    if (-not ($obj -is [System.__ComObject])) { return $obj }
    
    # Try IADsLargeInteger (64-bit integers for timestamps)
    try {
        $high = $obj.GetType().InvokeMember('HighPart', 'GetProperty', $null, $obj, $null)
        $low = $obj.GetType().InvokeMember('LowPart', 'GetProperty', $null, $obj, $null)
        return ([int64]$high -shl 32) -bor ([uint32]$low)
    } catch {}
    
    # Try IADsSecurityDescriptor
    try {
        $owner = $obj.GetType().InvokeMember('Owner', 'QueryInterface', $null, $obj, $null)
        if ($owner) { return "[SecurityDescriptor: Owner=$owner]" }
    } catch {}
    
    # Try IADsDNWithBinary (e.g., wellKnownObjects)
    try {
        $dn = $obj.GetType().InvokeMember('DNString', 'GetProperty', $null, $obj, $null)
        if ($dn) { return $dn }
    } catch {}
    
    # Try IADsDNWithString
    try {
        $dn = $obj.GetType().InvokeMember('DNString', 'GetProperty', $null, $obj, $null)
        $str = $obj.GetType().InvokeMember('StringValue', 'GetProperty', $null, $obj, $null)
        if ($dn -or $str) { return "$str|$dn" }
    } catch {}
    
    # Unknown COM object - return type info
    return $null
}

# Helper to convert a single property value to string
function Convert-PropValue($val) {
    if ($val -is [System.__ComObject]) {
        return Convert-ComObject $val
    }
    if ($val -is [byte[]]) {
        # Try to convert to GUID if it's 16 bytes
        if ($val.Length -eq 16) {
            return ([guid]$val).ToString()
        }
        # Otherwise return hex string
        return [BitConverter]::ToString($val) -replace '-', ''
    }
    return $val
}

$properties = $entry.Properties.PropertyNames |
    Sort-Object |
    ForEach-Object {
        $rawValue = $entry.Properties[$_]
        $value = if ($rawValue.Count -eq 0) {
            $null
        } elseif ($rawValue.Count -eq 1) {
            Convert-PropValue $rawValue[0]
        } else {
            # Check if it's actually a single byte array (not multiple values)
            $first = $rawValue[0]
            if ($first -is [byte]) {
                # It's a byte array being enumerated - collect and convert
                $bytes = [byte[]]@($rawValue | ForEach-Object { $_ })
                if ($bytes.Length -eq 16) {
                    ([guid]$bytes).ToString()
                } else {
                    [BitConverter]::ToString($bytes) -replace '-', ''
                }
            } elseif ($first -is [System.__ComObject]) {
                # COM object in multi-value - convert it
                Convert-ComObject $first
            } else {
                ($rawValue | ForEach-Object { Convert-PropValue $_ }) -join ', '
            }
        }
        [pscustomobject]@{
            Property = $_
            Value    = $value
        }
    }

if ($Raw) {
    $properties | ConvertTo-Csv -NoTypeInformation
    exit 0
}

# Visual output
if ($NoColor) {
    $esc = ''; $reset = ''; $bold = ''; $dim = ''
    $cyan = ''; $yellow = ''; $green = ''; $blue = ''; $magenta = ''
} else {
    $esc = [char]27
    $reset = "$esc[0m"
    $bold = "$esc[1m"
    $dim = "$esc[2m"
    $cyan = "$esc[36m"
    $yellow = "$esc[33m"
    $green = "$esc[32m"
    $blue = "$esc[34m"
    $magenta = "$esc[35m"
}

# Helper to get property value (auto-converts any remaining COM objects)
function Get-Prop($name) {
    $val = ($properties | Where-Object Property -eq $name).Value
    if ($val -is [System.__ComObject]) { return Convert-ComObject $val }
    return $val
}

# Helper to format AD timestamp (FileTime int64, auto-handles COM objects)
function Format-ADTime($val) {
    if ($val -is [System.__ComObject]) { $val = Convert-ComObject $val }
    if (-not $val -or $val -eq '0' -or $val -eq '9223372036854775807') { return $null }
    # Ensure we have a valid number before conversion
    if ($val -isnot [long] -and $val -isnot [int] -and $val -isnot [double]) {
        try { $val = [long]$val } catch { return $null }
    }
    try {
        [DateTime]::FromFileTime([long]$val).ToString('yyyy-MM-dd HH:mm:ss')
    } catch { $null }
}

# Helper to format DateTime objects
function Format-DateTime($val) {
    if (-not $val) { return $null }
    try {
        ([DateTime]$val).ToString('yyyy-MM-dd HH:mm:ss')
    } catch { $null }
}

# Helper to format phone numbers
function Format-Phone($val) {
    if (-not $val) { return $null }
    $digits = $val -replace '[^0-9]', ''
    if ($digits.Length -eq 10) {
        return '({0}) {1}-{2}' -f $digits.Substring(0,3), $digits.Substring(3,3), $digits.Substring(6,4)
    }
    if ($digits.Length -eq 11 -and $digits[0] -eq '1') {
        return '({0}) {1}-{2}' -f $digits.Substring(1,3), $digits.Substring(4,3), $digits.Substring(7,4)
    }
    return $val
}

# Get key values
$displayName = Get-Prop 'displayName'
$title = Get-Prop 'title'
$department = Get-Prop 'department'
$company = Get-Prop 'company'
$mail = Get-Prop 'mail'
$mobile = Format-Phone (Get-Prop 'mobile')
$manager = Get-Prop 'manager'
$office = "{0} - {1}" -f (Get-Prop 'physicalDeliveryOfficeName'), (Get-Prop 'streetAddress')

# Header card
Write-Host ""
Write-Host "$bold$cyan╭─────────────────────────────────────────────────────────────────╮$reset"
Write-Host "$bold$cyan│$reset  $bold󰀄  $yellow$displayName$reset"
Write-Host "$bold$cyan│$reset     $dim@$Username$reset"
if ($title -or $department) {
    $titleDept = @($title, $department) | Where-Object { $_ } | Join-String -Separator " · "
    Write-Host "$bold$cyan│$reset     $titleDept"
}
if ($company) { Write-Host "$bold$cyan│$reset     $dim$company$reset" }
Write-Host "$bold$cyan╰─────────────────────────────────────────────────────────────────╯$reset"

# Section helper
function Write-Section($title, $icon) {
    Write-Host ""
    Write-Host "  $bold$magenta$icon  $title$reset"
    Write-Host "  $dim$("─" * 50)$reset"
}

function Write-Field($label, $value, $labelWidth = 20) {
    if (-not $All -and -not $value) { return }
    $displayVal = if ($value) { $value } else { "$dim(empty)$reset" }
    if ($displayVal.Length -gt 80) { $displayVal = $displayVal.Substring(0, 77) + "..." }
    Write-Host "    $green$($label.PadRight($labelWidth))$reset $displayVal"
}

# Contact Info
Write-Section "Contact" ""
Write-Field "Email" $mail
Write-Field "Mobile" $mobile
Write-Field "Pager" (Get-Prop 'pager')
Write-Field "Office" $office

# Organization
Write-Section "Organization" "󰢏"
Write-Field "Title" $title
Write-Field "Department" $department
Write-Field "Company" $company
if ($manager) {
    # Look up manager details
    try {
        $mgrEntry = [ADSI]"LDAP://$manager"
        $mgrUsername = $mgrEntry.sAMAccountName.Value
        $mgrDisplayName = $mgrEntry.displayName.Value
        $mgrEmail = $mgrEntry.mail.Value
        
        Write-Host ""
        Write-Host "    $green$("Manager".PadRight(20))$reset $bold$mgrDisplayName$reset"
        Write-Host "    $(" " * 20) $dim@$mgrUsername$reset"
        if ($mgrEmail) {
            Write-Host "    $(" " * 20) $blue$mgrEmail$reset"
        }
    } catch {
        $mgrName = ($manager -split ',')[0] -replace '^CN=', ''
        Write-Field "Manager" $mgrName
    }
}

# Identity
Write-Section "Identity" "󰪪"
Write-Field "Username" (Get-Prop 'sAMAccountName')
Write-Field "Display Name" $displayName
Write-Field "First Name" (Get-Prop 'givenName')
Write-Field "Last Name" (Get-Prop 'sn')
Write-Field "Employee ID" (Get-Prop 'employeeID')
Write-Field "UPN" (Get-Prop 'userPrincipalName')

# Account Status
Write-Section "Account" "󰌆"
# Use more recent of lastLogon (per-DC) and lastLogonTimestamp (replicated)
$lastLogonRaw = Get-Prop 'lastLogon'
$lastLogonTsRaw = Get-Prop 'lastLogonTimestamp'
[long]$lastLogonVal = try { if ($lastLogonRaw -and $lastLogonRaw -ne '0') { [long]$lastLogonRaw } else { 0 } } catch { 0 }
[long]$lastLogonTsVal = try { if ($lastLogonTsRaw -and $lastLogonTsRaw -ne '0') { [long]$lastLogonTsRaw } else { 0 } } catch { 0 }
$lastLogon = Format-ADTime ([Math]::Max([long]$lastLogonVal, [long]$lastLogonTsVal))
$pwdLastSet = Format-ADTime (Get-Prop 'pwdLastSet')
$whenCreated = Format-DateTime (Get-Prop 'whenCreated')
$whenChanged = Format-DateTime (Get-Prop 'whenChanged')
$badPwdCount = Get-Prop 'badPwdCount'
$lockoutTime = Get-Prop 'lockoutTime'

Write-Field "Last Logon" $lastLogon
Write-Field "Password Set" $pwdLastSet
Write-Field "Created" $whenCreated
Write-Field "Modified" $whenChanged
Write-Field "Bad Pwd Count" $badPwdCount
if ($lockoutTime -and $lockoutTime -ne '0') {
    Write-Field "Locked Out" (Format-ADTime $lockoutTime) 
}

# Direct Reports (if -dr)
if ($DirectReports) {
    $directReportsRaw = $entry.Properties['directReports']
    if ($directReportsRaw -and $directReportsRaw.Count -gt 0) {
        Write-Section "Direct Reports ($($directReportsRaw.Count))" "󰡉"
        
        # Collect report data
        $reports = @()
        foreach ($reportDn in $directReportsRaw) {
            try {
                $reportEntry = [ADSI]"LDAP://$reportDn"
                $reports += [PSCustomObject]@{
                    Username    = "$($reportEntry.sAMAccountName.Value)"
                    DisplayName = "$($reportEntry.displayName.Value)"
                    Title       = "$($reportEntry.title.Value)"
                    Email       = "$($reportEntry.mail.Value)"
                }
            } catch {
                $reportName = ($reportDn -split ',')[0] -replace '^CN=', ''
                $reports += [PSCustomObject]@{
                    Username    = ""
                    DisplayName = $reportName
                    Title       = ""
                    Email       = ""
                }
            }
        }
        
        # Calculate column widths (max 25 per column)
        $colUser = [Math]::Min(25, ($reports | ForEach-Object { $_.Username.Length } | Measure-Object -Maximum).Maximum)
        $colUser = [Math]::Max($colUser, 8)
        $colName = [Math]::Min(30, ($reports | ForEach-Object { $_.DisplayName.Length } | Measure-Object -Maximum).Maximum)
        $colName = [Math]::Max($colName, 12)
        $colTitle = [Math]::Min(25, ($reports | ForEach-Object { $_.Title.Length } | Measure-Object -Maximum).Maximum)
        $colTitle = [Math]::Max($colTitle, 5)
        
        # Header
        Write-Host ""
        $header = "    $bold$("Username".PadRight($colUser))  $("Name".PadRight($colName))  $("Title".PadRight($colTitle))  Email$reset"
        Write-Host $header
        Write-Host "    $dim$("─" * $colUser)  $("─" * $colName)  $("─" * $colTitle)  $("─" * 30)$reset"
        
        # Rows
        foreach ($r in $reports | Sort-Object DisplayName) {
            $user = if ($r.Username.Length -gt $colUser) { $r.Username.Substring(0, $colUser - 2) + ".." } else { $r.Username.PadRight($colUser) }
            $name = if ($r.DisplayName.Length -gt $colName) { $r.DisplayName.Substring(0, $colName - 2) + ".." } else { $r.DisplayName.PadRight($colName) }
            $title = if ($r.Title.Length -gt $colTitle) { $r.Title.Substring(0, $colTitle - 2) + ".." } else { $r.Title.PadRight($colTitle) }
            $email = $r.Email
            
            Write-Host "    $cyan$user$reset  $name  $dim$title$reset  $blue$email$reset"
        }
        Write-Host ""
    } else {
        Write-Section "Direct Reports" "󰡉"
        Write-Host "    $dim(none)$reset"
    }
}

# Group Memberships (call other script if -g)
if ($Groups) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $groupsScript = Join-Path $scriptDir "adtools-user-groups.ps1"
    & $groupsScript $Username
}

# Show all properties if -All flag
if ($All) {
    Write-Section "All Properties" "󰋽"
    $maxPropLen = 32
    foreach ($prop in $properties) {
        $propName = $prop.Property.PadRight($maxPropLen)
        $value = $prop.Value
        if ($value.Length -gt 80) { $value = $value.Substring(0, 77) + "..." }
        $valueDisplay = if ($value) { $value } else { "$dim(empty)$reset" }
        Write-Host "    $dim$propName$reset $valueDisplay"
    }
}

Write-Host ""
Write-Host "  $dim$($properties.Count) properties total (use -a for all, -g for groups, -dr for reports, -r for CSV)$reset"
Write-Host ""
