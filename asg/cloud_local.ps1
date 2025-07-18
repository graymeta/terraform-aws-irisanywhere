Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 6009 -message "TIMING: Cloud_init start at $(Get-Date)"
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
    $wasabi = "${wasabi}"
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
        $os_accessid            = $secretdata.os_accessid
        $os_secretkey           = $secretdata.os_secretkey
        $saml_uniqueid          = $secretdata.saml_uniqueid
        $saml_displayname       = $secretdata.saml_displayname
        $saml_entryPoint        = $secretdata.saml_entryPoint
        $saml_samlissuer        = $secretdata.saml_samlissuer
        $saml_acsUrlBasePath    = $secretdata.saml_acsUrlBasePath
        $saml_acsUrlRelativePath= $secretdata.saml_acsUrlRelativePath
        $wasabi_access_key       = $secretdata.wasabi_access_key
        $wasabi_secret_access_key= $secretdata.wasabi_secret_access_key
        $wasabi_endpoint         = $secretdata.wasabi_endpoint
        $wasabi_region            = $secretdata.wasabi_region
        $wasabi_buckets          = $secretdata.wasabi_buckets
    }
    catch {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Exception accessing secret $iasecretarn"
    }

#Run init locally
Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "cache_content is: $cache_content"

& "C:\ProgramData\GrayMeta\launch\scripts\local_init_enterprise_rclone.ps1"

#Start SSM Service
Set-Service -Name AmazonSSMAgent -StartupType Automatic ; Start-Service AmazonSSMAgent

#Update Instance
    $instanceid = Get-MetaData -MetaDataType "instanceId"

    [System.Environment]::SetEnvironmentVariable('INSTANCE_ID', $instanceid, [System.EnvironmentVariableTarget]::Machine)
    [System.Environment]::SetEnvironmentVariable('INSTANCE_NAME', "${name}-$instanceid", [System.EnvironmentVariableTarget]::Machine)

    Import-Module -Name AWSPowerShell
    $tag = New-Object Amazon.EC2.Model.Tag
    $tag.Key = "Name"
    $tag.Value = "${name}-$instanceid"
    New-EC2Tag -Resource $instanceid -Tag $tag
    
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Init Complete - Restarting"
    Rename-Computer -NewName $instanceid -force