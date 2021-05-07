#Install Certificates

#If Domain Root Cert is not installed, Install it.
Write-Host "Testing Root Certificate Validity"
try{
    $CertStatus = Test-Certificate -Cert cert:\LocalMachine\root\7058F03C9972205361782C918C219473CCE853F0
    Write-Host "Root Certificate Valid"
}
catch {
    $CertStatus = $False
    Write-Host "Root Certificate Invalid"
}
if(-Not $CertStatus){
    Write-Host "Importing Root Certificate"
    Import-Certificate -FilePath "\\hpfod.net\NETLOGON\Certificates\PsmCerts01-2039.crt" -CertStoreLocation cert:\LocalMachine\root
}


Write-Host "Check if domain signed Machine Certificate is installed"
try{
    $StoreScope = "LocalMachine"
    $StoreName = "My"
    Write-Host "Opening Certificate Store: $Storename $StoreScope"
    $Store = New-Object System.Security.Cryptography.X509Certificates.X509Store $StoreName, $StoreScope
    $Store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
    Write-Host "Looking up certificate issuer"
    $certs = $Store.certificates | ?{$_.EnhancedKeyUsageList -match "Remote"  -and $_.Issuer -notmatch (hostname)}
    
    if($certs.count -lt 1){
        Write-Host "No Certs found, creating certificate"      
        $MachineCertificate = get-certificate -Template "FOD-ComputerRDP" -DnsName (hostname) -SubjectName "CN=$(hostname)" -CertStoreLocation cert:\$StoreScope\$Storename
        Write-Host "New Cert: $MachineCertificate"  
        
        Write-Host "Load new certificate"  
        $Store = New-Object System.Security.Cryptography.X509Certificates.X509Store $StoreName, $StoreScope
        $Store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
        $certs = $Store.certificates | ?{$_.EnhancedKeyUsageList -match "Remote"  -and $_.Issuer -notmatch (hostname)}
    }
    
}
catch {
    $Store.Close()
    $Error
}


Write-Host "Check if RDP certificate is CA signed"
try{
    $RDPStoreScope = "LocalMachine"
    $RDPStoreName = "Remote Desktop"
    Write-Host "Opening Certificate Store: $RDPStoreName $RDPStoreScope"
    $RDPStore = New-Object System.Security.Cryptography.X509Certificates.X509Store $RDPStoreName, $RDPStoreScope
    $RDPStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    Write-Host "Looking up signed remote certificates"
    $RDPCertificates = $RDPStore.certificates | ?{$_.EnhancedKeyUsageList -match "Remote"  -and $_.Issuer -notmatch (hostname)}
    if($RDPCertificates.count -lt 1){
        Write-Host "No RDP Signed Certificates Installed"
        foreach ($Certificate in $certs){
            Write-Host "Installing Signed Remote Certificate: $Certificate"
            $RDPStore.Add($Certificate)
        }
    }
    $SelfSignedRDPCertificates = $RDPStore.certificates | ?{$_.Issuer -match (hostname)}
    if($SelfSignedRDPCertificates.count -gt 0){
    Write-Host "Found Self Signed certificates"
        foreach ($Certificate in $SelfSignedRDPCertificates){
        Write-Host "Removing Certificate: $Certificate"
            $RDPStore.Remove($Certificate)
        }
    }
}
catch {
    $Store.Close()
    $RDPStore.Close()
    $Error
}


Write-host "Closing Certificate Stores."
$Store.Close()
$RDPStore.Close()
if($RDPCertificates.count -lt 1){
    Write-host "Restarting Terminal Services to load new certificate."
    get-service sessionenv | restart-service -force
    get-service termservice | restart-service -force
}
Write-host "Finished."
