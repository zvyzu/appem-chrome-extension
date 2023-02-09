#=====================
# Cek Koneksi Internet
#=====================

$net = (Test-Connection www.google.com -Count 1 -Quiet)
If ($net -ne "True") {
    Write-Host "Tidak dapat terkoneksi ke internet, Cek koneksi internet anda."
    Start-Sleep -Seconds 5
    exit
}

#===================
# Fungsi install Git
#===================

Function Install-Git {
    #Pengecekan chocolatey sudah terinstall
    if ((Get-Command -Name choco -ErrorAction Ignore) -and ($chocoVersion = (Get-Item "$env:ChocolateyInstall\choco.exe" -ErrorAction Ignore).VersionInfo.ProductVersion)) {
        Write-Output "Chocolatey Versi $chocoVersion sudah terinstall"
    } else {
        Write-Output "Menginstall Chocolatey"
        Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        powershell choco feature enable -n allowGlobalConfirmation
    }
    
    #Penginstallan Git menggunakan Chocolatey
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-command choco install git.install --yes | Out-Host" -WindowStyle Normal
    }
    catch [System.InvalidOperationException] {
        Write-Warning "Klik Yes di User Access Control untuk Menginstall"
    }
    catch {
        Write-Error $_.Exception
    }
}

#==============================
# Cek jika git sudah terinstall
#==============================

if (Get-Command -Name git -ErrorAction Ignore) {
    Write-Output "Git sudah terinstall"
} else {Install-Git}

