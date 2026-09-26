Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Initiate Cloud Init..."
#Retrieve and prepare Secrets 
    $MaxSessions = "${ia_max_sessions}"
    $keepalivetimeout = "${ia_keepalivetimeout}"
    $certcrtarn = "${ia_cert_crt_arn}"
    $certkeyarn = "${ia_cert_key_arn}"
    $iasecretarn = "${ia_secret_arn}"
    $iadomain = "${ia_domain}"
    $search_enabled = "${search_enabled}"
    $ia_video_bitrate = "${ia_video_bitrate}"
    $ia_video_codec = "${ia_video_codec}"
    $s3_enterprise = "${s3_enterprise}"
    $haproxy = "${haproxy}"
    $saml_enabled = "${saml_enabled}"
    $saml_cert_secret_arn = "${saml_cert_secret_arn}"
    $disk_data_size = "${disk_data_size}"
    $otlp_enabled = "${otlp_enabled}"
    $otlp_agent_gateway_endpoint = "${otlp_exporter_destination}"
    #$wasabi = "${wasabi}"
    $file_gateway = "${file_gateway}"
    $file_gateway_ip = "${file_gateway_ip}"
    $file_gateway_id = "${file_gateway_id}"
    $file_gateway_shares = "${file_gateway_shares}"
    $file_gateway_link_root = "${file_gateway_link_root}"
    #Retrieve and prepare Secrets
    try {
        $secretdata = get-SECsecretValue $iasecretarn ; $secretdata=$secretdata.secretstring | convertfrom-json
        #Set init variables
        $admin_customer_id      = $secretdata.admin_customer_id
        $admin_db_id            = $secretdata.admin_db_id
        $admin_db_pw            = $secretdata.admin_db_pw
        $admin_server           = $secretdata.admin_server
        $okta_issuer            = $secretdata.okta_issuer
        $okta_clientid	        = $secretdata.okta_clientid
        $okta_redirecturi       = $secretdata.okta_redirecturi
        $okta_scope             = $secretdata.okta_scope
        $os_endpoint            = $secretdata.os_endpoint
        $os_region              = $secretdata.os_region
        $saml_uniqueid          = $secretdata.saml_uniqueid
        $saml_displayname       = $secretdata.saml_displayname
        $saml_entryPoint        = $secretdata.saml_entryPoint
        $saml_samlissuer        = $secretdata.saml_samlissuer
        $saml_acsUrlBasePath    = $secretdata.saml_acsUrlBasePath
        $saml_acsUrlRelativePath = $secretdata.saml_acsUrlRelativePath
        $rfm_filters             = $secretdata.rfm_filters
        #$otlp_agent_gateway_endpoint = $secretdata.otlp_agent_gateway_endpoint
        #$wasabi_access_key       = $secretdata.wasabi_access_key
        #$wasabi_secret_access_key= $secretdata.wasabi_secret_access_key
        #$wasabi_endpoint         = $secretdata.wasabi_endpoint
        #$wasabi_region            = $secretdata.wasabi_region
        #$wasabi_buckets          = $secretdata.wasabi_buckets
    }
    catch {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Exception accessing secret $iasecretarn"
    }


    #S3 File Gateway shares replace the rclone mounts; local_init only uses s3_enterprise for rclone
    if ($file_gateway -eq "true") {
        $s3_enterprise = "false"
    }

    try {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Initiate local_init... "
        & "C:\ProgramData\GrayMeta\launch\scripts\local_init_enterprise_rclone.ps1"
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Completed local_init"
    } catch {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType `
        Error -eventid 1002 -message "Exception executing local_init_enterprise_rclone.ps1: $_"
    }

#Map S3 File Gateway shares as <link root>\<bucket>
#fgw-watchdog maps any missing share and link at startup and every 3 minutes, so instances
#that boot while the gateway is stopped or rebooting pick up the shares once it is back.
if ($file_gateway -eq "true") {
    try {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Configuring File Gateway shares from $file_gateway_ip"

        #bucketmount.ps1 and watchdog.ps1 are not generated in this mode
        foreach ($task in "launch-rclone", "rclone-watchdog") {
            Disable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | Out-Null
        }
        Set-SmbClientConfiguration -EnableBandwidthThrottling $false -Force

        if (-not (Test-Path "C:\fgw")) {
            New-Item -Path "C:\fgw" -ItemType Directory | Out-Null
        }
        @{
            ip         = $file_gateway_ip
            gateway_id = $file_gateway_id
            shares     = @($file_gateway_shares.Split(",", [System.StringSplitOptions]::RemoveEmptyEntries))
            link_root  = $file_gateway_link_root
            secret_arn = $iasecretarn
        } | ConvertTo-Json | Set-Content -Path "C:\fgw\config.json"

$fgwWatchdog = @'
$config = Get-Content -Path "C:\fgw\config.json" -Raw | ConvertFrom-Json
$log    = "C:\Logs\fgw-watchdog.log"

function Log($m) {
    Add-Content -Path $log -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m"
}

if (-not (Test-Path $config.link_root)) {
    New-Item -Path $config.link_root -ItemType Directory | Out-Null
}

$cred = $null
foreach ($share in $config.shares) {
    $remote = "\\$($config.ip)\$share"

    #Global mappings are visible to every user and service, including iris-service
    if (-not (Get-SmbGlobalMapping -RemotePath $remote -ErrorAction SilentlyContinue)) {
        try {
            if (-not $cred) {
                Import-Module AWSPowerShell -ErrorAction SilentlyContinue
                $region = $config.secret_arn.Split(":")[3]
                $secret = (Get-SECSecretValue -SecretId $config.secret_arn -Region $region).SecretString | ConvertFrom-Json
                $password = ConvertTo-SecureString $secret.filegateway_smb_password -AsPlainText -Force
                $cred = New-Object System.Management.Automation.PSCredential("$($config.gateway_id)\smbguest", $password)
            }
            New-SmbGlobalMapping -RemotePath $remote -Credential $cred -Persistent $true -ErrorAction Stop | Out-Null
            Log "Mapped $remote"
        } catch {
            Log "Could not map $remote : $($_.Exception.Message)"
        }
    }

    #Look for the link itself; Test-Path follows it and is false while the gateway is unreachable
    #mklink creates the link even while the gateway is unreachable
    if (-not (Get-ChildItem -Path $config.link_root -Force | Where-Object Name -eq $share)) {
        $link = Join-Path $config.link_root $share
        cmd /c mklink /D "$link" "$remote" | Out-Null
        if ($LASTEXITCODE -eq 0) { Log "Linked $link to $remote" } else { Log "Could not link $link to $remote" }
    }
}
'@
        Set-Content -Path "C:\fgw\fgw-watchdog.ps1" -Value $fgwWatchdog

        $dt = Get-Date
        $action    = New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "C:\fgw\fgw-watchdog.ps1"'
        $triggers  = @(
            (New-ScheduledTaskTrigger -AtStartup),
            (New-ScheduledTaskTrigger -Once -At $dt -RepetitionInterval (New-TimeSpan -Minutes 3) -RepetitionDuration ($dt.AddYears(25) - $dt))
        )
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
        Register-ScheduledTask -TaskName "fgw-watchdog" -Action $action -Trigger $triggers -Principal $principal -Settings $settings -Description "Maps S3 File Gateway shares and links" -Force | Out-Null

        #First pass now; the gateway is normally up before instances launch
        & "C:\fgw\fgw-watchdog.ps1"
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Configured File Gateway shares and fgw-watchdog task"
    } catch {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1003 -message "Exception configuring File Gateway shares: $_"
    }
}

#Start SSM Service
Set-Service -Name AmazonSSMAgent -StartupType Automatic ; Start-Service AmazonSSMAgent

#Update Instance
$instanceid = Get-MetaData -MetaDataType "instanceId"

[System.Environment]::SetEnvironmentVariable('INSTANCE_ID', $instanceid, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('INSTANCE_NAME', "${name}-$instanceid", [System.EnvironmentVariableTarget]::Machine)

Import-Module -Name AWSPowerShell #deprecated
#Import-Module AWS.Tools.S3  -ErrorAction Stop
#Import-Module AWS.Tools.EC2 -ErrorAction Stop


$tag = New-Object Amazon.EC2.Model.Tag
$tag.Key = "Name"
$tag.Value = "${name}-$instanceid"
New-EC2Tag -Resource $instanceid -Tag $tag

Rename-Computer -NewName $instanceid -force
Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Cloud Init Complete - Restarting EC2 Instance"