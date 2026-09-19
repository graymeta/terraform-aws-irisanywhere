
$iasecretarn = "${ia_secret_arn}"
$enterprise_ha = "${enterprise_ha}"
$dbserver = "${dbserver}"
$https_console_port = "${https_console_port}"
$http_console_port = "${http_console_port}"
$instance_index = [int]"${instance_index}"

# Ensure temp directory exists and start transcript logging
$temp_dir = "$($env:systemdrive)\IrisTemp"
if (-not (Test-Path $temp_dir)) {
    New-Item -ItemType Directory -Path $temp_dir -Force | Out-Null
}
$log_path = "$temp_dir\iris_admin_install.log"
Start-Transcript -Path $log_path -Append -IncludeInvocationHeader -ErrorAction SilentlyContinue

# Ensure custom Event Log source exists
try {
    if (-not (Get-EventLog -List -ErrorAction SilentlyContinue | Where-Object { $_.Log -eq 'IrisAdmin' })) {
        New-EventLog -LogName IrisAdmin -Source "IrisAdmin" -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
} catch {
    Write-Host "Warning: Could not create IrisAdmin event log source: $($_.Exception.Message)" -ForegroundColor Yellow
}

function Write-Log {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet("Information", "Warning", "Error")][string]$Level = "Information",
        [int]$EventId = 1001
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $color = switch ($Level) {
        "Error" { "Red" }
        "Warning" { "Yellow" }
        Default { "Green" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    try {
        Write-EventLog -LogName IrisAdmin -Source IrisAdmin -EntryType $Level -EventId $EventId -Message $Message -ErrorAction SilentlyContinue
    } catch {}
}

Write-Log -Message "Iris Admin cloud_init initialization started (Instance Index: $instance_index, Enterprise HA: $enterprise_ha)" -Level Information

# Retrieve and prepare Secrets
try {
    Write-Log -Message "Retrieving secret from ARN: $iasecretarn" -Level Information
    $secretdata = (Get-SECSecretValue -SecretId $iasecretarn).SecretString | ConvertFrom-Json
    
    $admin_db_id        = $secretdata.admin_db_id
    $admin_db_pw        = $secretdata.admin_db_pw
    $admin_console_id   = $secretdata.admin_console_id
    $admin_console_pw   = $secretdata.admin_console_pw

    if ([string]::IsNullOrEmpty($admin_db_id) -or [string]::IsNullOrEmpty($admin_db_pw) -or [string]::IsNullOrEmpty($admin_console_id) -or [string]::IsNullOrEmpty($admin_console_pw)) {
        Write-Log -Message "One or more required credentials in secret $iasecretarn are empty or missing!" -Level Warning
    } else {
        Write-Log -Message "Secrets retrieved successfully." -Level Information
    }
} catch {
    Write-Log -Message "Exception accessing secret $($iasecretarn): $($_.Exception.Message)" -Level Error
}

# Ensure SSM Agent is running
try {
    Set-Service -Name AmazonSSMAgent -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name AmazonSSMAgent -ErrorAction SilentlyContinue
    Write-Log -Message "AmazonSSMAgent service status: $((Get-Service -Name AmazonSSMAgent -ErrorAction SilentlyContinue).Status)" -Level Information
} catch {
    Write-Log -Message "Warning configuring AmazonSSMAgent: $($_.Exception.Message)" -Level Warning
}

# Locate and validate installer executable
$exe_files = Get-ChildItem -Path $temp_dir -Filter "*.exe" -ErrorAction SilentlyContinue
if (-not $exe_files -or $exe_files.Count -eq 0) {
    Write-Log -Message "FATAL: No .exe installer found in $temp_dir! Installation cannot proceed." -Level Error
    $iris_admin_exe = $null
} else {
    $iris_admin_exe = $exe_files[0].Name
    Write-Log -Message "Found installer: $iris_admin_exe" -Level Information
}

# Test database reachability if external RDS/PostgreSQL is used
if ($enterprise_ha -eq "true" -and -not [string]::IsNullOrEmpty($dbserver)) {
    Write-Log -Message "Enterprise HA mode enabled. Testing connectivity to DB server '$dbserver' on port 5432..." -Level Information
    $db_connected = $false
    for ($attempt = 1; $attempt -le 6; $attempt++) {
        try {
            $tcp_client = New-Object System.Net.Sockets.TcpClient
            $connect_task = $tcp_client.BeginConnect($dbserver, 5432, $null, $null)
            if ($connect_task.AsyncWaitHandle.WaitOne(5000, $false) -and $tcp_client.Connected) {
                $tcp_client.EndConnect($connect_task)
                $tcp_client.Close()
                $db_connected = $true
                Write-Log -Message "TCP connection to PostgreSQL DB ($($dbserver):5432) SUCCEEDED on attempt $attempt" -Level Information
                break
            } else {
                $tcp_client.Close()
            }
        } catch {}
        
        Write-Log -Message "Attempt $attempt of 6 - TCP connection to PostgreSQL ($($dbserver):5432) not ready yet. Retrying in 10s..." -Level Warning
        Start-Sleep -Seconds 10
    }

    if (-not $db_connected) {
        Write-Log -Message "FAILED to establish TCP connection to PostgreSQL DB ($($dbserver):5432) after 6 attempts!" -Level Error
    }
}

# Install execution with timing and exit code inspection
try {
    # $instance_index 0 installs immediately, all else wait an additional $instance_index * 60 seconds
    if ($instance_index -gt 0) {
        Write-Log -Message "Instance index is $instance_index. Waiting additional $($instance_index * 120) seconds..." -Level Information
        Start-Sleep -Seconds ($instance_index * 120)
    }

    if ([string]::IsNullOrEmpty($iris_admin_exe)) {
        throw "Installer executable not found in $temp_dir."
    }

    $exe_full_path = Join-Path $temp_dir $iris_admin_exe

    if ($enterprise_ha -eq "true") {
        $arg_list = "/S /INSTALLPOSTGRES=0 /DBHOST=$dbserver /SERVERPORTHTTPS=$https_console_port /SERVERPORTHTTP=$http_console_port /DATAFOLDER=C:\PostgreSQLData /DBUSERNAME=$admin_db_id /DBPORT=5432 /DBPASSWORD=$admin_db_pw /ADMINUSERNAME=$admin_console_id /ADMINPASSWORD=$admin_console_pw"
    } else {
        $arg_list = "/S /SERVERPORTHTTPS=$https_console_port /SERVERPORTHTTP=$http_console_port /DATAFOLDER=C:\PostgreSQLData /DBUSERNAME=$admin_db_id /DBPORT=5432 /DBPASSWORD=$admin_db_pw /ADMINUSERNAME=$admin_console_id /ADMINPASSWORD=$admin_console_pw"
    }

    Write-Log -Message "Executing installer: $exe_full_path" -Level Information

    $install_stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $proc = Start-Process -FilePath $exe_full_path -ArgumentList $arg_list -Wait -PassThru -RedirectStandardOutput "C:\IrisTemp\admin_installer_output.log"
    $install_stopwatch.Stop()
    $duration_sec = [math]::Round($install_stopwatch.Elapsed.TotalSeconds, 1)

    if ($proc.ExitCode -eq 0) {
        Write-Log -Message "Iris Admin installer completed successfully (ExitCode: 0, Duration: $($duration_sec)s)" -Level Information -EventId 1000
    } else {
        Write-Log -Message "Iris Admin installer exited with non-zero ExitCode: $($proc.ExitCode) (Duration: $($duration_sec)s)" -Level Warning -EventId 1001
        Write-Log -Message "Trying to install again..." -Level Information
        $install_stopwatch.Restart()
        $proc = Start-Process -FilePath $exe_full_path -ArgumentList $arg_list -Wait -PassThru -RedirectStandardOutput "C:\IrisTemp\admin_installer_output_retry.log"
        $install_stopwatch.Stop()
        $duration_sec = [math]::Round($install_stopwatch.Elapsed.TotalSeconds, 1)

        if ($proc.ExitCode -eq 0) {
            Write-Log -Message "Iris Admin installer completed successfully on RETRY (ExitCode: 0, Duration: $($duration_sec)s)" -Level Information -EventId 1000
        } else {
            Write-Log -Message "Iris Admin installer exited with non-zero ExitCode on retry: $($proc.ExitCode) (Duration: $($duration_sec)s)" -Level Error -EventId 1001
        }
    }
} catch {
    Write-Log -Message "Exception during install execution: $($_.Exception.ToString())" -Level Error
}

# Post-installation verification
Write-Log -Message "Running post-installation diagnostics..." -Level Information

$uninstall_keys = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\GrayMeta Iris DB Server",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\GrayMeta Iris DB Server",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Iris Admin",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Iris Admin"
)
$installed_version = $null
foreach ($key in $uninstall_keys) {
    if (Test-Path $key) {
        $ver = (Get-ItemProperty -Path $key -ErrorAction SilentlyContinue).DisplayVersion
        if ($ver) {
            $installed_version = $ver
            Write-Log -Message "Found installed registry entry at '$key' (Version: $ver)" -Level Information
            break
        }
    }
}

if ($installed_version) {
    Write-Log -Message "GrayMeta Iris Server version $installed_version installation verification SUCCEEDED." -Level Information
} else {
    Write-Log -Message "GrayMeta Iris Server installation verification FAILED." -Level Error
}

# Dot source the set-serverid script to make its functions available in this session
$setServerIdScript = "$env:ProgramData\Graymeta\Launch\scripts\set-serverid.ps1"
if (Test-Path $setServerIdScript) {
    . $setServerIdScript
    Write-Log -Message "Successfully dot-sourced $setServerIdScript" -Level Information
} else {
    Write-Log -Message "Warning: Script not found at $setServerIdScript" -Level Warning
}

$irisdbvercheck = (Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\GrayMeta Iris DB Server" -ErrorAction SilentlyContinue).DisplayVersion
if ($irisdbvercheck) {
    Write-Log -Message "Starting Server ID tagging process." -Level Information
    $serverid = & 'C:\Program Files\GrayMeta\Iris Admin\Server\IrisWebServerFromDotNetUtil.exe' --GetServerID
    Write-Log -Message "Retrieved Server ID: $serverid" -Level Information
    $instanceid = Get-MetaData -MetaDataType instanceId
    Import-Module AWS.Tools.EC2 -ErrorAction Stop
    New-EC2Tag -Resource $instanceid -Tag @{ Key = "ServerID"; Value = $serverid }
    Write-Log -Message "Tagged instance $instanceid with Server ID $serverid" -Level Information
}

Stop-Transcript -ErrorAction SilentlyContinue