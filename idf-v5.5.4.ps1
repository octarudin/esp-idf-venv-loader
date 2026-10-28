[CmdletBinding()]
param(
    [string] $IdfPath = 'C:\esp\v5.5.4\esp-idf',
    [string] $IdfToolsPath = 'C:\Espressif'
)

$ErrorActionPreference = 'Stop'
$commandName = 'idf-v5.5.4'
$startMarker = '# >>> ESP-IDF v5.5.4 command >>>'
$endMarker = '# <<< ESP-IDF v5.5.4 command <<<'

$IdfPath = [System.IO.Path]::GetFullPath($IdfPath)
$IdfToolsPath = [System.IO.Path]::GetFullPath($IdfToolsPath)
$exportScript = Join-Path $IdfPath 'export.ps1'
$installScript = Join-Path $IdfPath 'install.ps1'

if (-not (Test-Path -LiteralPath $exportScript -PathType Leaf)) {
    throw "export.ps1 tidak ditemukan di '$exportScript'."
}

if (-not (Test-Path -LiteralPath $installScript -PathType Leaf)) {
    throw "install.ps1 tidak ditemukan di '$installScript'."
}

if (-not (Test-Path -LiteralPath $IdfToolsPath -PathType Container)) {
    New-Item -ItemType Directory -Path $IdfToolsPath -Force | Out-Null
}

$escapedIdfPath = $IdfPath.Replace("'", "''")
$escapedIdfToolsPath = $IdfToolsPath.Replace("'", "''")

# Body ini dipakai sekarang dan disimpan sebagai command di profil PowerShell.
$activationBody = @"
# Simpan kondisi awal hanya pada aktivasi pertama. Snapshot ini nantinya
# dipersempit menjadi variabel yang benar-benar diubah oleh ESP-IDF.
`$captureIdfV554State = `$null -eq `$global:IdfV554EnvironmentState
if (`$captureIdfV554State) {
    `$idfV554EnvironmentBefore = @{}
    Get-ChildItem Env: | ForEach-Object {
        `$idfV554EnvironmentBefore[`$_.Name] = `$_.Value
    }
    `$currentPrompt = `$function:prompt
    if (`$currentPrompt -and `$currentPrompt.ToString() -notmatch 'IdfV554') {
        `$global:IdfV554OriginalPrompt = `$currentPrompt
    } else {
        # Hindari menyimpan wrapper prompt lama yang dapat memanggil dirinya
        # sendiri dan menyebabkan rekursi/hang.
        `$global:IdfV554OriginalPrompt = {
            "PS `$(`$executionContext.SessionState.Path.CurrentLocation)`$('>' * (`$nestedPromptLevel + 1)) "
        }
    }

    `$global:IdfV554FunctionState = @{}
    `$idfV554HelperFunctions = @(
        'idf.py',
        'esptool.py',
        'espefuse.py',
        'espsecure.py',
        'otatool.py',
        'parttool.py',
        'deactivate'
    )
    foreach (`$functionName in `$idfV554HelperFunctions) {
        `$existingFunction = Get-Item -LiteralPath "Function:\global:`$functionName" -ErrorAction SilentlyContinue
        `$global:IdfV554FunctionState[`$functionName] = [pscustomobject]@{
            Existed = `$null -ne `$existingFunction
            ScriptBlock = if (`$existingFunction) { `$existingFunction.ScriptBlock } else { `$null }
        }
    }
}

`$env:IDF_PATH = '$escapedIdfPath'
`$env:IDF_TOOLS_PATH = '$escapedIdfToolsPath'

`$exportScript = Join-Path `$env:IDF_PATH 'export.ps1'
`$installScript = Join-Path `$env:IDF_PATH 'install.ps1'
`$pythonPattern = Join-Path `$env:IDF_TOOLS_PATH 'python_env\idf5.5_py*_env\Scripts\python.exe'
`$pythonExe = Get-ChildItem -Path `$pythonPattern -File -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not `$pythonExe) {
    Write-Host 'Virtual environment ESP-IDF v5.5.4 belum ada.' -ForegroundColor Yellow
    Write-Host 'Menjalankan installer resmi ESP-IDF (hanya diperlukan sekali)...' -ForegroundColor Yellow

    if (-not (Test-Path -LiteralPath `$installScript -PathType Leaf)) {
        throw "install.ps1 tidak ditemukan di '`$installScript'."
    }

    `$LASTEXITCODE = 0
    & `$installScript
    if (`$LASTEXITCODE -ne 0) {
        throw "Instalasi ESP-IDF gagal dengan exit code `$LASTEXITCODE."
    }

    `$pythonExe = Get-ChildItem -Path `$pythonPattern -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not `$pythonExe) {
        throw "Installer selesai, tetapi virtual environment ESP-IDF tidak ditemukan di '`$env:IDF_TOOLS_PATH\python_env'."
    }
}

if (-not (Test-Path -LiteralPath `$exportScript -PathType Leaf)) {
    throw "export.ps1 tidak ditemukan di '`$exportScript'."
}

. `$exportScript

if (-not (Get-Command idf.py -ErrorAction SilentlyContinue)) {
    throw 'Aktivasi selesai tanpa menghasilkan command idf.py.'
}

# export.ps1 sudah mengaktifkan environment Python ESP-IDF. Jangan panggil
# Activate.ps1 lagi karena tindakan itu dapat menambahkan jalur venv dua kali.
# Buang idf.py.exe versi tool (misalnya 1.0.3), prioritaskan idf.py dari source
# ESP-IDF, lalu hapus seluruh entri PATH yang duplikat secara case-insensitive.
`$idfToolsDirectory = Join-Path `$env:IDF_PATH 'tools'
`$idfExeRoot = Join-Path `$env:IDF_TOOLS_PATH 'tools\idf-exe'
`$seenPathEntries = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
`$cleanPathEntries = [System.Collections.Generic.List[string]]::new()

foreach (`$pathEntry in @(`$idfToolsDirectory) + (`$env:Path -split ';')) {
    if ([string]::IsNullOrWhiteSpace(`$pathEntry)) {
        continue
    }

    `$cleanPathEntry = `$pathEntry.Trim().Trim('"')
    `$comparisonPath = `$cleanPathEntry.TrimEnd('\')
    `$comparisonIdfExeRoot = `$idfExeRoot.TrimEnd('\')

    if (`$comparisonPath -ieq `$comparisonIdfExeRoot -or
        `$comparisonPath.StartsWith(
            `$comparisonIdfExeRoot + '\',
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
        continue
    }

    if (`$seenPathEntries.Add(`$comparisonPath)) {
        `$cleanPathEntries.Add(`$cleanPathEntry)
    }
}

`$env:Path = `$cleanPathEntries -join ';'

# Jangan bergantung pada asosiasi file .py milik Windows (yang mungkin menunjuk
# ke VS Code). Buat command idf.py yang selalu menggunakan Python dari venv IDF.
`$global:IdfV554PythonExecutable = `$pythonExe.FullName
`$global:IdfV554PythonScript = Join-Path `$env:IDF_PATH 'tools\idf.py'

if (-not (Test-Path -LiteralPath `$global:IdfV554PythonExecutable -PathType Leaf)) {
    throw "Python ESP-IDF tidak ditemukan di '`$global:IdfV554PythonExecutable'."
}
if (-not (Test-Path -LiteralPath `$global:IdfV554PythonScript -PathType Leaf)) {
    throw "idf.py tidak ditemukan di '`$global:IdfV554PythonScript'."
}

Set-Item -Path 'Function:\global:idf.py' -Value {
    & `$global:IdfV554PythonExecutable `$global:IdfV554PythonScript @args
}

# Catat nilai asli dari variabel yang berubah. Variabel lain yang dibuat user
# setelah aktivasi tidak akan disentuh ketika deactivate dijalankan.
if (`$captureIdfV554State) {
    `$idfV554EnvironmentAfter = @{}
    Get-ChildItem Env: | ForEach-Object {
        `$idfV554EnvironmentAfter[`$_.Name] = `$_.Value
    }

    `$allEnvironmentNames = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    foreach (`$name in `$idfV554EnvironmentBefore.Keys) {
        [void] `$allEnvironmentNames.Add(`$name)
    }
    foreach (`$name in `$idfV554EnvironmentAfter.Keys) {
        [void] `$allEnvironmentNames.Add(`$name)
    }

    `$changedEnvironment = @{}
    foreach (`$name in `$allEnvironmentNames) {
        `$existedBefore = `$idfV554EnvironmentBefore.ContainsKey(`$name)
        `$existsAfter = `$idfV554EnvironmentAfter.ContainsKey(`$name)
        `$valueBefore = if (`$existedBefore) { `$idfV554EnvironmentBefore[`$name] } else { `$null }
        `$valueAfter = if (`$existsAfter) { `$idfV554EnvironmentAfter[`$name] } else { `$null }

        if (`$existedBefore -ne `$existsAfter -or `$valueBefore -cne `$valueAfter) {
            `$changedEnvironment[`$name] = [pscustomobject]@{
                Existed = `$existedBefore
                Value = `$valueBefore
            }
        }
    }
    `$global:IdfV554EnvironmentState = `$changedEnvironment
}

# PowerShell export ESP-IDF 5.5.4 belum menyediakan function deactivate.
# Function ini mengembalikan environment tepat ke kondisi sebelum aktivasi.
Set-Item -Path 'Function:\global:deactivate' -Value {
    `$savedState = `$global:IdfV554EnvironmentState
    if (`$null -eq `$savedState) {
        Write-Host 'Environment ESP-IDF v5.5.4 tidak sedang aktif.' -ForegroundColor Yellow
        return
    }

    foreach (`$name in `$savedState.Keys) {
        `$entry = `$savedState[`$name]
        if (`$entry.Existed) {
            [Environment]::SetEnvironmentVariable(`$name, `$entry.Value, 'Process')
        } else {
            [Environment]::SetEnvironmentVariable(`$name, `$null, 'Process')
        }
    }

    if (`$global:IdfV554OriginalPrompt) {
        Set-Item -Path 'Function:\global:prompt' -Value `$global:IdfV554OriginalPrompt
    }

    foreach (`$functionName in `$global:IdfV554FunctionState.Keys) {
        `$functionEntry = `$global:IdfV554FunctionState[`$functionName]
        `$functionPath = "Function:\global:`$functionName"
        if (`$functionEntry.Existed) {
            Set-Item -Path `$functionPath -Value `$functionEntry.ScriptBlock
        } else {
            Remove-Item -Path `$functionPath -ErrorAction SilentlyContinue
        }
    }

    Remove-Variable -Name IdfV554PythonExecutable -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name IdfV554PythonScript -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name IdfV554OriginalPrompt -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name IdfV554EnvironmentState -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name IdfV554FunctionState -Scope Global -ErrorAction SilentlyContinue

    Write-Host 'Environment ESP-IDF v5.5.4 telah dinonaktifkan.' -ForegroundColor Green
}

# Tampilkan indikator (venv) tanpa mengaktifkan ulang venv atau mengubah PATH.
function global:prompt {
    Write-Host -NoNewline '(venv) ' -ForegroundColor Green
    "PS `$(`$executionContext.SessionState.Path.CurrentLocation)`$('>' * (`$nestedPromptLevel + 1)) "
}
"@

$profilePath = $PROFILE.CurrentUserCurrentHost
$profileDirectory = Split-Path -Parent $profilePath
if (-not (Test-Path -LiteralPath $profileDirectory)) {
    New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
}

$profileBlock = @"
$startMarker
Set-Item -Path 'Function:\global:$commandName' -Value {
$activationBody
}
$endMarker
"@

# Jangan gunakan Regex.Replace untuk profileBlock karena karakter '$' di dalam
# kode PowerShell dapat dianggap sebagai substitution regex dan memperbesar file
# secara eksponensial. Perbarui profil secara streaming dan literal.
$profileSourcePath = if (Test-Path -LiteralPath $profilePath -PathType Leaf) {
    $profilePath
} else {
    $null
}

$profileInfo = if ($profileSourcePath) {
    Get-Item -LiteralPath $profileSourcePath
} else {
    $null
}

# Profil normal hanya beberapa KB. Jika sudah lebih dari 5 MB, simpan backup dan
# pulihkan basis profil dari lokasi Documents standar bila tersedia.
if ($profileInfo -and $profileInfo.Length -gt 5MB) {
    $backupTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $corruptProfileBackup = "$profilePath.corrupt-$backupTimestamp.bak"
    Copy-Item -LiteralPath $profilePath -Destination $corruptProfileBackup

    $fallbackProfilePath = Join-Path $HOME 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
    $fallbackInfo = if (
        $fallbackProfilePath -ne $profilePath -and
        (Test-Path -LiteralPath $fallbackProfilePath -PathType Leaf)
    ) {
        Get-Item -LiteralPath $fallbackProfilePath
    } else {
        $null
    }

    if ($fallbackInfo -and $fallbackInfo.Length -le 5MB) {
        $profileSourcePath = $fallbackProfilePath
    } else {
        $profileSourcePath = $null
    }

    Write-Warning "Profil PowerShell rusak dan telah dibackup ke: $corruptProfileBackup"
}

$temporaryProfilePath = "$profilePath.idf-v5.5.4.tmp"
if (Test-Path -LiteralPath $temporaryProfilePath) {
    [System.IO.File]::Delete($temporaryProfilePath)
}

$utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
$writer = [System.IO.StreamWriter]::new($temporaryProfilePath, $false, $utf8WithoutBom)
try {
    $managedBlockDepth = 0
    if ($profileSourcePath) {
        $reader = [System.IO.StreamReader]::new($profileSourcePath, $true)
        try {
            while (($profileLine = $reader.ReadLine()) -ne $null) {
                $trimmedProfileLine = $profileLine.Trim()
                if ($trimmedProfileLine -eq $startMarker) {
                    $managedBlockDepth++
                    continue
                }
                if ($trimmedProfileLine -eq $endMarker) {
                    if ($managedBlockDepth -gt 0) {
                        $managedBlockDepth--
                    }
                    continue
                }
                if ($managedBlockDepth -eq 0) {
                    $writer.WriteLine($profileLine)
                }
            }
        } finally {
            $reader.Dispose()
        }
    }

    $writer.WriteLine()
    $writer.WriteLine($profileBlock)
} finally {
    $writer.Dispose()
}

Move-Item -LiteralPath $temporaryProfilePath -Destination $profilePath -Force
Set-Item -Path "Function:\global:$commandName" -Value ([scriptblock]::Create($activationBody))

# Pasang wrapper Command Prompt ke WindowsApps milik user. Folder ini sudah ada
# secara permanen di User PATH sehingga tidak bergantung pada entri PATH baru
# yang dapat hilang atau tidak diwariskan ke proses Command Prompt berikutnya.
$windowsAppsDirectory = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
$cmdBinDirectory = if (Test-Path -LiteralPath $windowsAppsDirectory -PathType Container) {
    $windowsAppsDirectory
} else {
    Join-Path $env:LOCALAPPDATA 'idf-tools\bin'
}
$cmdWrapperPath = Join-Path $cmdBinDirectory "$commandName.cmd"
$cmdDeactivatePath = Join-Path $cmdBinDirectory 'deactivate.cmd'
$cmdSessionBinDirectory = Join-Path $env:LOCALAPPDATA 'idf-tools\session-bin'
$cmdSessionDeactivatePath = Join-Path $cmdSessionBinDirectory 'deactivate.cmd'
$cmdIdfPyWrapperPath = Join-Path $cmdSessionBinDirectory 'idf.py.cmd'
if (-not (Test-Path -LiteralPath $cmdBinDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $cmdBinDirectory -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $cmdSessionBinDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $cmdSessionBinDirectory -Force | Out-Null
}

$cmdWrapper = @"
@echo off

if defined IDF_V554_ACTIVE (
    echo ESP-IDF v5.5.4 sudah aktif pada Command Prompt ini.
    exit /b 0
)

rem Simpan kondisi sebelum aktivasi agar deactivate.cmd dapat memulihkannya.
set "IDF_V554_OLD_PATH=%PATH%"
set "IDF_V554_OLD_PROMPT=%PROMPT%"
set "IDF_V554_OLD_IDF_PATH=%IDF_PATH%"
set "IDF_V554_OLD_IDF_TOOLS_PATH=%IDF_TOOLS_PATH%"
set "IDF_V554_OLD_IDF_PYTHON_ENV_PATH=%IDF_PYTHON_ENV_PATH%"
set "IDF_V554_OLD_IDF_COMPONENT_LOCAL_STORAGE_URL=%IDF_COMPONENT_LOCAL_STORAGE_URL%"
set "IDF_V554_OLD_IDF_DEACTIVATE_FILE_PATH=%IDF_DEACTIVATE_FILE_PATH%"
set "IDF_V554_OLD_IDF_TOOLS_INSTALL_CMD=%IDF_TOOLS_INSTALL_CMD%"
set "IDF_V554_OLD_IDF_TOOLS_EXPORT_CMD=%IDF_TOOLS_EXPORT_CMD%"
set "IDF_V554_OLD_ESP_IDF_VERSION=%ESP_IDF_VERSION%"
set "IDF_V554_OLD_ESP_ROM_ELF_DIR=%ESP_ROM_ELF_DIR%"
set "IDF_V554_OLD_OPENOCD_SCRIPTS=%OPENOCD_SCRIPTS%"
set "IDF_V554_OLD_VIRTUAL_ENV=%VIRTUAL_ENV%"

set "IDF_PATH=$IdfPath"
set "IDF_TOOLS_PATH=$IdfToolsPath"

if not exist "%IDF_PATH%\export.bat" (
    echo ERROR: export.bat tidak ditemukan di "%IDF_PATH%\export.bat".
    goto :activation_failed
)

call "%IDF_PATH%\export.bat"
if errorlevel 1 goto :activation_failed

rem export.bat sudah menyiapkan Python environment dan PATH. Jangan panggil
rem activate.bat lagi agar jalur venv tidak ditambahkan untuk kedua kalinya.
set "IDF_V554_ACTIVE=1"
set "IDF_V554_SESSION_BIN=$cmdSessionBinDirectory"
set "PATH=%IDF_V554_SESSION_BIN%;%PATH%"
set "PROMPT=(venv) %IDF_V554_OLD_PROMPT%"
exit /b 0

:activation_failed
set "IDF_V554_ACTIVE=1"
call "%~dp0deactivate.cmd" >nul
echo ERROR: Aktivasi ESP-IDF v5.5.4 gagal.
exit /b 1
"@

Set-Content -LiteralPath $cmdWrapperPath -Value $cmdWrapper -Encoding ascii

$cmdDeactivateWrapper = @'
@echo off

if not defined IDF_V554_ACTIVE (
    echo Environment ESP-IDF v5.5.4 tidak sedang aktif.
    exit /b 0
)

set "PATH=%IDF_V554_OLD_PATH%"
set "PROMPT=%IDF_V554_OLD_PROMPT%"
set "IDF_PATH=%IDF_V554_OLD_IDF_PATH%"
set "IDF_TOOLS_PATH=%IDF_V554_OLD_IDF_TOOLS_PATH%"
set "IDF_PYTHON_ENV_PATH=%IDF_V554_OLD_IDF_PYTHON_ENV_PATH%"
set "IDF_COMPONENT_LOCAL_STORAGE_URL=%IDF_V554_OLD_IDF_COMPONENT_LOCAL_STORAGE_URL%"
set "IDF_DEACTIVATE_FILE_PATH=%IDF_V554_OLD_IDF_DEACTIVATE_FILE_PATH%"
set "IDF_TOOLS_INSTALL_CMD=%IDF_V554_OLD_IDF_TOOLS_INSTALL_CMD%"
set "IDF_TOOLS_EXPORT_CMD=%IDF_V554_OLD_IDF_TOOLS_EXPORT_CMD%"
set "ESP_IDF_VERSION=%IDF_V554_OLD_ESP_IDF_VERSION%"
set "ESP_ROM_ELF_DIR=%IDF_V554_OLD_ESP_ROM_ELF_DIR%"
set "OPENOCD_SCRIPTS=%IDF_V554_OLD_OPENOCD_SCRIPTS%"
set "VIRTUAL_ENV=%IDF_V554_OLD_VIRTUAL_ENV%"

set "IDF_V554_ACTIVE="
set "IDF_V554_OLD_PATH="
set "IDF_V554_OLD_PROMPT="
set "IDF_V554_OLD_IDF_PATH="
set "IDF_V554_OLD_IDF_TOOLS_PATH="
set "IDF_V554_OLD_IDF_PYTHON_ENV_PATH="
set "IDF_V554_OLD_IDF_COMPONENT_LOCAL_STORAGE_URL="
set "IDF_V554_OLD_IDF_DEACTIVATE_FILE_PATH="
set "IDF_V554_OLD_IDF_TOOLS_INSTALL_CMD="
set "IDF_V554_OLD_IDF_TOOLS_EXPORT_CMD="
set "IDF_V554_OLD_ESP_IDF_VERSION="
set "IDF_V554_OLD_ESP_ROM_ELF_DIR="
set "IDF_V554_OLD_OPENOCD_SCRIPTS="
set "IDF_V554_OLD_VIRTUAL_ENV="
set "IDF_V554_SESSION_BIN="

echo Environment ESP-IDF v5.5.4 telah dinonaktifkan.
'@

Set-Content -LiteralPath $cmdDeactivatePath -Value $cmdDeactivateWrapper -Encoding ascii
Set-Content -LiteralPath $cmdSessionDeactivatePath -Value $cmdDeactivateWrapper -Encoding ascii

$cmdIdfPyWrapper = @'
@echo off

if not defined IDF_V554_ACTIVE (
    echo ERROR: Environment ESP-IDF v5.5.4 belum diaktifkan.
    exit /b 1
)

if not exist "%IDF_PYTHON_ENV_PATH%\Scripts\python.exe" (
    echo ERROR: Python venv ESP-IDF tidak ditemukan di "%IDF_PYTHON_ENV_PATH%\Scripts\python.exe".
    exit /b 1
)

if not exist "%IDF_PATH%\tools\idf.py" (
    echo ERROR: idf.py tidak ditemukan di "%IDF_PATH%\tools\idf.py".
    exit /b 1
)

"%IDF_PYTHON_ENV_PATH%\Scripts\python.exe" "%IDF_PATH%\tools\idf.py" %*
exit /b %errorlevel%
'@

Set-Content -LiteralPath $cmdIdfPyWrapperPath -Value $cmdIdfPyWrapper -Encoding ascii

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$userPathEntries = @($userPath -split ';' | Where-Object { $_ })
$cmdBinAlreadyInPath = $userPathEntries | Where-Object {
    $_.TrimEnd('\') -ieq $cmdBinDirectory.TrimEnd('\')
}

if (-not $cmdBinAlreadyInPath) {
    $newUserPath = if ($userPath) {
        $userPath.TrimEnd(';') + ';' + $cmdBinDirectory
    } else {
        $cmdBinDirectory
    }
    [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
}

if (($env:Path -split ';') -notcontains $cmdBinDirectory) {
    $env:Path += ";$cmdBinDirectory"
}

Write-Host "Command '$commandName' telah dipasang di profil PowerShell." -ForegroundColor Green
Write-Host "Wrapper Command Prompt: $cmdWrapperPath" -ForegroundColor Green
Write-Host "Deactivation Command Prompt: $cmdDeactivatePath" -ForegroundColor Green
Write-Host "idf.py Command Prompt: $cmdIdfPyWrapperPath" -ForegroundColor Green
Write-Host ''
Write-Host "Instalasi selesai. Aktifkan saat diperlukan dengan: $commandName" -ForegroundColor Green

