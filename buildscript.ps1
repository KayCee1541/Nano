Get-ChildItem "./build" -Recurse | Remove-Item

$SourceFiles = Get-ChildItem -Path ".\src" -Recurse -Name -File -Include "*.asm"
$MiscFiles = Get-ChildItem -Path ".\src" -Recurse -Name -Exclude "*.asm"
$Config = @()
if (Test-Path -Path "./BuildConf.cfg") {
    $Config = Get-Content -Path "./BuildConf.cfg"
}

$FilesHash = @{}
foreach ($i in $SourceFiles) {
    $FilesHash[$i] = ($i -Split "\.")[0] + ".bin"
}
foreach ($i in $MiscFiles) {
    $FilesHash[$i] = $i
}

foreach ($i in $Config) {
    if ($FilesHash.ContainsKey($i.Split(' ')[0])) {
        $FilesHash[$i.Split(' ')[0]] = $i.Split(' ')[1]
    }
}

foreach ($i in $SourceFiles) {
    nasm -f bin (".\src\" + $i) -o (".\build\" + $FilesHash[$i])
}

foreach ($i in $MiscFiles) {
    Copy-Item (".\src\" + $i) -Destination (".\build\" + $FilesHash[$i])
}

$Fat16_MBR = Get-Content -Path ./fat16_MBR.bin -AsByteStream -Raw
$BootLoader = Get-Content -Path ./build/boot.bin -AsByteStream -Raw

for ($i = 0; $i -lt $Fat16_MBR.Length; $i++){
    if ($Fat16_MBR[$i] -ne 0) {
        $BootLoader[$i] = $Fat16_MBR[$i]
    }
}

[System.IO.File]::WriteAllBytes("./build/boot.bin", $BootLoader)