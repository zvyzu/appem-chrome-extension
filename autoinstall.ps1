#=====================
# Cek Koneksi Internet
#=====================

# Cek Koneksi ke www.google.com
If (-Not (Test-Connection www.google.com -Count 1 -Quiet)) {
    Write-Host "Tidak dapat terkoneksi ke internet, Cek koneksi internet anda."
    Start-Sleep -s 5
    exit
}

#=============================
# Mengecek dan menginstall Git
#=============================

Function Install-choco {
    #Pengecekan Chocolatey sudah terinstall
    if ((Get-Command -Name choco -ErrorAction Ignore) -and ($chocoVersion = (Get-Item "$env:ChocolateyInstall\choco.exe" -ErrorAction Ignore).VersionInfo.ProductVersion)) {
        Write-Output "Chocolatey Versi $chocoVersion sudah terinstall"
    } else {
        Write-Output "Menginstall Chocolatey"
        Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        powershell choco feature enable -n allowGlobalConfirmation
    }
}

Function Install-git {
    #Penginstallan Git menggunakan Chocolatey
    try {
        # Nama package official Git adalah "git.install" bukan "git"
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-command choco install git.install --yes | Out-Host" -WindowStyle Normal
        Start-Sleep -s 10
        Wait-Process choco -Timeout 240 -ErrorAction SilentlyContinue
    } catch [System.InvalidOperationException] {
        Write-Warning "Klik Yes di User Access Control untuk Menginstall"
    } catch {
        Write-Error $_.Exception
    }
}

# Cek jika git sudah terinstall
if (-Not (Get-Command -Name git -ErrorAction Ignore)) {
    Install-choco
    Install-git
}
