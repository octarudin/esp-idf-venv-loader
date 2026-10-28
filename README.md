# ESP-IDF Virtual Environment Loader

Wrapper untuk mengaktifkan dan menonaktifkan environment **ESP-IDF v5.5.4**
dengan satu perintah yang sama pada Windows PowerShell dan Command Prompt.

```text
idf-v5.5.4
```

Wrapper dapat dipanggil dari direktori proyek mana pun tanpa mengubah working
directory terminal.

## Dukungan sistem

- Windows 10 atau Windows 11
- Windows PowerShell
- Command Prompt (`cmd.exe`)
- ESP-IDF v5.5.4
- Python environment ESP-IDF 3.13

Konfigurasi ini telah diuji pada Windows build `10.0.26300.9711` dengan Python
`3.13.11`.

> Script ini khusus Windows. Pada Linux, aktivasi biasanya dilakukan dengan
> `source` melalui alias di `.bashrc`.

## Struktur instalasi yang digunakan

Wrapper mengharapkan ESP-IDF dan IDF Tools berada di lokasi berikut:

| Komponen | Lokasi |
| --- | --- |
| ESP-IDF source (`IDF_PATH`) | `C:\esp\v5.5.4\esp-idf` |
| ESP-IDF tools (`IDF_TOOLS_PATH`) | `C:\Espressif` |
| Python venv | `C:\Espressif\python_env\idf5.5_py3.13_env` |

`IDF_PATH` dan `IDF_TOOLS_PATH` memiliki fungsi berbeda. Jangan mengganti
`IDF_TOOLS_PATH` menjadi folder source ESP-IDF.

## File repository

```text
esp-idf-venv-loader/
├── idf-v5.5.4.ps1
└── README.md
```

`idf-v5.5.4.ps1` merupakan installer utama. Script ini menyiapkan function
PowerShell dan wrapper Command Prompt.

## Environment Variables

Pastikan folder berikut tersedia pada **User Path**:

```text
%LOCALAPPDATA%\Microsoft\WindowsApps
```

Nilai aktual umumnya berbentuk:

```text
C:\Users\<username>\AppData\Local\Microsoft\WindowsApps
```

Tambahkan melalui:

```text
Environment Variables
→ User variables
→ Path
→ New
→ %LOCALAPPDATA%\Microsoft\WindowsApps
```

Folder ESP-IDF, Python venv, dan `session-bin` tidak perlu ditambahkan secara
permanen ke `PATH`. Wrapper menambahkannya hanya selama environment aktif.

## Instalasi

Buka PowerShell pada folder repository, lalu jalankan:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\idf-v5.5.4.ps1
```

Installer akan:

1. Menambahkan function `idf-v5.5.4` ke `$PROFILE` PowerShell.
2. Menyiapkan function PowerShell `idf.py` dan `deactivate` ketika environment
   diaktifkan.
3. Membuat wrapper Command Prompt di
   `%LOCALAPPDATA%\Microsoft\WindowsApps`.
4. Membuat wrapper sesi di `%LOCALAPPDATA%\idf-tools\session-bin`.
5. Menambahkan folder WindowsApps ke User `PATH` bila belum tersedia.

File yang dihasilkan:

| File | Fungsi |
| --- | --- |
| `%LOCALAPPDATA%\Microsoft\WindowsApps\idf-v5.5.4.cmd` | Entry point Command Prompt |
| `%LOCALAPPDATA%\Microsoft\WindowsApps\deactivate.cmd` | Fallback deactivation CMD |
| `%LOCALAPPDATA%\idf-tools\session-bin\idf.py.cmd` | Menjalankan `idf.py` dengan Python venv yang benar |
| `%LOCALAPPDATA%\idf-tools\session-bin\deactivate.cmd` | Deactivation selama sesi CMD aktif |

Installer tidak langsung mengaktifkan ESP-IDF. Aktivasi dilakukan secara manual
saat diperlukan.

## Penggunaan pada PowerShell

Masuk ke folder proyek apa pun dan aktifkan ESP-IDF:

```powershell
cd D:\project\esp32\project-baru
idf-v5.5.4
```

Prompt akan berubah menjadi:

```text
(venv) PS D:\project\esp32\project-baru>
```

Verifikasi dan build:

```powershell
idf.py --version
idf.py build
```

Versi yang diharapkan:

```text
ESP-IDF v5.5.4
```

Keluar dari environment:

```powershell
deactivate
```

Untuk melihat resolusi command pada PowerShell, gunakan:

```powershell
Get-Command python
Get-Command idf.py -All
Get-Command deactivate
```

`where` pada PowerShell adalah alias `Where-Object`. Gunakan `Get-Command` atau
`where.exe` bila ingin mencari executable.

## Penggunaan pada Command Prompt

Aktifkan dari folder proyek apa pun:

```cmd
cd /d D:\project\esp32\project-baru
idf-v5.5.4
```

Prompt akan berubah menjadi:

```text
(venv) D:\project\esp32\project-baru>
```

Verifikasi dan build:

```cmd
where python
where idf.py
where deactivate
idf.py --version
idf.py build
```

Ketika aktif, hasil pertama untuk `idf.py` dan `deactivate` seharusnya berasal
dari:

```text
%LOCALAPPDATA%\idf-tools\session-bin
```

Keluar dari environment:

```cmd
deactivate
```

## Perilaku aktivasi dan deactivation

Ketika `idf-v5.5.4` dijalankan, wrapper:

- menetapkan `IDF_PATH` dan `IDF_TOOLS_PATH`;
- menjalankan `export.ps1` atau `export.bat` resmi ESP-IDF;
- memprioritaskan Python venv ESP-IDF;
- memastikan `idf.py` menggunakan source ESP-IDF v5.5.4, bukan
  `idf.py.exe` versi tool lain;
- mencegah penambahan jalur `PATH` secara berulang; dan
- mempertahankan working directory saat ini.

Ketika `deactivate` dijalankan, wrapper:

- mengembalikan `PATH` ke kondisi sebelum aktivasi;
- mengembalikan prompt terminal;
- memulihkan variabel environment sebelumnya; dan
- menghapus function atau wrapper sesi ESP-IDF dari resolusi command aktif.

Perubahan environment hanya berlaku pada terminal saat itu dan hilang ketika
terminal ditutup.

## Pemecahan masalah

### Command tidak ditemukan pada Command Prompt

Periksa:

```cmd
where idf-v5.5.4
```

Hasil yang diharapkan:

```text
C:\Users\<username>\AppData\Local\Microsoft\WindowsApps\idf-v5.5.4.cmd
```

Pastikan `%LOCALAPPDATA%\Microsoft\WindowsApps` tersedia pada User `PATH`, lalu
buka ulang terminal.

### `idf.py` membuka VS Code

Hal ini terjadi ketika file `.py` dijalankan melalui file association Windows.
Aktifkan environment terlebih dahulu:

```text
idf-v5.5.4
```

Wrapper PowerShell dan Command Prompt akan meneruskan `idf.py` secara eksplisit
ke Python venv ESP-IDF.

### Python diarahkan ke Microsoft Store

Periksa urutan Python setelah aktivasi:

```cmd
where python
```

Lokasi pertama harus berupa:

```text
C:\Espressif\python_env\idf5.5_py3.13_env\Scripts\python.exe
```

### Profil PowerShell rusak atau terlalu besar

Installer mendeteksi profil yang lebih besar dari 5 MB, membuat backup dengan
akhiran `.corrupt-<timestamp>.bak`, lalu memulihkan profil secara streaming.
Updater tidak menggunakan `Regex.Replace`, sehingga simbol PowerShell seperti
`$_` tidak dapat memperbesar isi profil secara berulang.

## Ringkasan alur

```text
idf-v5.5.4
    ↓
(venv) aktif
    ↓
idf.py build
    ↓
deactivate
    ↓
terminal kembali normal
```

