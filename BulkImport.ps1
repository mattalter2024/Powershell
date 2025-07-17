Import-Module ActiveDirectory

# Get current domain info
$DomainInfo = Get-ADDomain
$DN = $DomainInfo.DistinguishedName
$DNSRoot = $DomainInfo.DNSRoot

# Define target OUs
$BaseOU = "OU=TestLab,$DN"
$UserOU = "OU=Users,$BaseOU"
$ComputerOU = "OU=Computers,$BaseOU"

# Number of objects to create
$UserCount = 10000
$ComputerCount = 10000

# Robust Recursive OU Creation
function Ensure-OUExists {
    param([string]$OU)

    # Exit if empty or null
    if ([string]::IsNullOrWhiteSpace($OU)) {
        Write-Warning "⚠ OU path is null or empty. Skipping."
        return
    }

    # If OU exists, return
    try {
        if (Get-ADOrganizationalUnit -Identity $OU -ErrorAction Stop) {
            Write-Host "✔ OU exists: $OU"
            return
        }
    } catch {
        # Continue to creation
    }

    # Safe split
    $components = $OU -split '(?<!\\),'
    if ($components.Count -lt 2) {
        Write-Warning "⚠ Cannot split OU string: $OU"
        return
    }

    $OUName = ($components[0] -replace '^OU=', '')
    $ParentDN = ($components[1..($components.Count - 1)] -join ',')

    # Recursively create parent
    Ensure-OUExists -OU $ParentDN

    # Create this OU
    try {
        New-ADOrganizationalUnit -Name $OUName -Path $ParentDN -ProtectedFromAccidentalDeletion $false -ErrorAction Stop
        Write-Host "✔ Created OU: $OU"
    } catch {
        Write-Warning "⚠ Failed to create OU ${OUName} in ${ParentDN}: $_"
    }
}

# Ensure OU structure exists
Ensure-OUExists -OU $BaseOU
Ensure-OUExists -OU $UserOU
Ensure-OUExists -OU $ComputerOU

# Prepare password
$Password = ConvertTo-SecureString "P@ssword123!" -AsPlainText -Force

# --- Create Users ---
Write-Host "`n🧑 Creating $UserCount test users..."
for ($i = 1; $i -le $UserCount; $i++) {
    $Username = "TestUser$i"
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$Username'" -ErrorAction SilentlyContinue)) {
        try {
            New-ADUser -Name $Username `
                       -SamAccountName $Username `
                       -UserPrincipalName "$Username@$DNSRoot" `
                       -AccountPassword $Password `
                       -Enabled $true `
                       -Path $UserOU `
                       -PassThru | Out-Null
        } catch {
            Write-Warning "⚠ Failed to create user ${Username}: $_"
        }
    }
    if ($i % 500 -eq 0) { Write-Host "   ⏳ Created $i users..." }
}

# --- Create Computers ---
Write-Host "`n💻 Creating $ComputerCount test computers..."
for ($j = 1; $j -le $ComputerCount; $j++) {
    $ComputerName = "TestPC$j"
    if (-not (Get-ADComputer -Filter "Name -eq '$ComputerName'" -ErrorAction SilentlyContinue)) {
        try {
            New-ADComputer -Name $ComputerName `
                           -SamAccountName "$ComputerName$" `
                           -Path $ComputerOU `
                           -Enabled $true `
                           -PassThru | Out-Null
        } catch {
            Write-Warning "⚠ Failed to create computer ${ComputerName}: $_"
        }
    }
    if ($j % 500 -eq 0) { Write-Host "   ⏳ Created $j computers..." }
}

# --- Done ---
Write-Host "`n✅ Completed creation of $UserCount users and $ComputerCount computers."
Write-Host "   → Users OU: $UserOU"
Write-Host "   → Computers OU: $ComputerOU"
