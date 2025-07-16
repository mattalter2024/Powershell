# Configuration
$OU = "OU=TestUsers,DC=d01,DC=lab"  # Change to your target OU
$DefaultPassword = "P@ssw0rd123!"          # Set a secure default password
$Domain = "yourdomain.com"                # Set your domain

# Convert password to secure string
$SecurePassword = ConvertTo-SecureString $DefaultPassword -AsPlainText -Force

# Loop to create 100 users
for ($i = 1; $i -le 100; $i++) {
    $UserName = "TestUser$i"
    $GivenName = "Test"
    $Surname = "User$i"
    $DisplayName = "$GivenName $Surname"
    $UPN = "$UserName@$Domain"
    $SamAccountName = $UserName

    # Check if user already exists
    if (-not (Get-ADUser -Filter { SamAccountName -eq $SamAccountName } -ErrorAction SilentlyContinue)) {
        New-ADUser `
            -Name $DisplayName `
            -GivenName $GivenName `
            -Surname $Surname `
            -SamAccountName $SamAccountName `
            -UserPrincipalName $UPN `
            -AccountPassword $SecurePassword `
            -DisplayName $DisplayName `
            -Path $OU `
            -Enabled $true `
            -PasswordNeverExpires $true `
            -ChangePasswordAtLogon $false

        Write-Host "Created user: $SamAccountName"
    } else {
        Write-Host "User $SamAccountName already exists. Skipping..."
    }
}
