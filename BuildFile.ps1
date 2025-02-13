Remove-Item -Path "./build/*" -Recurse -Force

$directories = Get-ChildItem -Path "./src/" -Recurse -Force -Directory

foreach ($i in $directories) {
    $path = Split-Path -Path $i -Parent
    $path = $path.Replace('\src','\build')
    $name = Split-Path -Path $i -Leaf
    $null = New-Item -ItemType Directory -Path $path -Name $name
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