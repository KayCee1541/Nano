# FUNCTIONS AND DATA TYPES
function Convert-To-Byte-Array {
    [CmdletBinding()]
    param (
        [uint32]$NumIn
    )
    $num = $numIn
    [byte[]] $byteArray = 0, 0, 0, 0
    $byteArray[0] = $num % 256
    $num = [int][Math]::Floor($num / 256)
    $byteArray[1] = $num % 256
    $num = [int][Math]::Floor($num / 256)
    $byteArray[2] = $num % 256
    $num = [int][Math]::Floor($num / 256)
    $byteArray[3] = $num % 256
    $num = [int][Math]::Floor($num / 256)

    return $byteArray
}

[byte[]] $DirEntryBlank = @(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, # 8.3 File name
                            0, # File Attributes (READ_ONLY=0x01 HIDDEN=0x02 SYSTEM=0x04 VOLUME_ID=0x08 DIRECTORY=0x10 ARCHIVE=0x20)
                            0, # File Owner
                            0, # Creation time in hundredths of a second, 0-199 inclusive
                            0, 0 # Creation time, multiply seconds by 2 (Hour: 5 bits, Minutes: 6 bits, Seconds: 5 bits)
                            0, 0 # The date the file was created (year: 7 bits, Month: 4 bits, Day: 5 bits)
                            0, 0 # Last access date. Same format as creation date
                            0, 0 # Last modification time. Same format as creation time
                            0, 0 # Last modification date. Same format as creation date
                            0, 0, 0, 0 # File starting cluster
                            0, 0, 0, 0 # File size, in clusters
                            )

# ------------------------------------------------------------
# CODE
./buildscript.ps1

Write-Output "GENERATING DISK IMAGE"
wsl dd if=/dev/zero of=disk.img bs=1048576 count=1024 # create disk

$disk = [System.IO.File]::ReadAllBytes("./disk.img")
$disk_size = $disk.Length

Write-Output "SCANNING FOR FILES IN BUILD DIRECTORY"
# SCAN FOR FILES IN BUILD DIRECTORY
$files = Get-ChildItem ./build -Recurse -Force -Name
$NewArray = @()
$Directories = @()
foreach ($i in $files) {
    $i = "build\" + $i
    if (($i -split '\.').Length -eq 2) {
        $NewArray += $i
    } else {
        $Directories += $i
    }
}
$files = $NewArray

Write-Output "CHECKING FOR BOOT.BIN"
# CHECK IF BOOT.BIN EXISTS
if (-not ($files -Contains "build\boot.bin")) {
    Write-Output "NO BOOTLOADER FOUND! Bootloader MUST have the name 'boot.bin' and be placed in build directory, not in any subdirectories"
    foreach($i in $files) {
        Write-Output $i
    }
    exit
}

Write-Output "REMOVING BOOT.BIN FROM FILES LIST"
# REMOVE BOOT.BIN FROM FILES LIST
$NewArray = @()
foreach ($i in $files) {
    if ($i -ne "build\boot.bin") {
        $NewArray += $i
    }
}
$files = $NewArray

# LOAD BOOT.BIN
$bootloader = [System.IO.File]::ReadAllBytes("./build/boot.bin")
$bootloadersize = $bootloader.Length

# PREPARE BOOT RECORD INFORMATION
$OEM_IDENTIFIER = "nano"
$BYTES_SECTOR = 512
$SECTORS_CLUSTER = 4
$RESERVED_SECTORS_COUNT = ($bootloadersize - ($bootloadersize % 512)) / 512 + 1
$NUMBER_FATS = 2
$SIZE_FAT = 0           # calculated later
$NUM_RDENTRIES = 0      # calculated later
$TOTAL_SECTOR_COUNT = $disk_size / $BYTES_SECTOR
$MEDIA_DESC_TYPE = 0
$DRIVE_NUMBER = 0x80

$SIZE_FAT = (($TOTAL_SECTOR_COUNT / $SECTORS_CLUSTER) * 4 / $BYTES_SECTOR) * 1.5 # add some buffer space
$SIZE_FAT = [int][Math]::Floor($SIZE_FAT) # truncate any decimal points
$EXTRA_RES_SECTORS = 0

# COUNT NUMBER OF ROOT DIRECTORY ENTRIES
foreach ($i in $files) {
    if (($i -split "\\").Length -eq 2) {
        $NUM_RDENTRIES++
    }
}

$START_SECTOR = $RESERVED_SECTORS_COUNT + ($SIZE_FAT * $NUMBER_FATS) + $EXTRA_RES_SECTORS
$START_FAT1 = $RESERVED_SECTORS_COUNT + $EXTRA_RES_SECTORS
$START_FAT2 = $RESERVED_SECTORS_COUNT + $EXTRA_RES_SECTORS + $SIZE_FAT

# CREATE FAT CLUSTER ARRAY
$FAT_ARRAY = [uint32[]]::new($SIZE_FAT * $BYTES_SECTOR / 4)
$FAT_INDEX = 0
$USED_CLUSTERS = @([uint32]"0xFFFFFFFF")

Write-Output "GENERATING FAT TABLE"
# WRITE DIRECTORIES TO DISK
# directory array will be organized based on depth, in alphabetical order
# we can iteratively generate cluster IDs because of this
$DirHashTable = @{}
for ($i = 0; $i -lt $Directories.Length; $i++) {
    $DirHashTable[$Directories[$i]] = $i
    $USED_CLUSTERS += [uint32]
    $FAT_ARRAY[$FAT_INDEX] = [uint32]$i
    $FAT_INDEX++
    $FAT_ARRAY[$FAT_INDEX] = [uint32]"0xFFFFFFFF"
    $FAT_INDEX++
}

Write-Output "GENERATING DIRECTORIES"
# PLACE FOLDERS IN THEIR RESPECTIVE DIRECTORIES 
foreach ($i in $Directories) {
    $file = ($i -split "\\")[-1]
    $path = ""
    for ($j = 0; $j -lt ($i -split "\\").Length - 1; $j++){
        $path += ($i -split "\\")[$j]
    }
    $StoredCluster = $DirHashTable[$path]

    # generate directory entry
    $DirEntry = $DirEntryBlank
    for ($j = 0; $j -lt 8; $j++) {
        try {
            $DirEntry[$j] = $file[$j]
        } catch {
            $DirEntry[$j] = 32 # space = 32
        }
    }
    $dirEntry[11] = 0b00010101
    $Bytearray = Convert-To-Byte-Array $DirHashTable[$i]
    $dirEntry[24] = $Bytearray[0]
    $dirEntry[25] = $Bytearray[1]
    $dirEntry[26] = $Bytearray[2]
    $dirEntry[27] = $Bytearray[3]
    $Bytearray = Convert-To-Byte-Array 1
    $dirEntry[28] = $Bytearray[0]
    $dirEntry[29] = $Bytearray[1]
    $dirEntry[30] = $Bytearray[2]
    $dirEntry[31] = $Bytearray[3]

    # write directory entry
    $SectorAddress = $StoredCluster * $SECTORS_CLUSTER + $START_SECTOR
    $Offset = 0
    while ($disk[$SectorAddress * $BYTES_SECTOR + $Offset] -ne 0) {
        $Offset += 32
    }
    for ($i = 0; $i -lt $dirEntry.Length; $i++) {
        $disk[$SectorAddress * $BYTES_SECTOR + $Offset] = $DirEntry[$i]
        $Offset++
    }
}

Write-Output "WRITING FILES TO DIRECTORIES"
# PLACE FILES IN THEIR RESPECTIVE DIRECTORIES
foreach ($i in $files) {
    $file = ($i -split "\\")[-1]
    $path = ""
    $extension = ($file -split "\.")[1]
    $file = ($file -split "\.")[0]
    for ($j = 0; $j -lt ($i -split "\\").Length - 1; $j++){
        $path += ($i -split "\\")[$j]
    }
    $FileBytes = [System.IO.File]::ReadAllBytes(".\" + $i)
    $FileLengthClusters = [int][Math]::Ceiling($FileBytes.Length / ($BYTES_SECTOR * $SECTORS_CLUSTER))
    $Clusters = @()

    # find next open clusters
    $z = 0
    while ($Clusters.Length -lt $FileLengthClusters) {
        while (-not $USED_CLUSTERS -contains $z) {
            $z++
        }
        $USED_CLUSTERS += $z
        $Clusters += $z
    }

    # generate directory entry
    $DirEntry = $DirEntryBlank
    $filenamebytearray = [System.Text.Encoding]::UTF8.GetBytes($file)
    $extensionbytearray = [System.Text.Encoding]::UTF8.GetBytes($extension)
    # pad arrays with spaces
    while ($filenamebytearray.Length -lt 8) {
        $filenamebytearray += 32 # 32 = space in ascii
    }
    while ($extension.Length -lt 3) {
        $extensionbytearray += 32 # 32 = space in ascii
    }

    for ($j = 0; $j -lt 8; $j++) {
        $DirEntry[$j] = $filenamebytearray[$j]
    }
    for ($j = 0; $j -lt 3; $j++) {
        $DirEntry[$j + 8] = $extensionbytearray[$j]
    }
    $dirEntry[11] = 0b00000101
    $Bytearray = Convert-To-Byte-Array $Clusters[0]
    $dirEntry[24] = $Bytearray[0]
    $dirEntry[25] = $Bytearray[1]
    $dirEntry[26] = $Bytearray[2]
    $dirEntry[27] = $Bytearray[3]
    $Bytearray = Convert-To-Byte-Array $FileLengthClusters
    $dirEntry[28] = $Bytearray[0]
    $dirEntry[29] = $Bytearray[1]
    $dirEntry[30] = $Bytearray[2]
    $dirEntry[31] = $Bytearray[3]

    # write directory entry
    $SectorAddress = $StoredCluster * $SECTORS_CLUSTER + $START_SECTOR
    $Offset = 0
    $StoredCluster = $DirHashTable[$path]
    while ($disk[$SectorAddress * $BYTES_SECTOR + $Offset] -ne 0) {
        $Offset += 32
    }
    for ($i = 0; $i -lt $dirEntry.Length; $i++) {
        $disk[$SectorAddress * $BYTES_SECTOR + $Offset] = $DirEntry[$i]
        $Offset++
    }
    # write FAT
    foreach($j in $Clusters){
        $FAT_ARRAY[$FAT_INDEX] = [uint32]$j
        $FAT_INDEX++
    }
    $FAT_ARRAY[$FAT_INDEX] = [uint32]"0xFFFFFFFF"
    $FAT_INDEX++

    for ($j = 0; $j -lt $FileBytes.Length; $j++) {
        $ADDRESS = ($Clusters[[Math]::Floor($j / ($BYTES_SECTOR * $SECTORS_CLUSTER))] * $SECTORS_CLUSTER + $START_SECTOR) * $BYTES_SECTOR + ($j % ($BYTES_SECTOR * $SECTORS_CLUSTER))
        # to explain what the mouthful of a line the above line does, it first selects the appropriate cluster of the file, then converts it to a sector number
        # after the starting sector. Then, it converts said sector to a byte address 
        $disk[$ADDRESS] = $FileBytes[$j]
    }
}

# WRITE BOOT RECORD STRUCTURE TO BOOTLOADER
# Load bytes per sector
$Bytearray = Convert-To-Byte-Array $BYTES_SECTOR
$bootloader[7] = $byteArray[0]
$bootloader[8] = $byteArray[1]

# Load sectors per cluster
$Bytearray = Convert-To-Byte-Array $SECTORS_CLUSTER
$bootloader[9] = $byteArray[0]

# Load reserved sectors count
$Bytearray = Convert-To-Byte-Array ($RESERVED_SECTORS_COUNT + $EXTRA_RES_SECTORS)
$bootloader[10] = $byteArray[0]
$bootloader[11] = $Bytearray[1]

# Number of FATs
$Bytearray = Convert-To-Byte-Array $NUMBER_FATS
$bootloader[12] = $Bytearray[0]

# Load Size of FATs in sectors
$Bytearray = Convert-To-Byte-Array $SIZE_FAT
$bootloader[13] = $Bytearray[0]
$bootloader[14] = $Bytearray[1]
$bootloader[15] = $Bytearray[2]
$bootloader[16] = $Bytearray[3]

# Load Total number of Root Directory Entries
$Bytearray = Convert-To-Byte-Array $NUM_RDENTRIES
$bootloader[17] = $Bytearray[0]
$bootloader[18] = $Bytearray[1]

# Load Total sector count
$Bytearray = Convert-To-Byte-Array $TOTAL_SECTOR_COUNT
$bootloader[19] = $Bytearray[0]
$bootloader[20] = $Bytearray[1]
$bootloader[21] = $Bytearray[2]
$bootloader[22] = $Bytearray[3]
    
# Load Media descriptor type
$Bytearray = Convert-To-Byte-Array $MEDIA_DESC_TYPE
$bootloader[23] = $Bytearray[0]

# Load Drive number
$Bytearray = Convert-To-Byte-Array $DRIVE_NUMBER
$bootloader[24] = $Bytearray[0]

Write-Output "WRITING BOOTLOADER TO DISK"
# WRITE BOOT LOADER
for ($i = 0; $i -lt $bootloadersize; $i++) {
    $disk[$i] = $bootloader[$i]
}

Write-Output "WRITTING FATS TO DISK"
# WRITE FATs
$Offset = 0
for ($i = 0; $i -lt $FAT_ARRAY.Length; $i++) {
    $Bytearray = Convert-To-Byte-Array $FAT_ARRAY[$i]
    $ADDRESS = $i * 4 + $START_FAT1 * $BYTES_SECTOR
    $disk[$ADDRESS] = $Bytearray[0]
    $disk[$ADDRESS + 1] = $Bytearray[1]
    $disk[$ADDRESS + 2] = $Bytearray[2]
    $disk[$ADDRESS + 3] = $Bytearray[3]

    $ADDRESS = $i * 4 + $START_FAT2 * $BYTES_SECTOR
    $disk[$ADDRESS] = $Bytearray[0]
    $disk[$ADDRESS + 1] = $Bytearray[1]
    $disk[$ADDRESS + 2] = $Bytearray[2]
    $disk[$ADDRESS + 3] = $Bytearray[3]
}

Write-Output "SAVING DISK INFORMATION"
# WRITE BYTES TO DISK
[System.IO.File]::WriteAllBytes("disk.img", $disk)

Write-Output "ROOT DIRECTORY PLACED AT SECTOR $START_SECTOR"