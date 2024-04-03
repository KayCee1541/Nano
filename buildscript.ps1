$Files = Get-ChildItem -Path ./src -Recurse -Force -Name
# clear out build folder
Get-ChildItem -Path ./build -File -Recurse -Force | foreach { $_.Delete()}

# Filter out boot.asm
$NewArray = @()
foreach($i in $Files) {
    if ($i -ne "boot.asm") {
        $NewArray += $i
    }
}
$Files = $NewArray

# Compile boot.asm prematurely
nasm -f bin ./src/boot.asm -o ./build/boot.bin

# Organize source files into respective compile groups
$CCompiles = @()
$ASMCompiles = @()
$OtherFiles = @() # Other files will be copied directly to build directory
foreach ($i in $Files) {
    if (($i -split ".")[1] -eq "c") {
        $CCompiles += $i
    } elseif (($i -split ".")[1] -eq "asm") {
        $ASMCompiles += $i
    } else {
        $OtherFiles += $i
    }
}

# Process source file names into their respective build file names
$COUTPUTS = @()
foreach ($i in $CCompiles) {
    $COUTPUTS += ("build\" + ($i -split ".")[0] + "exc")
}

$ASMOUTPUTS = $()
foreach($i in $ASMCompiles) {
    $ASMOUTPUTS += ("build\" + ($i -split ".")[0] + "exc")
}

# Compile C files
for ($i = 0; $i -lt $CCompiles.Length; $i++) {
    # Check if file has associated linker file
    if ($files.Contains(($i -split ".")[0] + "ld")) {
        $linker = ($i -split ".")[0] + "ld"
        wsl gcc -march=x86_64 -nostartfiles -nostdlib -ffreestanding -nodefaultlibs -T $linker -Wall -Wextra -c $CCompiles[$i] -o $COUTPUTS[$i]
    }
    else {
        wsl gcc -march=x86_64 -nostartfiles -nostdlib -ffreestanding -nodefaultlibs -Wall -Wextra -c $CCompiles[$i] -o $COUTPUTS[$i]
    }
}

# Compile ASM files
for ($i = 0; $i -lt $ASMCompiles.Length; $i++) {
    # Check if file has associated linker file
    if ($files.Contains(($i -split ".")[0] + "ld")) {
        $linker = ($i -split ".")[0] + "ld"
        $output = ($i -split ".")[0] + "o"
        nasm $ASMCompiles[$i] $output
        gcc ld $output -T $linker -o $ASMOUTPUTS[$i]
        Remove-Item $output
    }
    else {
        nasm -f elf64 $ASMCompiles[$i] -o $ASMOUTPUTS[$i]
    }
}

foreach ($i in $OtherFiles) {
    $destination = ".\build\" + $i
    $i = ".\src\" + $i
    Copy-Item $i -Destination $destination
}