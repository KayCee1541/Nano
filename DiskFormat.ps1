. ./BuildFile.ps1
$DISK_SIZE = 360KB

# Create floppy image
$disk = new-object System.IO.Filestream ./disk.img, Create, ReadWrite
$disk.SetLength($DISK_SIZE)
$disk.Close()

# Floppy disk geometry
$BYTES_SEC = 512
$SEC_CLUS = 0 # computed later
$RES_SEC = 0 # computed later
$NUM_FATS = 2
$TOTAL_SECS = [int]($DISK_SIZE / $BYTES_SEC)
$SIZE_FAT = 0 # computed later
$SEC_TRCK = 9
$TRCK_SIDE = 40
$SIDES = 2
$NUM_HIDDEN = 0

$SEC_CLUS = [int][Math]::Ceiling($TOTAL_SECS / 65536)
$TOTAL_CLUSTERS = [int]($TOTAL_SECS / $SEC_CLUS)
$SIZE_FAT = [int][Math]::Ceiling($TOTAL_CLUSTERS * 2 / $BYTES_SEC)
$RES_SEC = [int]($SIZE_FAT * $NUM_FATS + 1)

# Format bootloader
$BootPath = "./build/OSBOOT-.bin"
$BootBytes = [System.IO.File]::ReadAllBytes($BootPath)

$BootBytes[11] = [BitConverter]::GetBytes($BYTES_SEC)[0]
$BootBytes[12] = [BitConverter]::GetBytes($BYTES_SEC)[1]
$BootBytes[13] = [BitConverter]::GetBytes($SEC_CLUS)[0]
$BootBytes[14] = [BitConverter]::GetBytes($RES_SEC)[0]
$BootBytes[15] = [BitConverter]::GetBytes($RES_SEC)[1]
$BootBytes[16] = [BitConverter]::GetBytes($NUM_FATS)[0]
$BootBytes[19] = [BitConverter]::GetBytes($TOTAL_SECS)[0]
$BootBytes[20] = [BitConverter]::GetBytes($TOTAL_SECS)[1]
$BootBytes[21] = [BitConverter]::GetBytes(0xFD)[0] 
$BootBytes[22] = [BitConverter]::GetBytes($SIZE_FAT)[0]
$BootBytes[23] = [BitConverter]::GetBytes($SIZE_FAT)[1]
$BootBytes[24] = [BitConverter]::GetBytes($SEC_TRCK)[0]
$BootBytes[25] = [BitConverter]::GetBytes($SEC_TRCK)[1]
$BootBytes[26] = [BitConverter]::GetBytes($SIDES)[0]
$BootBytes[27] = [BitConverter]::GetBytes($SIDES)[1]
$BootBytes[28] = [BitConverter]::GetBytes($NUM_HIDDEN)[0]
$BootBytes[29] = [BitConverter]::GetBytes($NUM_HIDDEN)[1]
$BootBytes[30] = [BitConverter]::GetBytes($NUM_HIDDEN)[2]
$BootBytes[31] = [BitConverter]::GetBytes($NUM_HIDDEN)[3]

# Write boot to disk
$Disk = [System.IO.File]::ReadAllBytes("Disk.img")

for ($i = 0; $i -lt $BootBytes.Length; $i++) {
    $Disk[$i] = $BootBytes[$i]
}

# Format files and directories to disk
$Files = Get-ChildItem -Path "./build/" -Recurse

$FolderContaining = @{}
$FileClusters = @{}

$MaxFolderChildren = $BYTES_SEC * $SEC_CLUS / 32

$FolderContaining[(Resolve-Path "./build/")] = 0
$FileClusters[(Resolve-Path "./build/")] = 0

foreach ($i in $Folders) {
    $FileEntry = [byte[]]::new(32)
    $Name = $i.Name
    $Executable = $False
    
    if (!($i.Attributes =match "Directory")) {
        $Ext = $i.Extension.ToLower()
    }
    else {
        $Ext = "   "
    }

    if (($Name[-1] -eq '-' -and $Ext -eq "bin") -or ($Ext -eq "exc")) {
        $Executable = $True
    }
}

[System.IO.File]::WriteAllBytes("Disk.img", $Disk)