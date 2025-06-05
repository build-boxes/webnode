if (-Not (Test-Path -Path 'C:\\Temp')) {
	New-Item -ItemType Directory -Path 'C:\\Temp'
};
$cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\\LocalMachine\\My;
$thumbprint = $cert.Thumbprint;
$certPath = 'C:\\Temp\\winrm-cert.cer';
Export-Certificate -Cert "Cert:\\LocalMachine\\My\\$thumbprint" -FilePath $certPath;
Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\\LocalMachine\\Root;
New-Item -Path WSMan:\\localhost\\Listener -Transport HTTPS -Address * -CertificateThumbprint $thumbprint -Force;
Set-Item -Path WSMan:\\localhost\\Service\\Auth\\Basic -Value $true;
New-NetFirewallRule -Name "WinRM_HTTPS" -DisplayName "WinRM over HTTPS" -Protocol TCP -LocalPort 5986 -Action Allow;
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-WebRequest -Uri 'https://community.chocolatey.org/install.ps1' -UseBasicParsing | Invoke-Expression
};
choco install python --version=3.12 -y;
exit 0;
