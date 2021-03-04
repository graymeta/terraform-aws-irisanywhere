<powershell>

$irisadminuid  = "${iadm_uid}"
$irisadminpw   = "${iadm_pw}"
$irisadmindbid = "${iadmdb_uid}"
$irisadmindbpw = "${iadmdb_pw}"

$start_time=$(((get-date).ToUniversalTime()).ToString("yyyyMMddTHHmmssZ"))
$start_time

$iris_admin_exe = gci "$($env:systemdrive)\IrisTemp\" | where {$_.name -like "*.exe*"} | select -ExpandProperty name

Write-Host "Message: Installing IrisAdmin $iadbversion"  -ForegroundColor Green
try {
    Start-Process -FilePath "C:\IrisTemp\$($iris_admin_exe)" -ArgumentList  "/S /DATAFOLDER=C:\PostgreSQLData /DBUSERNAME=$irisadmindbid /DBPORT=5432 /DBPASSWORD=$irisadmindbpw /ADMINUSERNAME=$irisadminuid /ADMINPASSWORD=$irisadminpw" -Wait -PassThru

    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Iris Admin installed"
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception during install process."   
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Iris Admin failed to install"
}
#Check and Cleanup
$irisdbvercheck = Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\GrayMeta Iris DB Server" -name Displayversion | select -ExpandProperty displayversion 
Write-host "GrayMeta Iris Server version $irisdbvercheck installed"  -ForegroundColor Green

</powershell>