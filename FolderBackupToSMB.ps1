<#
.SYNOPSIS
  Zabali priecinok do 7z a prekopiruje archív na SMB (bez ukladania hesla v skripte).
.PARAMETER SourceFolder
.PARAMETER SevenZipPath
.PARAMETER SMBPath  # UNC cesta, napr. \\server\backup
.PARAMETER ArchivePrefix
.PARAMETER RetentionCount  # kolko najnovsich archivov zachovat
#>

param(
    [string]$SourceFolder = "CESTA K ZALOHOVANEMU PRIECINKU",
    [string]$SevenZipPath = "C:\Program Files\7-Zip\7z.exe",
    [string]$SMBPath = "\\CESTA NA ULOZENIE NA SIET SMB",
    [string]$ArchivePrefix = "NASTAV NAZOV ZALOHY",
    [int]$RetentionCount = 10  # predvolený počet archívov na zachovanie
)

# --- nastavenie logovania ---
$LogDir = "C:\ProgramData\BackupToSMB\logs"
if (-not (Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }
$LogFile = Join-Path $LogDir ("backup_" + (Get-Date -Format "yyyyMMdd") + ".log")

function Log {
    param($msg)
    $line = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - $msg"
    Write-Output $line | Tee-Object -FilePath $LogFile -Append
}

try {
    Log "=== Spustenie backup skriptu ==="
    if (-not (Test-Path $SourceFolder)) { throw "Source folder '$SourceFolder' not found." }
    if (-not (Test-Path $SevenZipPath)) { throw "7z not found at '$SevenZipPath'." }

    # vytvorit nazov archivu s timestampom
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $ArchiveName = "$($ArchivePrefix)_$timestamp.7z"
    $ArchivePath = Join-Path $env:TEMP $ArchiveName

    Log "Balenie '$SourceFolder' -> '$ArchivePath' (7z)"
    # Spustenie 7z s vypisom priebehu v konzole a logovanie v reálnom čase
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $SevenZipPath
    $processInfo.Arguments = "a -t7z `"$ArchivePath`" `"$(Join-Path $SourceFolder '*')`" -mx=5 -bsp1"
    $processInfo.RedirectStandardOutput = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::Start($processInfo)
    while (-not $process.StandardOutput.EndOfStream) {
        $line = $process.StandardOutput.ReadLine()
        # Preskočiť prázdne riadky
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        # Logovať každý neprázdny riadok výstupu
        Log "Raw output: $line"
        # Zachytávanie percent (napr. "10 %", "20%", "10% 244 + ImapMail\...")
        if ($line -match "^\s*(\d+)\s*\%") {
            $percent = [int]$matches[1]
            $fileInfo = if ($line -match "\d+\s*\+\s*(.+)$") { $matches[1] } else { "N/A" }
            Write-Progress -Activity "Kompresia archívu" -Status "Komprimujem: $percent% ($fileInfo)" -PercentComplete $percent
            Log "Progress: $percent%"
        }
    }
    $process.WaitForExit()

    # Oneskorenie pre zabezpečenie, že archív je zapísaný na disk
    Start-Sleep -Seconds 5
    if ($process.ExitCode -ne 0 -or -not (Test-Path $ArchivePath)) {
        throw "Archív sa nevytvoril. Návratový kód: $($process.ExitCode), Cesta: $ArchivePath"
    }

    Write-Progress -Activity "Kompresia archívu" -Completed
    Log "Archiv vytvoreny."

    # Skopíruj na SMB
    $Destination = Join-Path $SMBPath $ArchiveName
    Log "Kopirujem archiv na '$Destination'..."
    Copy-Item -Path $ArchivePath -Destination $Destination -Force

    if (-not (Test-Path $Destination)) { throw "Kopírovanie zlyhalo." }
    Log "Kopirovanie uspesne."

    # vymazat lokalny docasny archiv
    Remove-Item -Path $ArchivePath -Force -ErrorAction SilentlyContinue
    Log "Docasny archiv odstraneny z: $ArchivePath"

    # Rotácia: vymaž staré archívy na SMB podľa RetentionCount
    if ($RetentionCount -gt 0) {
        Log "Odstranujem nadbytocne archivy, zachovam $RetentionCount najnovsich z $SMBPath"
        try {
            $archives = Get-ChildItem -Path $SMBPath -Filter "$($ArchivePrefix)*.7z" -ErrorAction Stop |
                Sort-Object LastWriteTime -Descending |
                Select-Object -Skip $RetentionCount
            foreach ($archive in $archives) {
                $p = $archive.FullName
                Log "Mazem: $p"
                Remove-Item -Path $p -Force -ErrorAction Continue
            }
        } catch {
            Log "Chyba pri rotacii: $_"
        }
    }

    Log "=== Backup dokonceny OK ==="
    exit 0
}
catch {
    Log "ERROR: $_"
    Write-Progress -Activity "Kompresia archívu" -Completed
    exit 1
}
