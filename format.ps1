Write-Output "Formatting disk... (This may take a while)"
. ./ToolsLib.ps1

$image = "./disk.img"
$boot1 = "./build/boot1.bin"
$boot2 = "./build/boot2.bin"

# map of disk, num = starting sector number unless otherwise specified
$clustersize = 4
$SectorSize = 512 # in bytes
$reserved = 0
$FAT1 = 3
$FAT2 = 259
$FATSize = 256
$DirTable = 516
$EntrySize = 32 # in bytes
$FirstCluster = 1153 # cluster, not sector number

$boot1bin = [System.IO.File]::ReadAllBytes($boot1)
$boot2bin = [System.IO.File]::ReadAllBytes($boot2)
try {
    $imagesize = [System.IO.File]::ReadAllBytes($image).Count
}
catch{
    exit
}
$data = [byte[]]::new($imagesize)
$index = 0

$boot2binSize = [Math]::Ceiling($boot2bin.Count / ($SectorSize * $clustersize)) # generate boot2 binary size in clusters

Write-Output "Writing boot1 data"
for ($i = 0; $i -lt $boot1bin.Count; $i++){
    $data[$i] = $boot1bin[$i]
}


# Set up directory table
$EntryFormat = [byte[]](0, 0, # File ID
                        0, 0, 0, 0, 0, 0, 0, 0, # File name, padded with spaces
                        0, 0, 0, # file extension
                        128, # flags 1 (0x80 set to indicate entry is free)
                        0, # flags 2
                        0, # creation time in 0.01ths of a second (ranges 0-200)
                        0, 0, # time of creation
                        0, 0, # date of creation
                        0, # Owner ID
                        0, 0, # ID of containing directory (root is 0)
                        0, 0, # File starting cluster
                        0, 0, # File size (in # of clusters)
                        0, 0, # Last modified time
                        0, 0, # Last modified date
                        0)    # Extraneous value, may be used by software (boot2 magic number stored here)

$RootEntry = [byte[]](0, 0, # File ID
                      82, 79, 79, 84, 68, 73, 82, 32, # File name, padded with spaces
                      100, 105, 114, # file extension (directories can have it empty or "dir")
                      62, # flags 1
                      0, # flags 2
                      0, # creation time in 0.01ths of a second (ranges 0-200)
                      0, 0, # time of creation
                      0, 0, # date of creation
                      0, # Owner ID
                      0, 0, # ID of containing directory (root is 0)
                      0, 0, # File starting cluster
                      0, 0, # File size (in # of clusters)
                      0, 0, # Last modified time
                      0, 0, # Last modified date
                      0)    # Extraneous value, may be used by softeare (boot2 magic number stored here)

$dtindex = $DirTable * $SectorSize

Write-Output "Setting up Directory Table..."
while (($dtindex / $SectorSize) -lt ($FirstCluster * $clustersize - 32)){
    foreach($i in $EntryFormat){
        $data[$dtindex] = $i
        $dtindex++
    }
    try {$EntryFormat[0]++}
    Catch{
        $EntryFormat[0] = 0
        $EntryFormat[1]++
    }
}

$dtindex = $DirTable * $SectorSize
$flags1 = $data[$dtindex + 0x0D]
for ($i = 0; $i -lt 32; $i++){
    $data[$dtindex + $i] = $RootEntry[$i]
}


# FAT scan:
[System.Collections.ArrayList]$UnusedClusters = [System.Linq.Enumerable]::Range($FirstCluster,65535).ToArray()
$FatRealIndex = ($FAT1 - 1) * $SectorSize
$Fat2RealIndex = ($FAT2 - 1) * $SectorSize
$FatLastEntryIndex = $FatRealIndex
$Fat2LastEntryindex = $Fat2RealIndex
$Corrupted = $false

Write-Output "Scanning File Allocation Tables..."
while ($FatRealIndex -lt (($FAT2 - 1) * $SectorSize)) {
    $num = $data[$FatRealIndex] + $data[$FatRealIndex + 1] * 256 # x86 is little endian, so smaller value is first
    $num2 = $data[$Fat2RealIndex] + $data[$Fat2RealIndex + 1] * 256 # Number at same index in fat2
    try {
        $UnusedClusters.Remove($num)
    } 
    finally {
        $FatRealIndex += 2
        $Fat2RealIndex += 2
        if ($num -eq 65535) {
            $FatLastEntryIndex = $FatRealIndex
            $Fat2LastEntryindex = $Fat2RealIndex
            $corrupted = $false
        }
    }
}

Write-Output "Scan complete! Generating FAT entry"
[System.Collections.ArrayList]$boot2clusters = @()
while ($boot2binSize -gt 0){
    $boot2clusters.Add($UnusedClusters[0])
    $UnusedClusters.RemoveAt(0)
    $boot2binSize -= 1
}
$boot2binSize = $boot2clusters.Count

# write entry to FATs
foreach($i in $boot2clusters){
    $data[$FatLastEntryIndex] = $i % 256
    $data[$FatLastEntryIndex + 1] = ($i - $i % 256) / 256 # get integer quotient
    $FatLastEntryIndex += 2

    $data[$Fat2LastEntryIndex] = $i % 256
    $data[$Fat2LastEntryIndex + 1] = ($i - $i % 256) / 256 # get integer quotient
    $Fat2LastEntryIndex += 2
}
$data[$FatLastEntryIndex] = 255
$data[$FatLastEntryIndex + 1] = 255
$FatLastEntryIndex += 2
$data[$Fat2LastEntryIndex] = 255
$data[$Fat2LastEntryIndex + 1] = 255
$Fat2LastEntryIndex += 2 # end FAT entry with FF FF

$boot2firstclusterA = $boot2clusters[0]
$boot2firstclusterA = $boot2firstclusterA % 256
$boot2firstclusterB = $boot2clusters[0]
$boot2firstclusterB = [Math]::Floor($boot2firstclusterB / 256)
$boot2binSizeA = $boot2binSize % 256
$boot2binSizeB = [Math]::Floor($boot2binSize / 256)

# Scan directory table for open entry
$Entry = [byte[]](0, 0, # File ID
                  98, 111, 111, 116, 50, 32, 32, 32, # File name, padded with spaces ("boot2   ")
                  115, 121, 98, # file extension (syb for system binary)
                  47, # flags 1 (0010 1111)
                  112, # flags 2 (0111 0000)
                  0, # creation time in 0.01ths of a second (ranges 0-200)
                  0, 0, # time of creation
                  0, 0, # date of creation
                  0, # Owner ID
                  0, 0, # ID of containing directory (root is 0)
                  $boot2firstclusterA, $boot2firstclusterB, # File starting cluster
                  $boot2binSizeA, $boot2binSizeB, # File size (in # of clusters)
                  0, 0, # Last modified time
                  0, 0, # Last modified date
                  50)    # Extraneous value, may be used by softeare (boot2 magic number stored here)

# Find open entry in DT, then write to it and mark it as used
Write-Output "Searching for open entry on DT..."
$dtindex = $DirTable * $SectorSize
$found = $false
while (!$found){
    $flags1 = $data[$dtindex + 0x0D]
    if ((Byte-to-bit -byte $flags1)[0] -eq 1){
        $found = $true
        for ($i = 0; $i -lt 32; $i++){
            $data[$dtindex + $i] = $Entry[$i]
        }
    }
    $dtindex += 32
}

# Write data from boot2 onto the clusters found previously
$index = 0
Write-Output "Writing boot2 data to disk..."
foreach($i in $boot2clusters){
    for($j = ($i-1) * $clustersize * $SectorSize; $j -lt ($i) * $clustersize * $SectorSize; $j++){
        if ($index -gt $boot2bin.Count) {
            $data[$j] = 0
        } else {
            $data[$j] = $boot2bin[$index]
        }
        $index++
    }
}

[System.IO.File]::WriteAllBytes($image, $data)
