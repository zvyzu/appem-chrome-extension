#=================
# Global Variables
#=================

# Nama folder untuk menampung chrome extension lain
$folder = "chrome-extension"

# Nama folder untuk sipd-chrome-extension
$sipd = "sipd-chrome-extension"

# Pengecekan drive D:
if (Test-Path "D:\" ) {
    $dir = "D:\$folder"
}
else {
    $dir = "$env:SystemDrive\$folder"
}

# Pemanggilan git.exe dari $git_path jika pemanggilan git secara global gagal
if ([Environment]::OSVersion.Version -lt (new-object 'Version' 8,1)) { # Pengecekan Windows 7
    Write-Host 'Silakan Upgrade / Update Windows Anda ke Windows 11 Atau Windows 10'
}
else {
    $git_path = "$env:ProgramFiles\Git\cmd\git.exe"
}

#====================
#  Global Functions
#====================

function Start-Pause { # Jeda Script jika terjadi Error
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
}

function Start-ping { # Cek Koneksi Internet
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

function Install-choco {
    if (-Not((Get-Command -Name choco -ErrorAction Ignore | Out-Null) -and (Get-Item "$env:ChocolateyInstall\choco.exe" -ErrorAction Ignore).VersionInfo.ProductVersion)) {
        Start-ping
        Write-Output "Menginstall Chocolatey..."

        if(-Not([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
            Start-Process -FilePath "powershell.exe" -Verb "RunAs" -ArgumentList "-command irm https://raw.githubusercontent.com/evanvyz/appem-chrome-extension/beta/autoinstall.ps1 | iex | Out-Host"
            Exit
        }

        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
            powershell choco feature enable -n allowGlobalConfirmation
        }
        catch {
            throw [ChocoFailedInstall]::new('Gagal menginstall')
        }
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
        Start-Pause
    }
}

function Test-git {
    # Cek jika git sudah terinstall
    if (-Not(Get-Command -Name git -ErrorAction Ignore)) {
        Install-choco
        Install-git
    }
    else {
        Clear-Host
        Write-Host ' '
        # choco outdated
    }
}

#==================================
#  Melakukan git clone / git pull
#==================================

function Edit-gitconfig { # Memperbaiki masalah git unsafe.directory
    if (Test-Path $env:USERPROFILE\.gitconfig) {
        if (Test-Path "D:\" ) {
            $drive = "D:"
        }
        else {
            $drive = "$env:SystemDrive"
        }

        $git_safedir = Get-Content $env:USERPROFILE\.gitconfig | Select-String -Pattern "$drive/$folder/$sipd"
        if ($null -eq $git_safedir -or $git_safedir -eq '') {
            $gitconfig = @"
            directory = $drive/$folder/$sipd
"@
            $gitconfig | Out-File -Encoding utf8 -LiteralPath "$env:USERPROFILE\.gitconfig" -Append -Force
            Start-Sleep -Seconds 1
        }
    }
}

function Start-Git_Clone_Sipd {
    Start-ping

    Write-Host "OK"
    Start-Pause

    # Mengecek folder sudah ada
    if (Test-Path "$dir\$sipd") {
        Remove-Item -LiteralPath "$dir\$sipd" -Force -Recurse
    }

    # Melakukan git clone
    try {
        if (Get-Command -Name git -ErrorAction Ignore) {
            Start-Process powershell.exe -ArgumentList "-command git clone https://github.com/agusnurwanto/sipd-chrome-extension.git $drive\$sipd | Out-Host"
        }
        else {
            Start-Process -FilePath $git_path -ArgumentList "clone https://github.com/agusnurwanto/sipd-chrome-extension.git $dir\$sipd"
        }
        Start-Sleep -s 3
        Wait-Process git -Timeout 120 -ErrorAction SilentlyContinue
    }
    catch {
        Write-Error $_.Exception
        Start-Pause
    }

    Start-Sleep -s 2
    if (Test-Path "$dir\$sipd") {
        Test-configjs
    }
    else {
        Write-Host 'sipd-chrome-extension belum terclone!'
        Start-Pause
    }
}

function Start-Git_Pull_Sipd {
    Edit-gitconfig

    if (Get-Command -Name git -ErrorAction Ignore) {
        try { # Melakukan git pull
            Write-Host ' '
            Write-Host 'Menjalankan git pull :'
            git -C $dir\$sipd pull origin master
            Start-Sleep -s 5
            Wait-Process git -Timeout 60 -ErrorAction SilentlyContinue
        }
        catch {
            Write-Error $_.Exception
            Start-Pause
        }
    }

    Test-configjs
}

function Test-configjs {
    # Mengecek config.js
    if (-Not(Test-Path "$dir\$sipd\config.js")) {
        Edit-configjs
    }
}

function Test-sipd_chrome_extension {
    if (Test-Path "$dir\$sipd") {
        # Daftar file dan folder sipd-chrome-extension
        $files = @(
            '.git',
            'css',
            'excel\BANKEU.xlsx',
            'excel\BOS-HIBAH.xlsx',
            'img\indonesia-flag.png',
            'img\logo.png',
            'js',
            '.gitignore',
            'config.js.example',
            'manifest.json',
            'popup.html',
            'README.md'
        )
        # Mengecek kelengkapan file sipd-chrome-extension
        foreach ($file in $files) {
            if (-Not(Test-Path "$dir\$sipd\$file")) {
                Write-Host ' '
                Write-Host "File / folder di dalam $sipd tidak lengkap!"
                Write-Host ' '
                Write-Host "Menghapus folder $sipd..."
                Remove-Item -Path "$dir\$sipd" -Force -Recurse
                Write-Host ' '
                Write-Host 'Menjalankan git clone...'
                Write-Host ' '
                Start-Git_Clone_Sipd
                break
            }
        }
        Start-Git_Pull_Sipd
    }
    else {
        Start-Git_Clone_Sipd
    }
}

#==========================================
#  Menu Buka SIPD / Install Google Chrome
#==========================================

function Install-Chrome {
    Write-Host ' '
    Write-Host 'Ketik "y" lalu tekan Enter untuk menginstall Google Chrome'
    Write-Host ' '
    $confirm = Read-Host "Download dan install Google Chrome?"
    if ($confirm -eq "y") {
        Start-ping
        try {
            # Perlu di ingat choco install googlechrome akan menginstall tidak peduli chrome sudah terinstall
            Start-Process powershell.exe -Verb RunAs -ArgumentList "-command choco install googlechrome --yes | Out-Host" -WindowStyle Normal
            Start-Sleep -s 10
            Wait-Process choco -Timeout 240 -ErrorAction SilentlyContinue
        }
        catch [System.InvalidOperationException] {
            Write-Warning "Klik Yes di User Access Control untuk Menginstall"
        }
        catch {
            Write-Error $_.Exception
            Start-Pause
        }
    }
}

function Open-Sipd {
    Test-configjs

    # Mengecek Proses Google Chrome sedang berjalan dan menutupnya
    $chrome = Get-Process chrome -ErrorAction SilentlyContinue
    if ($chrome) {
        Clear-Host
        Write-Host ' '
        Write-Host 'Google Chrome Sedang Berjalan!'
        Write-Host ' '
        $clschrome = Read-Host 'Ketik "y" lalu tekan Enter untuk menutup Google Chrome'
        if ($clschrome -eq "y") {
            if ($chrome) {
                Write-Host ' '
                Write-Host 'Sedang menutup Google Chrome...'
                $chrome.CloseMainWindow()|Out-Null
                Start-Sleep -Seconds 3
                if (!$chrome.HasExited) {
                    $chrome | Stop-Process -Force
                }
            }
        }
        else {
            if ($chrome) {
                Start-Menu
            }
        }
    }

    if (Test-Path "$dir\$sipd\config.js") {
        # Mengambil url sipd dari config.js
        $get_url_configjs = Get-Content "$dir\$sipd\config.js" | Select-String -Pattern '\.sipd\.kemendagri\.go\.id' | Out-String

        if ($get_url_configjs -ne '' -or $null -ne $get_url_configjs) {
            $url_daerah_sipd = $get_url_configjs.Trim().Trim('sipd_url : "').Trim('// alamat sipd sesuai kabupaten kota masing-masing').Trim(',"')
        }
        else {
            Edit-configjs
        }
    }
    else {
        Edit-configjs
    }

    Clear-Host
    Write-Host ' '
    Write-Host 'Ketik "y" dan tekan Enter untuk membuka SIPD.'
    Write-Host ' '
    $confirm = Read-Host "Buka SIPD?"
    if ($confirm -eq "y") {
        try {
            # Membuka SIPD dengan chrome extension sipd-chrome-extension (Bersifat tidak permanen / hilang jika ditutup)
            Start-Process chrome.exe -ArgumentList "--load-extension=$dir\$sipd", "$url_daerah_sipd"
        }
        catch {
            Write-Host ' '
            Write-Warning "Google Chrome Belum terinstall."
            Write-Host ' '
            Install-Chrome
        }
    }
}

#=============================================
#  Menu git pull ulang sipd-chrome-extension
#=============================================

function Confirm-git_pull {
    Clear-Host
    Write-Host ' '
    Write-Host "Ketik y dan tekan Enter untuk git pull ulang $sipd."
    Write-Host ' '
    $confirm = Read-Host "git pull ulang $sipd?"
    if ($confirm -eq 'y') {
        Start-Git_Pull_Sipd
    }
}

#==========================================
#  Menu Clone ulang sipd-chrome-extension
#==========================================

function Confirm-git_clone {
    Clear-Host
    Write-Host ' '
    Write-Host "Ketik y dan tekan Enter untuk git clone ulang $sipd."
    Write-Host ' '
    $confirm = Read-Host "git clone ulang $sipd?"
    if ($confirm -eq 'y') {
        Start-Git_Clone_Sipd
    }
}

#===========================================
#  Menu update aplikasi Git dan Chocolatey
#===========================================

function Confirm-update_git {
    Clear-Host
    Write-Host ' '
    Write-Host 'Ketik "y" dan tekan Enter untuk update aplikasi Git.'
    Write-Host ' '
    $confirm = Read-Host "Update aplikasi Git?"
    if ($confirm -eq "y") {
        Start-ping

        try {
            # Nama package official Git adalah "git.install" bukan "git"
            Start-Process powershell.exe -Verb RunAs -ArgumentList "-command choco upgrade git.install --yes | Out-Host" -WindowStyle Normal
            Start-Sleep -s 10
            Wait-Process choco -Timeout 240 -ErrorAction SilentlyContinue
        }
        catch [System.InvalidOperationException] {
            Write-Warning "Klik Yes di User Access Control untuk Menginstall"
        }
        catch {
            Write-Error $_.Exception
            Start-Pause
        }

        try {
            Start-Process powershell.exe -Verb RunAs -ArgumentList "-command choco upgrade chocolatey --yes | Out-Host" -WindowStyle Normal
            Start-Sleep -s 10
            Wait-Process choco -Timeout 240 -ErrorAction SilentlyContinue
        }
        catch [System.InvalidOperationException] {
            Write-Warning "Klik Yes di User Access Control untuk Menginstall"
        }
        catch {
            Write-Error $_.Exception
            Start-Pause
        }
    }
}

#===================================
#  Menu Install ulang aplikasi Git
#===================================

function Confirm-reinstall_git {
    Clear-Host
    Write-Host ' '
    Write-Host 'Ketik "y" dan tekan Enter untuk install ulang aplikasi Git.'
    Write-Host ' '
    $confirm = Read-Host "Install ulang aplikasi Git?"
    if ($confirm -eq "y") {
        try {
            # Nama package official Git adalah "git.install" bukan "git"
            Start-Process powershell.exe -Verb RunAs -ArgumentList "-command choco uninstall git.install --yes | Out-Host" -WindowStyle Normal
            Start-Sleep -s 10
            Wait-Process choco -Timeout 240 -ErrorAction SilentlyContinue
        }
        catch [System.InvalidOperationException] {
            Write-Warning "Klik Yes di User Access Control untuk Menginstall"
        }
        catch {
            Write-Error $_.Exception
            Start-Pause
        }
        Install-git
    }
}

#===========================================
#  Menu Download dan install Google Chrome
#===========================================

function Confirm-chrome {
    Clear-Host
    write-Host ' '
    write-Host 'Mengecek Google Chrome terinstall...'
    write-Host ' '
    try {
        # choco install googlechrome akan paksa install tidak peduli chrome sudah terinstall!
        Start-Process chrome.exe
        Wait-Process chrome -Timeout 1 -ErrorAction SilentlyContinue
        Get-Process chrome | Stop-Process -Force
        Write-Host 'Google Chrome sudah terinstall.'
        Start-Sleep -s 5
    }
    catch {
        Install-Chrome
    }
}

#=======================================
#  Menu Tentang sipd-chrome-extension.
#=======================================

function Open-about_sipd_chrome_extension {
    Clear-Host
    Write-Host ' '
    Write-Host "Ketik y dan tekan Enter untuk tentang $sipd."
    Write-Host ' '
    $confirm = Read-Host "Buka Tentang $sipd?"
    if ($confirm -eq "y") {
        try {
            Start-Process chrome.exe -ArgumentList "--load-extension=$dir\$sipd", "https://github.com/agusnurwanto/sipd-chrome-extension#readme"
        }
        catch {
            Write-Host ' '
            Write-Warning 'Google Chrome Belum terinstall!'
            Write-Host ' '
            Install-Chrome
        }
    }
}

#===================
#  Edit config.js
#===================

function Edit-configjs {
    $list_tahun = @'
Tahun Anggaran:
1 2021
2 2022
3 2023
4 2024
5 2025
6 2026
7 2027
8 2028
9 Ketik manual

0 Kembali ke Menu Utama
'@

    # Menampilkan input id daerah dan url sipd lalu mereplace file config.js
    function Show-id_url {
        $show_conf = @"
Konfigurasi config.js:

Tahun Anggaran: $tahun_anggaran
ID Daerah: $id_daerah
URL SIPD: https://$i.sipd.kemendagri.go.id/

Menyimpan ke $dir\$sipd\config.js
"@

        Clear-Host
        Write-Host ' '
        Write-Host $show_conf
        Start-Sleep -s 5
    }

    # melakukan tindakan sesuai input user
    do {
        Clear-Host
        # if (-Not(Test-Path "$dir\$sipd\config.js")) {Write-Host ''}
        Write-Host ' '
        Write-Host $list_tahun
        $pilih_th = Read-Host "Pilih Tahun Anggaran"
        switch ($pilih_th) {
            1 {$tahun_anggaran = "2021"}
            2 {$tahun_anggaran = "2022"}
            3 {$tahun_anggaran = "2023"}
            4 {$tahun_anggaran = "2024"}
            5 {$tahun_anggaran = "2025"}
            6 {$tahun_anggaran = "2026"}
            7 {$tahun_anggaran = "2027"}
            8 {$tahun_anggaran = "2028"}
            9 {
                Write-Host ' '
                $tahun_anggaran = Read-Host "Tahun Anggaran"
            }
            0 {Start-Menu}
        }
    }
    until ($null -ne $tahun_anggaran)

    Show-Provinsi

    # Di Pisah ke function Edit-URL_SIPD ini karena list daerah yang terlalu panjang
}

#=================
#  Menu Aplikasi
#=================

function Start-Menu {
    $title = 'Menu APPEM Chrome Extension'
    $menu_list = @"
================ $title ================

1 Buka SIPD.
2 Update ulang sipd-chrome-extension
3 Clone ulang sipd-chrome-extension
4 Update aplikasi Git
5 Install ulang aplikasi Git
6 Download dan install Google Chrome
7 Update aplikasi Chocolatey
8 Tentang sipd-chrome-extension
9 Edit config.js
0 Tutup aplikasi

Pilih lalu Enter untuk memilih.
"@

    do {
        Clear-Host
        Write-Host $menu_list
        Write-Host ' '
        $pilihan = Read-Host "Pilih"
        switch ($pilihan) {
        1 {Open-Sipd}
        2 {Confirm-git_pull}
        3 {Confirm-git_clone}
        4 {Confirm-update_git}
        5 {Confirm-reinstall_git}
        6 {Confirm-chrome}
        7 {Confirm-update_chocolatey}
        8 {Open-about_sipd_chrome_extension}
        9 {Edit-configjs}
        0 {Exit}
        }
    }
    until ($pilihan -eq '0')
}

#==========================
#  Menu Admin / Developer
#==========================

function Start-Menu_Dev {
    $title = 'Menu Admin / Developer'
    $menu_list = @"
================ $title ================

1 Install AnyDesk
2 Uninstall AnyDesk
3 Install Sublime Text
4 Uninstall Sublime Text
5 Install Notepad++
6 
7 
8 
9 
0 Tutup aplikasi
"@

    do {
        Clear-Host
        Write-Host $menu_list
        Write-Host ' '
        $pilihan = Read-Host "Pilih"
        switch ($pilihan) {
        1 {}
        2 {}
        3 {}
        4 {}
        5 {}
        6 {}
        7 {}
        8 {}
        9 {}
        0 {Exit}
        }
    }
    until ($pilihan -eq '0')
}

#
#  Install AnyDesk
#

#===================
#  Daftar Provinsi
#===================

function Show-Provinsi {
    $list_prov = @'
    1  Provinsi DKI Jakarta
    2  Provinsi Banten
    3  Provinsi Jawa Barat
    4  Provinsi Jawa Tengah
    5  Provinsi DI Yogyakarta
    6  Provinsi Jawa Timur
    7  Aceh
    8  Provinsi Sumatera Utara
    9  Provinsi Sumatera Barat
    10 Provinsi Riau
    11 Provinsi Jambi
    12 Provinsi Sumatera Selatan
    13 Provinsi Bengkulu
    14 Provinsi Lampung
    15 Provinsi Kalimantan Utara
    16 Provinsi Kalimantan Barat
    17 Provinsi Kalimantan Tengah
    18 Provinsi Kalimantan Timur
    19 Provinsi Kalimantan Selatan
    20 Provinsi Sulawesi Utara
    21 Provinsi Gorontalo
    22 Provinsi Sulawesi Tengah
    23 Provinsi Sulawesi Barat
    24 Provinsi Sulawesi Selatan
    25 Provinsi Sulawesi Tenggara
    26 Provinsi Maluku
    27 Provinsi Maluku Utara
    28 Provinsi Bali
    29 Provinsi Nusa Tenggara Barat
    30 Provinsi Nusa Tenggara Timur
    31 Provinsi Bangka Belitung
    32 Provinsi Kepulauan Riau
    33 Provinsi Papua Barat dan Provinsi Papua Barat Daya
    34 Provinsi Papua, Provinsi Papua Selatan, Provinsi Papua Tengah, dan Provinsi Papua Pegunungan
'@

    do {
        Clear-Host
        Write-Host ' '
        Write-Host $list_prov
        Write-Host ' '
        Write-Host '0 Kembali ke Menu Utama'
        Write-Host ' '
        $pilih_prov = Read-Host 'Pilih Provinsi'
        switch ($pilih_prov) {
            1  {}
            2  {}
            3  {}
            4  {}
            5  {}
            6  {}
            7  {}
            8  {}
            9  {}
            10 {}
            11 {}
            12 {}
            13 {}
            14 {}
            15 {}
            16 {}
            17 {}
            18 {}
            19 {}
            20 {}
            21 {}
            22 {}
            23 {}
            24 {}
            25 {}
            26 {}
            27 {}
            28 {}
            29 {}
            30 {}
            31 {}
            32 {}
            33 {}
            34 {}
            0  {Start-Menu}
        }
    }
    until ($null -ne $pilih_prov)

    Edit-URL_SIPD($pilih_prov)
}

#=================
#  Daftar Daerah
#=================

function Show-Daerah {
    Param(
        [Parameter(Mandatory = $true)]$prov
    )

    switch ($prov) {
        1 {return '1 Provinsi DKI Jakarta'}
        2 {return @'
492 Provinsi Banten
493 Kab. Lebak
494 Kab. Pandeglang
495 Kab. Serang
496 Kab. Tangerang
497 Kota Cilegon
498 Kota Tangerang
499 Kota Serang
500 Kota Tangerang Selatan
'@}
        3 {return @'
8  Provinsi Jawa Barat
9  Kab. Bandung
10 Kab. Bekasi
11 Kab. Bogor
12 Kab. Ciamis
13 Kab. Cianjur
14 Kab. Cirebon
15 Kab. Garut
16 Kab. Indramayu
17 Kab. Karawang
18 Kab. Kuningan
19 Kab. Majalengka
20 Kab. Purwakarta
21 Kab. Subang
22 Kab. Sukabumi
23 Kab. Sumedang
24 Kab. Tasikmalaya
25 Kota Bandung
26 Kota Bekasi
27 Kota Bogor
28 Kota Cirebon
29 Kota Depok
30 Kota Sukabumi
31 Kota Cimahi
32 Kota Tasikmalaya
33 Kota Banjar
34 Kab. Bandung Barat
'@}
        4  {return @'
35 Provinsi Jawa Tengah
36 Kab. Banjarnegara
37 Kab. Banyumas
38 Kab. Batang
39 Kab. Blora
40 Kab. Boyolali
41 Kab. Brebes
42 Kab. Cilacap
43 Kab. Demak
44 Kab. Grobogan
45 Kab. Jepara
46 Kab. Karanganyar
47 Kab. Kebumen
48 Kab. Kendal
49 Kab. Klaten
50 Kab. Kudus
51 Kab. Magelang
52 Kab. Pati
53 Kab. Pekalongan
54 Kab. Pemalang
55 Kab. Purbalingga
56 Kab. Purworejo
57 Kab. Rembang
58 Kab. Semarang
59 Kab. Sragen
60 Kab. Sukoharjo
61 Kab. Tegal
62 Kab. Temanggung
63 Kab. Wonogiri
64 Kab. Wonosobo
65 Kota Magelang
66 Kota Pekalongan
67 Kota Salatiga
68 Kota Semarang
69 Kota Surakarta
70 Kota Tegal
'@}
        5  {return @'
71 Provinsi DI Yogyakarta
72 Kab. Bantul
73 Kab. Gunungkidul
74 Kab. Kulon Progo
75 Kab. Sleman
76 Kota Yogyakarta
'@}
        6  {return @'
77  Provinsi Jawa Timur
78  Kab. Bangkalan
79  Kab. Banyuwangi
80  Kab. Blitar
81  Kab. Bojonegoro
82  Kab. Bondowoso
83  Kab. Gresik
84  Kab. Jember
85  Kab. Jombang
86  Kab. Kediri
87  Kab. Lamongan
88  Kab. Lumajang
89  Kab. Madiun
90  Kab. Magetan
91  Kab. Malang
92  Kab. Mojokerto
93  Kab. Nganjuk
94  Kab. Ngawi
95  Kab. Pacitan
96  Kab. Pamekasan
97  Kab. Pasuruan
98  Kab. Ponorogo
99  Kab. Probolinggo
100 Kab. Sampang
101 Kab. Sidoarjo
102 Kab. Situbondo
103 Kab. Sumenep
104 Kab. Trenggalek
105 Kab. Tuban
106 Kab. Tulungagung
107 Kota Blitar
108 Kota Kediri
109 Kota Madiun
110 Kota Malang
111 Kota Mojokerto
112 Kota Pasuruan
113 Kota Probolinggo
114 Kota Surabaya
115 Kota Batu
'@}
        7  {return @'
116 Aceh
117 Kab. Aceh Barat
118 Kab. Aceh Besar
119 Kab. Aceh Selatan
120 Kab. Aceh Singkil
121 Kab. Aceh Tengah
122 Kab. Aceh Tenggara
123 Kab. Aceh Timur
124 Kab. Aceh Utara
125 Kab. Bireuen
126 Kab. Pidie
127 Kab. Simeulue
128 Kota Banda Aceh
129 Kota Sabang
130 Kota Langsa
131 Kota Lhokseumawe
132 Kab. Nagan Raya
133 Kab. Aceh Jaya
134 Kab. Aceh Barat Daya
135 Kab. Gayo Lues
136 Kab. Aceh Tamiang
137 Kab. Bener Meriah
138 Kota Subulussalam
139 Kab. Pidie Jaya
'@}
        8  {return @'
141 Provinsi Sumatera Utara
142 Kab. Asahan
143 Kab. Dairi
144 Kab. Deli Serdang
145 Kab. Karo
146 Kab. Labuhanbatu
147 Kab. Langkat
148 Kab. Mandailing Natal
149 Kab. Nias
150 Kab. Simalungun
151 Kab. Tapanuli Selatan
152 Kab. Tapanuli Tengah
153 Kab. Tapanuli Utara
154 Kab. Toba
155 Kota Binjai
156 Kota Medan
157 Kota Pematangsiantar
158 Kota Sibolga
159 Kota Tanjung Balai
160 Kota Tebing Tinggi
161 Kota Padangsidempuan
162 Kab. Pakpak Bharat
163 Kab. Nias Selatan
164 Kab. Humbang Hasundutan
165 Kab. Serdang Bedagai
166 Kab. Samosir
167 Kab. Batu Bara
173 Kab. Padang Lawas
174 Kab. Padang Lawas Utara
175 Kab. Labuhanbatu Utara
176 Kab. Labuhanbatu Selatan
177 Kab. Nias Utara
178 Kab. Nias Barat
179 Kota Gunungsitoli
'@}
        9  {return @'
180 Provinsi Sumatera Barat
181 Kab. Lima Puluh Kota
182 Kab. Agam
183 Kab. Kepulauan Mentawai
184 Kab. Padang Pariaman
185 Kab. Pasaman
186 Kab. Pesisir Selatan
187 Kab. Sijunjung
188 Kab. Solok
189 Kab. Tanah Datar
190 Kota Bukittinggi
191 Kota Padang Panjang
192 Kota Padang
193 Kota Payakumbuh
194 Kota Sawahlunto
195 Kota Solok
196 Kota Pariaman
197 Kab. Pasaman Barat
198 Kab. Dharmasraya
199 Kab. Solok Selatan
'@}
        10 {return @'
202 Provinsi Riau
203 Kab. Bengkalis
204 Kab. Indragiri Hilir
205 Kab. Indragiri Hulu
206 Kab. Kampar
207 Kab. Kuantan Singingi
208 Kab. Pelalawan
209 Kab. Rokan Hilir
210 Kab. Rokan Hulu
211 Kab. Siak
212 Kota Dumai
213 Kota Pekanbaru
215 Kab. Kepulauan Meranti
'@}
        11 {return @'
216 Provinsi Jambi
217 Kab. Batanghari
218 Kab. Bungo
219 Kab. Kerinci
220 Kab. Merangin
221 Kab. Muaro Jambi
222 Kab. Sarolangun
223 Kab. Tanjung Jabung Barat
224 Kab. Tanjung Jabung Timur
225 Kab. Tebo
226 Kota Jambi
228 Kota Sungai Penuh
'@}
        12 {return @'
229 Provinsi Sumatera Selatan
230 Kab. Lahat
231 Kab. Musi Banyuasin
232 Kab. Musi Rawas
233 Kab. Muara Enim
234 Kab. Ogan Komering Ilir
235 Kab. Ogan Komering Ulu
236 Kota Palembang
237 Kota Pagar Alam
238 Kota Lubuk Linggau
239 Kota Prabumulih
240 Kab. Banyuasin
241 Kab. Ogan Ilir
242 Kab. Ogan Komering Ulu Timur
243 Kab. Ogan Komering Ulu Selatan
244 Kab. Empat Lawang
'@}
        13 {return @'
471 Provinsi Bengkulu
472 Kab. Bengkulu Selatan
473 Kab. Bengkulu Utara
474 Kab. Rejang Lebong
475 Kota Bengkulu
476 Kab. Kaur
477 Kab. Seluma
478 Kab. Muko Muko
479 Kab. Lebong
480 Kab. Kepahiang
481 Kab. Bengkulu Tengah
'@}
        14 {return @'
246 Provinsi Lampung
247 Kab. Lampung Barat
248 Kab. Lampung Selatan
249 Kab. Lampung Tengah
250 Kab. Lampung Utara
251 Kab. Lampung Timur
252 Kab. Tanggamus
253 Kab. Tulang Bawang
254 Kab. Way Kanan
255 Kota Bandar Lampung
256 Kota Metro
257 Kab. Pesawaran
258 Kab. Pringsewu
259 Kab. Mesuji
260 Kab. Tulang Bawang Barat
'@}
        15 {return @'
546 Provinsi Kalimantan Utara
547 Kab. Bulungan
548 Kab. Malinau
549 Kab. Nunukan
550 Kab. Tana Tidung
551 Kota Tarakan
'@}
        16 {return @'
261 Provinsi Kalimantan Barat
262 Kab. Bengkayang
263 Kab. Landak
264 Kab. Kapuas Hulu
265 Kab. Ketapang
267 Kab. Sambas
268 Kab. Sanggau
269 Kab. Sintang
270 Kota Pontianak
271 Kota Singkawang
272 Kab. Sekadau
273 Kab. Melawi
274 Kab. Kayong Utara
275 Kab. Kubu Raya
'@}
        17 {return @'
276 Provinsi Kalimantan Tengah
277 Kab. Barito Selatan
278 Kab. Barito Utara
279 Kab. Kapuas
280 Kab. Kotawaringin Barat
281 Kab. Kotawaringin Timur
282 Kota Palangkaraya
283 Kab. Barito Timur
284 Kab. Murung Raya
285 Kab. Pulang Pisau
286 Kab. Gunung Mas
287 Kab. Lamandau
288 Kab. Sukamara
289 Kab. Katingan
290 Kab. Seruyan
'@}
        18 {return @'
307 Provinsi Kalimantan Timur
308 Kab. Berau
309 Kab. Kutai Kartanegara
310 Kab. Kutai Barat
311 Kab. Kutai Timur
312 Kab. Paser
313 Kota Balikpapan
314 Kota Bontang
315 Kota Samarinda
316 Kab. Penajam Paser Utara
'@}
        19 {return @'
291 Provinsi Kalimantan Selatan
292 Kab. Banjar
293 Kab. Barito Kuala
294 Kab. Hulu Sungai Selatan
295 Kab. Hulu Sungai Tengah
296 Kab. Hulu Sungai Utara
297 Kab. Kotabaru
298 Kab. Tabalong
299 Kab. Tanah Laut
300 Kab. Tapin
301 Kota Banjarbaru
302 Kota Banjarmasin
303 Kab. Balangan
304 Kab. Tanah Bumbu
'@}
        20 {return @'
318 Provinsi Sulawesi Utara
319 Kab. Bolaang Mongondow
320 Kab. Minahasa
321 Kab. Kepulauan Sangihe
322 Kota Bitung
323 Kota Manado
324 Kab. Kepulauan Talaud
325 Kab. Minahasa Selatan
326 Kota Tomohon
327 Kab. Minahasa Utara
328 Kota Kotamobagu
329 Kab. Bolaang Mongondow Utara
330 Kab. Kep. Siau Tagulandang Biaro
331 Kab. Minahasa Tenggara
332 Kab. Bolaang Mongondow Timur
333 Kab. Bolaang Mongondow Selatan
'@}
        21 {return @'
510 Provinsi Gorontalo
511 Kab. Boalemo
512 Kab. Gorontalo
513 Kota Gorontalo
514 Kab. Pohuwato
515 Kab. Bone Bolango
516 Kab. Gorontalo Utara
'@}
        22 {return @'
334 Provinsi Sulawesi Tengah
335 Kab. Banggai
336 Kab. Banggai Kepulauan
337 Kab. Buol
338 Kab. Toli Toli
339 Kab. Donggala
340 Kab. Morowali
341 Kab. Poso
342 Kota Palu
343 Kab. Parigi Moutong
344 Kab. Tojo Una Una
345 Kab. Sigi
'@}
        23 {return @'
540 Provinsi Sulawesi Barat
541 Kab. Majene
542 Kab. Mamuju
543 Kab. Polewali Mandar
544 Kab. Mamasa
545 Kab. Pasangkayu
'@}
        24 {return @'
346 Provinsi Sulawesi Selatan
347 Kab. Bantaeng
348 Kab. Barru
349 Kab. Bone
350 Kab. Bulukumba
351 Kab. Enrekang
352 Kab. Gowa
353 Kab. Jeneponto
354 Kab. Luwu
355 Kab. Luwu Utara
356 Kab. Maros
357 Kab. Pangkajene Kepulauan
358 Kab. Pinrang
359 Kab. Kepulauan Selayar
360 Kab. Sidenreng Rappang
361 Kab. Sinjai
362 Kab. Soppeng
363 Kab. Takalar
364 Kab. Tana Toraja
365 Kab. Wajo
366 Kota Pare Pare
367 Kota Makassar
368 Kota Palopo
369 Kab. Luwu Timur
370 Kab. Toraja Utara
'@}
        25 {return @'
371 Provinsi Sulawesi Tenggara
372 Kab. Buton
373 Kab. Konawe
374 Kab. Kolaka
375 Kab. Muna
376 Kota Kendari
377 Kota Bau Bau
378 Kab. Konawe Selatan
379 Kab. Bombana
380 Kab. Wakatobi
381 Kab. Kolaka Utara
382 Kab. Konawe Utara
383 Kab. Buton Utara
'@}
        26 {return @'
384 Provinsi Maluku
385 Kab. Kepulauan Tanimbar
386 Kab. Maluku Tengah
387 Kab. Maluku Tenggara
388 Kab. Buru
389 Kota Ambon
390 Kab. Seram Bagian Barat
391 Kab. Seram Bagian Timur
392 Kab. Kepulauan Aru
393 Kota Tual
394 Kab. Maluku Barat Daya
395 Kab. Buru Selatan
'@}
        27 {return @'
482 Provinsi Maluku Utara
483 Kab. Halmahera Tengah
484 Kab. Halmahera Barat
485 Kota Ternate
486 Kab. Halmahera Timur
487 Kota Tidore Kepulauan
488 Kab. Kepulauan Sula
489 Kab. Halmahera Selatan
490 Kab. Halmahera Utara
491 Kab. Pulau Morotai
'@}
        28 {return @'
396 Provinsi Bali
397 Kab. Badung
398 Kab. Bangli
399 Kab. Buleleng
400 Kab. Gianyar
401 Kab. Jembrana
402 Kab. Karangasem
403 Kab. Klungkung
404 Kab. Tabanan
405 Kota Denpasar
'@}
        29 {return @'
407 Provinsi Nusa Tenggara Barat
408 Kab. Bima
409 Kab. Dompu
410 Kab. Lombok Barat
411 Kab. Lombok Tengah
412 Kab. Lombok Timur
413 Kab. Sumbawa
414 Kota Mataram
415 Kota Bima
416 Kab. Sumbawa Barat
417 Kab. Lombok Utara
'@}
        30 {return @'
418 Provinsi Nusa Tenggara Timur
419 Kab. Alor
420 Kab. Belu
421 Kab. Ende
422 Kab. Flores Timur
423 Kab. Kupang
424 Kab. Lembata
425 Kab. Manggarai
426 Kab. Ngada
427 Kab. Sikka
428 Kab. Sumba Barat
429 Kab. Sumba Timur
430 Kab. Timor Tengah Selatan
431 Kab. Timor Tengah Utara
432 Kota Kupang
433 Kab. Rote Ndao
434 Kab. Manggarai Barat
435 Kab. Nagekeo
436 Kab. Sumba Barat Daya
437 Kab. Sumba Tengah
438 Kab. Manggarai Timur
439 Kab. Sabu Raijua
'@}
        31 {return @'
501 Provinsi Bangka Belitung
502 Kab. Bangka
503 Kab. Belitung
504 Kota Pangkal Pinang
505 Kab. Bangka Selatan
506 Kab. Bangka Tengah
507 Kab. Bangka Barat
508 Kab. Belitung Timur
'@}
        32 {return @'
519 Provinsi Kepulauan Riau
520 Kab. Bintan
521 Kab. Natuna
522 Kab. Karimun
523 Kota Batam
524 Kota Tanjung Pinang
525 Kab. Lingga
527 Kab. Kepulauan Anambas
'@}
        33 {return @'
528 Provinsi Papua Barat
530 Kab. Manokwari
531 Kab. Fak Fak
535 Kab. Teluk Bintuni
536 Kab. Teluk Wondama
537 Kab. Kaimana
558 Kab. Manokwari Selatan
559 Kab. Pegunungan Arfak
610 Provinsi Papua Barat Daya
611 Kab. Sorong
612 Kab. Sorong Selatan
613 Kab. Raja Ampat
614 Kab. Tambrauw
615 Kab. Maybrat
616 Kota Sorong
'@}
        34 {return @'
440 Provinsi Papua
441 Kab. Biak Numfor
442 Kab. Jayapura
449 Kab. Kepulauan Yapen
450 Kota Jayapura
451 Kab. Sarmi
452 Kab. Keerom
459 Kab. Waropen
460 Kab. Supiori
461 Kab. Mamberamo Raya
468 Kab. Puncak
552 Kab. Pangandaran
553 Kab. Mempawah
554 Kab. Mahakam Ulu
555 Kab. Pesisir Barat
556 Kab. Pulau Taliabu
557 Kab. Malaka
560 Kab. Mamuju Tengah
561 Kab. Banggai Laut
562 Kab. Morowali Utara
563 Kab. Buton Selatan
564 Kab. Buton Tengah
565 Kab. Kolaka Timur
566 Kab. Konawe Kepulauan
567 Kab. Muna Barat
569 Kab. Musi Rawas Utara
570 Kab. Penukal Abab Lematang Ilir
588 Provinsi Papua Selatan
589 Provinsi Papua Tengah
590 Provinsi Papua Pegunungan
591 Kab. Merauke
592 Kab. Boven Digoel
593 Kab. Mappi
594 Kab. Asmat
595 Kab. Nabire
596 Kab. Puncak Jaya
597 Kab. Paniai
598 Kab. Mimika
599 Kab. Dogiyai
600 Kab. Intan Jaya
601 Kab. Deiyai
602 Kab. Jayawijaya
603 Kab. Pegunungan Bintang
604 Kab. Yahukimo
605 Kab. Tolikara
606 Kab. Mamberamo Tengah
607 Kab. Yalimo
608 Kab. Lanny Jaya
609 Kab. Nduga
'@}
    }
}

#===========================
#  Lanjutan Edit config.js
#===========================

function Edit-URL_SIPD {
    param (
        [Parameter(Mandatory = $true)]$no_pilihan_prov
    )
    
    do {
        Clear-Host
        Write-Host ' '
        Show-Daerah($no_pilihan_prov)
        Write-Host ' '
        Write-Host '0 Kembali ke Menu Utama'
        Write-Host ' '
        $id_daerah = Read-Host 'Pilih Daerah'
        switch ($id_daerah) {
            1   {$i = 'jakarta'}
            8   {$i = 'jabarprov'}
            9   {$i = 'bandungkab'}
            10  {$i = 'bekasikab'}
            11  {$i = 'bogorkab'}
            12  {$i = 'ciamiskab'}
            13  {$i = 'cianjurkab'}
            14  {$i = 'cirebonkab'}
            15  {$i = 'garutkab'}
            16  {$i = 'indramayukab'}
            17  {$i = 'karawangkab'}
            18  {$i = 'kuningankab'}
            19  {$i = 'majalengkakab'}
            20  {$i = 'purwakartakab'}
            21  {$i = 'subangkab'}
            22  {$i = 'sukabumikab'}
            23  {$i = 'sumedangkab'}
            24  {$i = 'tasikmalayakab'}
            25  {$i = 'bandung'}
            26  {$i = 'bekasi'}
            27  {$i = 'bogor'}
            28  {$i = 'cirebon'}
            29  {$i = 'depok'}
            30  {$i = 'sukabumi'}
            31  {$i = 'cimahi'}
            32  {$i = 'tasikmalaya'}
            33  {$i = 'banjar'}
            34  {$i = 'bandung baratkab'}
            35  {$i = 'jatengprov'}
            36  {$i = 'banjarnegarakab'}
            37  {$i = 'banyumaskab'}
            38  {$i = 'batangkab'}
            39  {$i = 'blorakab'}
            40  {$i = 'boyolalikab'}
            41  {$i = 'brebeskab'}
            42  {$i = 'cilacapkab'}
            43  {$i = 'demakkab'}
            44  {$i = 'grobogankab'}
            45  {$i = 'jeparakab'}
            46  {$i = 'karanganyarkab'}
            47  {$i = 'kebumenkab'}
            48  {$i = 'kendalkab'}
            49  {$i = 'klatenkab'}
            50  {$i = 'kuduskab'}
            51  {$i = 'magelangkab'}
            52  {$i = 'patikab'}
            53  {$i = 'pekalongankab'}
            54  {$i = 'pemalangkab'}
            55  {$i = 'purbalinggakab'}
            56  {$i = 'purworejokab'}
            57  {$i = 'rembangkab'}
            58  {$i = 'semarangkab'}
            59  {$i = 'sragenkab'}
            60  {$i = 'sukoharjokab'}
            61  {$i = 'tegalkab'}
            62  {$i = 'temanggungkab'}
            63  {$i = 'wonogirikab'}
            64  {$i = 'wonosobokab'}
            65  {$i = 'magelang'}
            66  {$i = 'pekalongan'}
            67  {$i = 'salatiga'}
            68  {$i = 'semarang'}
            69  {$i = 'surakarta'}
            70  {$i = 'tegal'}
            71  {$i = 'jogjaprov'}
            72  {$i = 'bantulkab'}
            73  {$i = 'gunungkidulkab'}
            74  {$i = 'kulon progokab'}
            75  {$i = 'slemankab'}
            76  {$i = 'jogjakota'}
            77  {$i = 'jatimprov'}
            78  {$i = 'bangkalankab'}
            79  {$i = 'banyuwangikab'}
            80  {$i = 'blitarkab'}
            81  {$i = 'bojonegorokab'}
            82  {$i = 'bondowosokab'}
            83  {$i = 'gresikkab'}
            84  {$i = 'jemberkab'}
            85  {$i = 'jombangkab'}
            86  {$i = 'kedirikab'}
            87  {$i = 'lamongankab'}
            88  {$i = 'lumajangkab'}
            89  {$i = 'madiunkab'}
            90  {$i = 'magetankab'}
            91  {$i = 'malangkab'}
            92  {$i = 'mojokertokab'}
            93  {$i = 'nganjukkab'}
            94  {$i = 'ngawikab'}
            95  {$i = 'pacitankab'}
            96  {$i = 'pamekasankab'}
            97  {$i = 'pasuruankab'}
            98  {$i = 'ponorogokab'}
            99  {$i = 'probolinggokab'}
            100 {$i = 'sampangkab'}
            101 {$i = 'sidoarjokab'}
            102 {$i = 'situbondokab'}
            103 {$i = 'sumenepkab'}
            104 {$i = 'trenggalekkab'}
            105 {$i = 'tubankab'}
            106 {$i = 'tulungagungkab'}
            107 {$i = 'blitar'}
            108 {$i = 'kediri'}
            109 {$i = 'madiun'}
            110 {$i = 'malang'}
            111 {$i = 'mojokerto'}
            112 {$i = 'pasuruan'}
            113 {$i = 'probolinggo'}
            114 {$i = 'surabaya'}
            115 {$i = 'batu'}
            116 {$i = 'acehprov'}
            117 {$i = 'acehbaratkab'}
            118 {$i = 'acehbesarkab'}
            119 {$i = 'acehselatankab'}
            120 {$i = 'acehsingkilkab'}
            121 {$i = 'acehtengahkab'}
            122 {$i = 'acehtenggarakab'}
            123 {$i = 'acehtimurkab'}
            124 {$i = 'acehutarakab'}
            125 {$i = 'bireuenkab'}
            126 {$i = 'pidiekab'}
            127 {$i = 'simeuluekab'}
            128 {$i = 'bandaaceh'}
            129 {$i = 'sabang'}
            130 {$i = 'langsa'}
            131 {$i = 'lhokseumawe'}
            132 {$i = 'naganrayakab'}
            133 {$i = 'acehjayakab'}
            134 {$i = 'acehbaratdayakab'}
            135 {$i = 'gayolueskab'}
            136 {$i = 'acehtamiangkab'}
            137 {$i = 'benermeriahkab'}
            138 {$i = 'subulussalam'}
            139 {$i = 'pidiejayakab'}
            141 {$i = 'sumutprov'}
            142 {$i = 'asahankab'}
            143 {$i = 'dairikab'}
            144 {$i = 'deliserdangkab'}
            145 {$i = 'tanahkarokab'}
            146 {$i = 'labuhanbatukab'}
            147 {$i = 'langkatkab'}
            148 {$i = 'mandailingnatalkab'}
            149 {$i = 'niaskab'}
            150 {$i = 'simalungunkab'}
            151 {$i = 'tapanuliselatankab'}
            152 {$i = 'tapanulitengahkab'}
            153 {$i = 'tapanuliutarakab'}
            154 {$i = 'tobakab'}
            155 {$i = 'binjai'}
            156 {$i = 'medan'}
            157 {$i = 'pematangsiantar'}
            158 {$i = 'sibolga'}
            159 {$i = 'tanjungbalai'}
            160 {$i = 'tebingtinggi'}
            161 {$i = 'padangsidempuan'}
            162 {$i = 'pakpakbharatkab'}
            163 {$i = 'niasselatankab'}
            164 {$i = 'humbanghasundutankab'}
            165 {$i = 'serdangbedagaikab'}
            166 {$i = 'samosirkab'}
            167 {$i = 'batubarakab'}
            173 {$i = 'padanglawaskab'}
            174 {$i = 'padanglawasutarakab'}
            175 {$i = 'labuhanbatuutarakab'}
            176 {$i = 'labuhanbatuselatankab'}
            177 {$i = 'niasutarakab'}
            178 {$i = 'niasbaratkab'}
            179 {$i = 'gunungsitoli'}
            180 {$i = 'sumbarprov'}
            181 {$i = 'limapuluhkotakab'}
            182 {$i = 'agamkab'}
            183 {$i = 'kepulauanmentawaikab'}
            184 {$i = 'padangpariamankab'}
            185 {$i = 'pasamankab'}
            186 {$i = 'pesisirselatankab'}
            187 {$i = 'sijunjungkab'}
            188 {$i = 'solokkab'}
            189 {$i = 'tanahdatarkab'}
            190 {$i = 'bukittinggi'}
            191 {$i = 'padangpanjang'}
            192 {$i = 'padang'}
            193 {$i = 'payakumbuh'}
            194 {$i = 'sawahlunto'}
            195 {$i = 'solok'}
            196 {$i = 'pariaman'}
            197 {$i = 'pasamanbaratkab'}
            198 {$i = 'dharmasrayakab'}
            199 {$i = 'solokselatankab'}
            202 {$i = 'riauprov'}
            203 {$i = 'bengkaliskab'}
            204 {$i = 'indragirihilirkab'}
            205 {$i = 'indragirihulukab'}
            206 {$i = 'kamparkab'}
            207 {$i = 'kuantansingingikab'}
            208 {$i = 'pelalawankab'}
            209 {$i = 'rokanhilirkab'}
            210 {$i = 'rokanhulukab'}
            211 {$i = 'siakkab'}
            212 {$i = 'dumai'}
            213 {$i = 'pekanbaru'}
            215 {$i = 'kepulauanmerantikab'}
            216 {$i = 'jambiprov'}
            217 {$i = 'batangharikab'}
            218 {$i = 'bungokab'}
            219 {$i = 'kerincikab'}
            220 {$i = 'meranginkab'}
            221 {$i = 'muarojambikab'}
            222 {$i = 'sarolangunkab'}
            223 {$i = 'tanjungjabungbaratkab'}
            224 {$i = 'tanjungjabungtimurkab'}
            225 {$i = 'tebokab'}
            226 {$i = 'jambi'}
            228 {$i = 'sungaipenuh'}
            229 {$i = 'sumselprov'}
            230 {$i = 'lahatkab'}
            231 {$i = 'musibanyuasinkab'}
            232 {$i = 'musirawaskab'}
            233 {$i = 'muaraenimkab'}
            234 {$i = 'ogankomeringilirkab'}
            235 {$i = 'ogankomeringulukab'}
            236 {$i = 'palembang'}
            237 {$i = 'pagaralam'}
            238 {$i = 'lubuklinggau'}
            239 {$i = 'prabumulih'}
            240 {$i = 'banyuasinkab'}
            241 {$i = 'oganilirkab'}
            242 {$i = 'okutimurkab'}
            243 {$i = 'okuselatankab'}
            244 {$i = 'empatlawangkab'}
            246 {$i = 'lampungprov'}
            247 {$i = 'lampungbaratkab'}
            248 {$i = 'lampungselatankab'}
            249 {$i = 'lampungtengahkab'}
            250 {$i = 'lampungutarakab'}
            251 {$i = 'lampungtimurkab'}
            252 {$i = 'tanggamuskab'}
            253 {$i = 'tulangbawangkab'}
            254 {$i = 'waykanankab'}
            255 {$i = 'bandarlampung'}
            256 {$i = 'metro'}
            257 {$i = 'pesawarankab'}
            258 {$i = 'pringsewukab'}
            259 {$i = 'mesujikab'}
            260 {$i = 'tulangbawangbaratkab'}
            261 {$i = 'kalbarprov'}
            262 {$i = 'bengkayangkab'}
            263 {$i = 'landakkab'}
            264 {$i = 'kapuashulukab'}
            265 {$i = 'ketapangkab'}
            267 {$i = 'sambaskab'}
            268 {$i = 'sanggaukab'}
            269 {$i = 'sintangkab'}
            270 {$i = 'pontianak'}
            271 {$i = 'singkawang'}
            272 {$i = 'sekadaukab'}
            273 {$i = 'melawikab'}
            274 {$i = 'kayongutarakab'}
            275 {$i = 'kuburayakab'}
            276 {$i = 'kaltengprov'}
            277 {$i = 'baritoselatankab'}
            278 {$i = 'baritoutarakab'}
            279 {$i = 'kapuaskab'}
            280 {$i = 'kotawaringinbaratkab'}
            281 {$i = 'kotawaringintimurkab'}
            282 {$i = 'palangkaraya'}
            283 {$i = 'baritotimurkab'}
            284 {$i = 'murungrayakab'}
            285 {$i = 'pulangpisaukab'}
            286 {$i = 'gunungmaskab'}
            287 {$i = 'lamandaukab'}
            288 {$i = 'sukamarakab'}
            289 {$i = 'katingankab'}
            290 {$i = 'seruyankab'}
            291 {$i = 'kalselprov'}
            292 {$i = 'banjarkab'}
            293 {$i = 'baritokualakab'}
            294 {$i = 'hulusungaiselatankab'}
            295 {$i = 'hulusungaitengahkab'}
            296 {$i = 'hulusungaiutarakab'}
            297 {$i = 'kotabarukab'}
            298 {$i = 'tabalongkab'}
            299 {$i = 'tanahlautkab'}
            300 {$i = 'tapinkab'}
            301 {$i = 'banjarbaru'}
            302 {$i = 'banjarmasin'}
            303 {$i = 'balangankab'}
            304 {$i = 'tanahbumbukab'}
            307 {$i = 'kaltimprov'}
            308 {$i = 'beraukab'}
            309 {$i = 'kutaikartanegarakab'}
            310 {$i = 'kutaibaratkab'}
            311 {$i = 'kutaitimurkab'}
            312 {$i = 'pasirkab'}
            313 {$i = 'balikpapan'}
            314 {$i = 'bontang'}
            315 {$i = 'samarinda'}
            316 {$i = 'penajampaserutarakab'}
            318 {$i = 'sulutprov'}
            319 {$i = 'bolaangmongondowkab'}
            320 {$i = 'minahasakab'}
            321 {$i = 'sangihekab'}
            322 {$i = 'bitung'}
            323 {$i = 'manado'}
            324 {$i = 'kepulauantalaudkab'}
            325 {$i = 'minahasaselatankab'}
            326 {$i = 'tomohon'}
            327 {$i = 'minahasautarakab'}
            328 {$i = 'kotamubagu'}
            329 {$i = 'bolaangmongondowutarakab'}
            330 {$i = 'kepsiautagulandangbiarokab'}
            331 {$i = 'minahasatenggarakab'}
            332 {$i = 'bolaangmongondowtimurkab'}
            333 {$i = 'bolaangmongondowselatankab'}
            334 {$i = 'sultengprov'}
            335 {$i = 'banggaikab'}
            336 {$i = 'banggaikepulauankab'}
            337 {$i = 'buolkab'}
            338 {$i = 'toli-tolikab'}
            339 {$i = 'donggalakab'}
            340 {$i = 'morowalikab'}
            341 {$i = 'posokab'}
            342 {$i = 'palu'}
            343 {$i = 'parigimoutongkab'}
            344 {$i = 'tojouna-unakab'}
            345 {$i = 'sigikab'}
            346 {$i = 'sulselprov'}
            347 {$i = 'bantaengkab'}
            348 {$i = 'barrukab'}
            349 {$i = 'bonekab'}
            350 {$i = 'bulukumbakab'}
            351 {$i = 'enrekangkab'}
            352 {$i = 'gowakab'}
            353 {$i = 'jenepontokab'}
            354 {$i = 'luwukab'}
            355 {$i = 'luwuutarakab'}
            356 {$i = 'maroskab'}
            357 {$i = 'pangkajenekepulauankab'}
            358 {$i = 'pinrangkab'}
            359 {$i = 'kepulauanselayarkab'}
            360 {$i = 'sidenrengrappangkab'}
            361 {$i = 'sinjaikab'}
            362 {$i = 'soppengkab'}
            363 {$i = 'takalarkab'}
            364 {$i = 'tanatorajakab'}
            365 {$i = 'wajokab'}
            366 {$i = 'pare-pare'}
            367 {$i = 'makassar'}
            368 {$i = 'palopo'}
            369 {$i = 'luwutimurkab'}
            370 {$i = 'torajautarakab'}
            371 {$i = 'sultraprov'}
            372 {$i = 'butonkab'}
            373 {$i = 'konawekab'}
            374 {$i = 'kolakakab'}
            375 {$i = 'munakab'}
            376 {$i = 'kendari'}
            377 {$i = 'bau-bau'}
            378 {$i = 'konaweselatankab'}
            379 {$i = 'bombanakab'}
            380 {$i = 'wakatobikab'}
            381 {$i = 'kolakautarakab'}
            382 {$i = 'konaweutarakab'}
            383 {$i = 'butonutarakab'}
            384 {$i = 'malukuprov'}
            385 {$i = 'kepulauantanimbarkab'}
            386 {$i = 'malukutengahkab'}
            387 {$i = 'malukutenggarakab'}
            388 {$i = 'burukab'}
            389 {$i = 'ambon'}
            390 {$i = 'serambagianbaratkab'}
            391 {$i = 'serambagiantimurkab'}
            392 {$i = 'kepulauanarukab'}
            393 {$i = 'tual'}
            394 {$i = 'malukubaratdayakab'}
            395 {$i = 'buruselatankab'}
            396 {$i = 'baliprov'}
            397 {$i = 'badungkab'}
            398 {$i = 'banglikab'}
            399 {$i = 'bulelengkab'}
            400 {$i = 'gianyarkab'}
            401 {$i = 'jembranakab'}
            402 {$i = 'karangasemkab'}
            403 {$i = 'klungkungkab'}
            404 {$i = 'tabanankab'}
            405 {$i = 'denpasar'}
            407 {$i = 'ntbprov'}
            408 {$i = 'bimakab'}
            409 {$i = 'dompukab'}
            410 {$i = 'lombokbaratkab'}
            411 {$i = 'lomboktengahkab'}
            412 {$i = 'lomboktimurkab'}
            413 {$i = 'sumbawakab'}
            414 {$i = 'mataram'}
            415 {$i = 'bima'}
            416 {$i = 'sumbawabaratkab'}
            417 {$i = 'lombokutarakab'}
            418 {$i = 'nttprov'}
            419 {$i = 'alorkab'}
            420 {$i = 'belukab'}
            421 {$i = 'endekab'}
            422 {$i = 'florestimurkab'}
            423 {$i = 'kupangkab'}
            424 {$i = 'lembatakab'}
            425 {$i = 'manggaraikab'}
            426 {$i = 'ngadakab'}
            427 {$i = 'sikkakab'}
            428 {$i = 'sumbabaratkab'}
            429 {$i = 'sumbatimurkab'}
            430 {$i = 'timortengahselatankab'}
            431 {$i = 'timortengahutarakab'}
            432 {$i = 'kupang'}
            433 {$i = 'rotendaokab'}
            434 {$i = 'manggaraibaratkab'}
            435 {$i = 'nagekeokab'}
            436 {$i = 'sumbabaratdayakab'}
            437 {$i = 'sumbatengahkab'}
            438 {$i = 'manggaraitimurkab'}
            439 {$i = 'saburaijuakab'}
            440 {$i = 'papuaprov'}
            441 {$i = 'biaknumforkab'}
            442 {$i = 'jayapurakab'}
            449 {$i = 'kepulauanyapenkab'}
            450 {$i = 'jayapura'}
            451 {$i = 'sarmikab'}
            452 {$i = 'keeromkab'}
            459 {$i = 'waropenkab'}
            460 {$i = 'supiorikab'}
            461 {$i = 'mamberamorayakab'}
            468 {$i = 'puncakkab'}
            471 {$i = 'bengkuluprov'}
            472 {$i = 'bengkuluselatankab'}
            473 {$i = 'bengkuluutarakab'}
            474 {$i = 'rejanglebongkab'}
            475 {$i = 'bengkulu'}
            476 {$i = 'kaurkab'}
            477 {$i = 'selumakab'}
            478 {$i = 'muko-mukokab'}
            479 {$i = 'lebongkab'}
            480 {$i = 'kepahiangkab'}
            481 {$i = 'bengkulutengahkab'}
            482 {$i = 'malutprov'}
            483 {$i = 'halmaheratengahkab'}
            484 {$i = 'halmaherabaratkab'}
            485 {$i = 'ternate'}
            486 {$i = 'halmaheratimurkab'}
            487 {$i = 'tidorekepulauan'}
            488 {$i = 'kepulauansulakab'}
            489 {$i = 'halmaheraselatankab'}
            490 {$i = 'halmaherautarakab'}
            491 {$i = 'morotaikab'}
            492 {$i = 'bantenprov'}
            493 {$i = 'lebakkab'}
            494 {$i = 'pandeglangkab'}
            495 {$i = 'serangkab'}
            496 {$i = 'tangerangkab'}
            497 {$i = 'cilegon'}
            498 {$i = 'tangerang'}
            499 {$i = 'serang'}
            500 {$i = 'tangerangselatan'}
            501 {$i = 'babelprov'}
            502 {$i = 'bangkakab'}
            503 {$i = 'belitungkab'}
            504 {$i = 'pangkalpinang'}
            505 {$i = 'bangkaselatankab'}
            506 {$i = 'bangkatengahkab'}
            507 {$i = 'bangkabaratkab'}
            508 {$i = 'belitungtimurkab'}
            510 {$i = 'gorontaloprov'}
            511 {$i = 'boalemokab'}
            512 {$i = 'gorontalokab'}
            513 {$i = 'gorontalo'}
            514 {$i = 'pohuwatokab'}
            515 {$i = 'bonebolangokab'}
            516 {$i = 'gorontaloutarakab'}
            519 {$i = 'kepriprov'}
            520 {$i = 'bintankab'}
            521 {$i = 'natunakab'}
            522 {$i = 'karimunkab'}
            523 {$i = 'batam'}
            524 {$i = 'tanjungpinang'}
            525 {$i = 'linggakab'}
            527 {$i = 'kepulauananambaskab'}
            528 {$i = 'papuabaratprov'}
            530 {$i = 'manokwarikab'}
            531 {$i = 'fak-fakkab'}
            535 {$i = 'telukbintunikab'}
            536 {$i = 'telukwondamakab'}
            537 {$i = 'kaimanakab'}
            540 {$i = 'sulbarprov'}
            541 {$i = 'majenekab'}
            542 {$i = 'mamujukab'}
            543 {$i = 'polewalimandarkab'}
            544 {$i = 'mamasakab'}
            545 {$i = 'pasangkayukab'}
            546 {$i = 'kaltaraprov'}
            547 {$i = 'bulungankab'}
            548 {$i = 'malinaukab'}
            549 {$i = 'nunukankab'}
            550 {$i = 'tanatidungkab'}
            551 {$i = 'tarakan'}
            552 {$i = 'pangandarankab'}
            553 {$i = 'mempawahkab'}
            554 {$i = 'mahakamulukab'}
            555 {$i = 'pesisirbaratkab'}
            556 {$i = 'pulautaliabukab'}
            557 {$i = 'malakakab'}
            558 {$i = 'manokwariselatankab'}
            559 {$i = 'pegununganarfakkab'}
            560 {$i = 'mamujutengahkab'}
            561 {$i = 'banggailautkab'}
            562 {$i = 'morowaliutarakab'}
            563 {$i = 'butonselatankab'}
            564 {$i = 'butontengahkab'}
            565 {$i = 'kolakatimurkab'}
            566 {$i = 'konawekepulauankab'}
            567 {$i = 'munabaratkab'}
            569 {$i = 'musirawasutarakab'}
            570 {$i = 'penukalabablematangilirkab'}
            588 {$i = 'papuaselatanprov'}
            589 {$i = 'papuatengahprov'}
            590 {$i = 'papuapegununganprov'}
            591 {$i = 'meraukekab'}
            592 {$i = 'bovendigoelkab'}
            593 {$i = 'mappikab'}
            594 {$i = 'asmatkab'}
            595 {$i = 'nabirekab'}
            596 {$i = 'puncakjayakab'}
            597 {$i = 'paniaikab'}
            598 {$i = 'mimikakab'}
            599 {$i = 'dogiyaikab'}
            600 {$i = 'intanjayakab'}
            601 {$i = 'deiyaikab'}
            602 {$i = 'jayawijayakab'}
            603 {$i = 'pegununganbintangkab'}
            604 {$i = 'yahukimokab'}
            605 {$i = 'tolikarakab'}
            606 {$i = 'mamberamotengahkab'}
            607 {$i = 'yalimokab'}
            608 {$i = 'lannyjayakab'}
            609 {$i = 'ndugakab'}
            610 {$i = 'papuabaratdayaprov'}
            611 {$i = 'sorongkab'}
            612 {$i = 'sorongselatankab'}
            613 {$i = 'rajaampatkab'}
            614 {$i = 'tambrauwkab'}
            615 {$i = 'maybratkab'}
            616 {$i = 'sorong'}
            0   {Start-Menu}
        }
    }
    until ($null -ne $i)

    Show-id_url

    $configjs = @"
var config = {
	tahun_anggaran : "$tahun_anggaran", // Tahun anggaran
	id_daerah : "$id_daerah", // ID daerah bisa didapat dengan ketikan kode drakor di console log SIPD Merah atau cek value dari pilihan pemda di halaman login SIPD Biru
	sipd_url : "https://$i.sipd.kemendagri.go.id/", // alamat sipd sesuai kabupaten kota masing-masing
	jml_rincian : 500, // maksimal jumlah rincian yang dikirim ke server lokal dalam satu request
	realisasi : false, // get realisasi rekening
	url_server_lokal : "https://xxxxxxxxxxxxxxx/wp-admin/admin-ajax.php", // url server lokal
	api_key : "xxxxxxxxxxxxxxxxxxx", // api key server lokal disesuaikan dengan api dari WP plugin
	sipd_private : false, // koneksi ke plugin SIPD private
	tapd : [{
		nama: "nama tim tapd 1",
		nip: "12343464575656",
		jabatan: "Sekda",
	},{
		nama: "nama tim tapd 2",
		nip: "12343464575652",
		jabatan: "Kepala Bappeda",
	},{
		nama: "nama tim tapd 3",
		nip: "12343464575653",
		jabatan: "Kepala BPPKAD",
	}], // nama tim TAPD dalam bentuk array dan object maksimal 8 orang sesuai format SIPD
	tgl_rka : "false", // pilihan nilai default "auto"=auto generate, false=fitur dimatikan, "isi tanggal sendiri"=tanggal ini akan muncul sebagai nilai default dan bisa diedit
	nama_daerah : "Magetan", // akan tampil sebelum tgl_rka
	kepala_daerah : "Bapak / Ibu xxx xx.xx", // akan tampil di lampiran perda
	replace_logo : false, // jika nilai true maka akan mengganti logo di SIPD dengan logo di file img/logo.png
	no_perkada : 'xx/xx/xx/xx', // settingan no_perkada ini untuk edit nomor, tanggal dan keterangan perkada, setting false atau kosongkan value untuk menonaktifkan
	tampil_edit_hapus_rinci : true // Menampilkan tombol edit dan hapus di halaman Detail Rincian sub kegiatan
};
"@

    try {
        Set-Content -Value $configjs -LiteralPath "$dir\$sipd\config.js" -Force -Encoding UTF8
    }
    catch {
        $configjs | Out-File -Encoding utf8 -LiteralPath "$dir\$sipd\config.js" -Force
    }
}

function main {
    # Pengecekan Chocolatey sudah terinstall
    if ((Get-Command -Name choco -ErrorAction Ignore) -and ($chocoVersion = (Get-Item "$env:ChocolateyInstall\choco.exe" -ErrorAction Ignore).VersionInfo.ProductVersion)) {
        Write-Output "Chocolatey Versi $chocoVersion sudah terinstall"
    }
    else {
        Install-choco
    }

    if (Get-Command -Name git -ErrorAction Ignore) { # Pengecekan Git sudah terinstall
        Test-sipd_chrome_extension
    }
    else {
        Install-git

        if (Test-Path $git_path) { # Pengecekan Setelah Git terinstall
            Test-sipd_chrome_extension
        }
    }

    if (Test-Path "$dir\$sipd") {
        Start-Menu
    }
    else {
        Write-Host 'sipd-chrome-extension belum terclone!'
        Test-Path $git_path
        Get-Command -Name git -ErrorAction Ignore
        git.exe
        Start-Process -FilePath $git_path
        Start-Pause
    }
}

main
