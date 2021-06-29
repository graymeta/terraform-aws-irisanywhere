<powershell>
$iasecretarn = "${ia_secret_arn}"

#Retrieve and prepare Secrets
try {
    $secretdata = get-SECsecretValue $iasecretarn ; $secretdata=$secretdata.secretstring | convertfrom-json
    #Set init variables
    $admin_db_id        = $secretdata.admin_db_id
    $admin_db_pw        = $secretdata.admin_db_pw
    $admin_console_id   = $secretdata.admin_console_id
    $admin_console_pw   = $secretdata.admin_console_pw

    #TEMP create event log for debugging
    New-EventLog -LogName IrisAdmin -Source "IrisAdmin" ; Start-Sleep -Seconds 10
    Write-EventLog -LogName IrisAdmin -source IrisAdmin -EntryType Information -eventid 1001 -message "I have started initializing"
    $secretdata | export-csv c:\creds.csv -NoTypeInformation
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception accessing secret $iasecretarn" -ForegroundColor Red 
    Write-EventLog -LogName IrisAdmin -source IrisAdmin -EntryType Error -eventid 1001 -message "Exception accessing secret $iasecretarn"
}

$start_time=$(((get-date).ToUniversalTime()).ToString("yyyyMMddTHHmmssZ"))
$start_time

$iris_admin_exe = gci "$($env:systemdrive)\IrisTemp\" | where {$_.name -like "*.exe*"} | select -ExpandProperty name

Write-Host "Message: Installing IrisAdmin $iadbversion"  -ForegroundColor Green
try {
    Start-Process -FilePath "C:\IrisTemp\$($iris_admin_exe)" -ArgumentList  "/S /DATAFOLDER=C:\PostgreSQLData /DBUSERNAME=$admin_db_id /DBPORT=5432 /DBPASSWORD=$admin_db_pw /ADMINUSERNAME=$admin_console_id /ADMINPASSWORD=$admin_console_pw" -Wait -PassThru

    Write-EventLog -LogName IrisAdmin -source IrisAdmin -EntryType Information -eventid 1000 -message "Iris Admin installed"
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception during install process."   
    Write-EventLog -LogName IrisAdmin -source IrisAdmin -EntryType Error -eventid 1001 -message "Iris Admin failed to install"
}
#Check and Cleanup
$irisdbvercheck = Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\GrayMeta Iris DB Server" -name Displayversion | select -ExpandProperty displayversion 
Write-host "GrayMeta Iris Server version $irisdbvercheck installed"  -ForegroundColor Green
</powershell>