# ======================================
# Active Directory Health Check Report - Nicely Formatted HTML
# ======================================

$timeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportPath = "$PWD\AD_HealthCheck_Report_$timeStamp.html"
$global:ReportSections = @()

function Add-Section {
    param(
        [string]$Section,
        [string]$Content
    )

    if (-not $Content -or $Content.Trim() -eq "") {
        $Content = "[No data collected or command failed]"
    }

    # Convert newlines to <br> for HTML
    $HtmlContent = $Content.Trim() -replace "`r?`n", "<br>"

    # Add this section's HTML
    $global:ReportSections += @"
<h3>$Section</h3>
<p>$HtmlContent</p>
<hr>
"@
}

# Header for the report
$headerHtml = @"
<h2>Active Directory Health Check Report - $env:COMPUTERNAME</h2>
<p>Generated on $(Get-Date)</p>
<hr>
"@

Write-Host "Starting Active Directory Health Check..."

# 1️⃣ Server Name
Add-Section -Section "Server Name" -Content $env:COMPUTERNAME

# 2️⃣ FSMO Roles
try {
    $fsmo = netdom query fsmo 2>&1 | Out-String
    Add-Section -Section "FSMO Roles" -Content $fsmo
} catch {
    Add-Section -Section "FSMO Roles" -Content "Error: $_"
}

# 3️⃣ Domain & Forest Functional Level
try {
    $domainMode = (Get-ADDomain).DomainMode
    $forestMode = (Get-ADForest).ForestMode
    $funcLevels = "Domain Functional Level: $domainMode`nForest Functional Level: $forestMode"
    Add-Section -Section "Domain & Forest Functional Levels" -Content $funcLevels
} catch {
    Add-Section -Section "Domain & Forest Functional Levels" -Content "Error: $_"
}

# 4️⃣ AD Database Size
try {
    $ntdsPath = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters")."DSA Database file"
    if (Test-Path $ntdsPath) {
        $dbSize = (Get-Item $ntdsPath).Length / 1MB
        $dbDetails = "Path: $ntdsPath`nSize: {0:N2} MB" -f $dbSize
        Add-Section -Section "AD Database" -Content $dbDetails
    } else {
        Add-Section -Section "AD Database" -Content "ntds.dit file not found."
    }
} catch {
    Add-Section -Section "AD Database" -Content "Error: $_"
}

# 5️⃣ Disk Space for ntds.dit volume
try {
    if ($ntdsPath) {
        $volume = (Get-Item $ntdsPath).PSDrive.Root
        $disk = Get-PSDrive | Where-Object { $_.Root -eq $volume }
        if ($disk) {
            $freeGB = [math]::Round($disk.Free / 1GB, 2)
            $totalGB = [math]::Round(($disk.Used + $disk.Free) / 1GB, 2)
            $diskInfo = "Volume: $volume`nFree: $freeGB GB / Total: $totalGB GB"
            Add-Section -Section "Disk Space for ntds.dit" -Content $diskInfo
        } else {
            Add-Section -Section "Disk Space" -Content "Could not determine disk space."
        }
    }
} catch {
    Add-Section -Section "Disk Space" -Content "Error: $_"
}

# 6️⃣ Replication Summary
try {
    $repl = repadmin /replsummary 2>&1 | Out-String
    Add-Section -Section "Replication Summary" -Content $repl
} catch {
    Add-Section -Section "Replication Summary" -Content "Error: $_"
}

# 7️⃣ DCDiag Output
try {
    $dcdiag = dcdiag /c /q 2>&1 | Out-String
    Add-Section -Section "DCDiag (Critical Issues)" -Content $dcdiag
} catch {
    Add-Section -Section "DCDiag" -Content "Error: $_"
}

# 8️⃣ SYSVOL Migration State
try {
    $sysvol = dfsrmig /getglobalstate 2>&1 | Out-String
    Add-Section -Section "SYSVOL DFSR Migration State" -Content $sysvol
} catch {
    Add-Section -Section "SYSVOL DFSR Migration State" -Content "Error: $_"
}

# 9️⃣ Time Service
try {
    $timeConfig = w32tm /query /configuration 2>&1 | Out-String
    $timeStatus = w32tm /query /status 2>&1 | Out-String
    Add-Section -Section "Time Service Configuration" -Content $timeConfig
    Add-Section -Section "Time Service Status" -Content $timeStatus
} catch {
    Add-Section -Section "Time Service" -Content "Error: $_"
}

# 🔟 Directory Service Event Log Errors/Warnings
try {
    $events = Get-WinEvent -LogName "Directory Service" -ErrorAction SilentlyContinue |
        Where-Object { $_.LevelDisplayName -in @('Error','Warning') } |
        Select-Object -First 10 TimeCreated, Id, LevelDisplayName, Message |
        Format-List | Out-String
    Add-Section -Section "Recent Directory Service Errors/Warnings" -Content $events
} catch {
    Add-Section -Section "Event Log" -Content "Error: $_"
}

# 11️⃣ Domain Controller Services Status
try {
    $services = Get-Service NTDS DFSR DNS Netlogon KDC w32time | Format-Table Name, Status -AutoSize | Out-String
    Add-Section -Section "Domain Controller Services Status" -Content $services
} catch {
    Add-Section -Section "Domain Controller Services Status" -Content "Error: $_"
}

# 12️⃣ SYSVOL Share Presence
try {
    $shares = Get-SmbShare | Where-Object Name -eq 'SYSVOL' | Format-Table Name, Path, Description -AutoSize | Out-String
    Add-Section -Section "SYSVOL Share Status" -Content $shares
} catch {
    Add-Section -Section "SYSVOL Share Status" -Content "Error: $_"
}

# 13️⃣ Recent System Event Log Errors
try {
    $systemEvents = Get-WinEvent -LogName System -ErrorAction SilentlyContinue |
        Where-Object { $_.LevelDisplayName -in @('Error','Critical') } |
        Select-Object -First 10 TimeCreated, Id, LevelDisplayName, Message |
        Format-List | Out-String
    Add-Section -Section "Recent System Event Log Errors" -Content $systemEvents
} catch {
    Add-Section -Section "Recent System Event Log Errors" -Content "Error: $_"
}

# 14️⃣ Stale Computer Accounts (inactive 90+ days)
try {
    $staleComputers = Get-ADComputer -Filter * -Properties LastLogonDate |
        Where-Object { $_.LastLogonDate -and $_.LastLogonDate -lt (Get-Date).AddDays(-90) } |
        Select-Object Name, LastLogonDate |
        Format-Table -AutoSize | Out-String
    Add-Section -Section "Stale Computer Accounts (90+ Days Inactive)" -Content $staleComputers
} catch {
    Add-Section -Section "Stale Computer Accounts" -Content "Error: $_"
}

# 15️⃣ Group Policy Objects (GPO) Statistics
try {
    $allGPOs = Get-GPO -All
    $gpoCount = $allGPOs.Count

    $recentGPOs = $allGPOs |
        Sort-Object ModificationTime -Descending |
        Select-Object -First 5 |
        ForEach-Object { "$($_.DisplayName) (Modified: $($_.ModificationTime))" } |
        Out-String

    $gpoStats = "Total GPO Count: $gpoCount`n`nMost Recently Modified GPOs:`n$recentGPOs"

    Add-Section -Section "Group Policy Objects (GPO) Statistics" -Content $gpoStats
} catch {
    Add-Section -Section "Group Policy Objects (GPO) Statistics" -Content "Error: $_"
}

# 16️⃣ Domain Admins and Local Administrators Membership
try {
    $domainAdmins = Get-ADGroupMember "Domain Admins" -Recursive
    $domainAdminCount = $domainAdmins.Count
    $domainAdminList = $domainAdmins | Select-Object -ExpandProperty SamAccountName | Out-String

    $localAdmins = Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue
    if ($null -eq $localAdmins) {
        $localAdminList = "[Unable to retrieve local Administrators group on this system.]"
    } else {
        $localAdminList = $localAdmins | ForEach-Object { "$($_.ObjectClass): $($_.Name)" } | Out-String
    }

    $adminInfo = "Domain Admins in AD:`nTotal: $domainAdminCount`n`nMembers:`n$domainAdminList`n`nLocal Administrators Group on Server:`n$localAdminList"
    Add-Section -Section "Domain Admins and Local Administrators Membership" -Content $adminInfo
} catch {
    Add-Section -Section "Domain Admins and Local Administrators Membership" -Content "Error: $_"
}

# 17️⃣ DNS Server Configuration
try {
    $forwarders = Get-DnsServerForwarder -ErrorAction SilentlyContinue
    if ($null -eq $forwarders) {
        $forwarderList = "No forwarders configured or not a DNS server."
    } else {
        $forwarderList = ($forwarders.IPAddress -join ", ")
    }

    $zones = Get-DnsServerZone -ErrorAction SilentlyContinue
    if ($null -eq $zones) {
        $zoneList = "No zones found or not a DNS server."
    } else {
        $zoneDetails = $zones | ForEach-Object {
            $zoneName = $_.ZoneName
            $zoneType = $_.ZoneType
            $replicationScope = $_.ReplicationScope
            $agingEnabled = if ($_.AgingEnabled) { "Enabled" } else { "Disabled" }
            "$zoneName (Type: $zoneType, Replication: $replicationScope, Aging: $agingEnabled)"
        } | Out-String
        $zoneList = $zoneDetails
    }

    $dnsInfo = "Forwarders:`n$forwarderList`n`nZones:`n$zoneList"
    Add-Section -Section "DNS Server Configuration" -Content $dnsInfo
} catch {
    Add-Section -Section "DNS Server Configuration" -Content "Error: $_"
}

# 18️⃣ SYSVOL Folder Size and File Count
try {
    $sysvolPath = "C:\Windows\SYSVOL\domain"
    if (Test-Path $sysvolPath) {
        $files = Get-ChildItem -Path $sysvolPath -Recurse -File -ErrorAction SilentlyContinue
        $fileCount = $files.Count
        $totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
        $totalSizeGB = [math]::Round($totalBytes / 1GB, 2)
        $sysvolInfo = "Path: $sysvolPath`nTotal Size: $totalSizeGB GB`nTotal Files: $fileCount"
    } else {
        $sysvolInfo = "SYSVOL folder not found at $sysvolPath."
    }
    Add-Section -Section "SYSVOL Folder Size and File Count" -Content $sysvolInfo
} catch {
    Add-Section -Section "SYSVOL Folder Size and File Count" -Content "Error: $_"
}

# 19️⃣ SYSVOL Replication Method
try {
    $dfsrmigState = dfsrmig /getglobalstate 2>&1 | Out-String
    Add-Section -Section "SYSVOL Replication Method" -Content $dfsrmigState
} catch {
    Add-Section -Section "SYSVOL Replication Method" -Content "Error: $_"
}

# 20️⃣ SYSVOL DFSR Replication Partners
try {
    $groups = Get-DfsReplicationGroup -ErrorAction SilentlyContinue
    if ($null -eq $groups) {
        $partnersInfo = "No DFS Replication Groups found on this server."
    } else {
        $partnersDetails = ""
        foreach ($group in $groups) {
            $partnersDetails += "`nReplication Group: $($group.GroupName)"
            $connections = Get-DfsrConnection -GroupName $group.GroupName -ErrorAction SilentlyContinue
            if ($connections) {
                foreach ($conn in $connections) {
                    $partnersDetails += "`n- $($conn.SourceComputerName) --> $($conn.DestinationComputerName)"
                }
            } else {
                $partnersDetails += "`n- No connections found in this group."
            }
            $partnersDetails += "`n"
        }
        $partnersInfo = $partnersDetails
    }

    Add-Section -Section "SYSVOL DFSR Replication Partners" -Content $partnersInfo
} catch {
    Add-Section -Section "SYSVOL DFSR Replication Partners" -Content "Error: $_"
}

# 21️⃣ DFS Namespaces
try {
    $dfsRoots = Get-DfsnRoot -ErrorAction SilentlyContinue
    if ($null -eq $dfsRoots) {
        $dfsNamespaceList = "No DFS Namespaces found on this server."
    } else {
        $dfsNamespaceList = ($dfsRoots.Path -join "`n")
    }

    Add-Section -Section "DFS Namespaces on this Server" -Content $dfsNamespaceList
} catch {
    Add-Section -Section "DFS Namespaces on this Server" -Content "Error: $_"
}

# ✅ Generate the final HTML
$BodyContent = $headerHtml + ($ReportSections -join "`n")

$HTMLPage = @"
<!DOCTYPE html>
<html>
<head>
<title>AD Health Check Report</title>
</head>
<body>
$BodyContent
</body>
</html>
"@

$HTMLPage | Out-File -Encoding utf8 $reportPath

Write-Host "`n✅ Health Check Report generated: $reportPath"
