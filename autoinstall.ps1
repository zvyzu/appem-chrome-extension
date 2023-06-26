#=====================
# Cek Koneksi Internet
#=====================

function Start-ping {
    if (-Not(Test-Connection www.google.com -Count 1 -Quiet)) {
        Clear-Host
        Write-Host ' '
        Write-Host 'Tidak dapat terkoneksi ke internet!'
        Write-Host ' '
        Write-Host 'Cek koneksi internet anda.'
        Start-Sleep -Seconds 5
        exit
    }
    else {
        if (-Not(Test-Connection github.com -Count 1 -Quiet)) {
            Write-Host 'Tidak dapat terkoneksi ke github.com!'
        }
    }
}

#=============================
# Mengecek dan menginstall Git
#=============================

function Test-choco {
    # Pengecekan Chocolatey sudah terinstall
    if ((Get-Command -Name choco -ErrorAction Ignore) -and ($chocoVersion = (Get-Item "$env:ChocolateyInstall\choco.exe" -ErrorAction Ignore).VersionInfo.ProductVersion)) {
        Write-Output "Chocolatey Versi $chocoVersion sudah terinstall"
    }
    else {
        Start-ping
        Write-Output "Menginstall Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        powershell choco feature enable -n allowGlobalConfirmation
    }
}

function Install-git {
    Start-ping

    # Penginstallan Git menggunakan Chocolatey
    try {
        # Nama package official Git adalah "git.install" bukan "git"
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-command choco install git.install --yes | Out-Host" -WindowStyle Normal
        Start-Sleep -Seconds 10
        Wait-Process choco -Timeout 240 -ErrorAction SilentlyContinue
    }
    catch [System.InvalidOperationException] {
        Write-Warning "Klik Yes di User Access Control untuk Menginstall"
    }
    catch {
        Write-Error $_.Exception
        Start-Sleep -Seconds 10
    }
}

function Start-re_run {
    Start-Process cmd.exe -ArgumentList "/c powershell Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://s.id/appembeta'))"
    Exit
}

function Test-git {
    # Cek jika git sudah terinstall
    if (-Not(Get-Command -Name git -ErrorAction Ignore)) {
        Install-git
        Start-re_run
    }
    else {
        Clear-Host
        Write-Host ' OK'
        # choco outdated
    }
}

function main {
    Test-choco
    Test-git
    Write-Host 'End'
}

main
