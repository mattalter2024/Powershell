# Configurable settings
$GroupOU = "OU=TestGroups,DC=D01,DC=lab"        # Where to create the groups
$UserSearchBase = "OU=TestUsers,DC=D01,DC=lab"  # Where the users exist
$GroupPrefix = "TestGroup"
$UserPrefix = "TestUser"

# Load Active Directory module
Import-Module ActiveDirectory

# Get all users named TestUser* from the correct OU
$AllUsers = Get-ADUser -Filter * -SearchBase $UserSearchBase | Where-Object {
    $_.SamAccountName -like "$UserPrefix*"
}

# Validate user collection
if ($AllUsers.Count -lt 1) {
    Write-Error "No test users found in $UserSearchBase. Please verify the user creation script was run."
    exit
}

# Create 100 groups and populate with random users
for ($i = 1; $i -le 100; $i++) {
    $GroupName = "$GroupPrefix$i"

    # Check if group already exists
    if (-not (Get-ADGroup -Filter { Name -eq $GroupName } -SearchBase $GroupOU -ErrorAction SilentlyContinue)) {
        New-ADGroup `
            -Name $GroupName `
            -SamAccountName $GroupName `
            -GroupScope Global `
            -Path $GroupOU `
            -Description "Test group $i" `
            -PassThru | Out-Null

        Write-Host "Created group: $GroupName"
    } else {
        Write-Host "Group $GroupName already exists. Skipping..."
    }

    # Randomly select 5–15 users per group
    $Members = Get-Random -InputObject $AllUsers -Count (Get-Random -Minimum 5 -Maximum 16)

    foreach ($User in $Members) {
        try {
            Add-ADGroupMember -Identity $GroupName -Members $User.SamAccountName -ErrorAction Stop
        } catch {
            Write-Warning "Failed to add $($User.SamAccountName) to ${GroupName}: $_"
        }
    }
}
