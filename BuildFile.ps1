Remove-Item -Path "./build/*" -Recurse -Force

Get-ChildItem -Path "./src/" -Recurse -File | Where-Object { $_.Extension -ne ".asm"} | ForEach-Object {
    $DestPath = $_.FullName -Replace [regex]::Escape((Resolve-Path "./src/")), (Resolve-Path "./build/")
    $DestDir = Split-Path -Path $DestPath -Parent
    if (!(Test-Path $DestDir)) { New-Item -ItemType Directory -Path $DestDir -Force }
    Copy-Item -Path $_.FullName -Destination $DestPath
}

$files = Get-ChildItem -Path "./src/*.asm" -Recurse -Force -File -Name

foreach ($i in $files) {
    $name = Split-Path -Path $i -Leaf
    if ($name[0] -eq '-') {
        $res = $i.Replace('.asm','.exc')
    }
    else {
        $res = $i.Replace('.asm','-.bin')
    }
    nasm -f bin ("./src/"+$i) -o ("./build/"+$res)
}