wsl dd if=/dev/zero of=disk.img bs=512 count=65535
./buildscript.ps1

$Disk = Get-Content -Path ./disk.img -AsByteStream -Raw
$BootCode = Get-Content -Path ./build/boot.bin -AsByteStream -Raw

$Files = Get-ChildItem -Path "./build" -Recurse -Name -Exclude "boot.bin"
$NewArray = @()
foreach($i in $Files) {
    $NewArray += "build\" + $i
}
$Files = $NewArray
$NewArray = @()
foreach($i in $Folders) {
    $NewArray += "build\" + $i
}

$Bytes_Sector = $BootCode[11] + $BootCode[12] * 256
$Sectors_Cluster = $BootCode[13]
$Reserved_Sector = $BootCode[14] + $BootCode[15] * 256
$Number_Fats = $BootCode[16]
$Total_Sectors = 65535
$Sectors_Fat = $BootCode[22] + $BootCode[23] * 256

$ClusterZero = $Reserved_Sector + $Number_Fats * $Sectors_Fat - ($Sectors_Cluster)

$Directory_Entry = [Byte[]] (   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, # 8.3 file name
                                0, # Attributes
                                0, # Reserved
                                0, # Creation time in hundredths of a second
                                0, 0, # Creation time (Hour: 5 bits, Minutes: 6 bits, Seconds: 5 bits)
                                0, 0, # Creation date (Year: 7 bits, Month: 4 bits, Day: 5 bits)
                                0, 0, # Last accessed date
                                0, 0, # High 16 bits of this entry's first cluster number. Unused by NANO
                                0, 0, # Last modification time
                                0, 0, # Last modification date
                                0, 0, # Low 16 bits of this entry's first cluster number.
                                0, 0, 0, 0 # Size of file in bytes
)

$UsedClusters = @(0, 1, 0xfff7, 0xfff8, 0xfff9, 0xfffa, 0xfffb, 0xfffc, 0xfffd, 0xfffe, 0xffff)
$MaxClusterNumber = ($Disk.Length - ($RootDirectory * $Bytes_Sector - $Bytes_Sector * $Sectors_Cluster)) / ($Bytes_Sector * $Sectors_Cluster)
$FileClusters = @{"build" = 1}

# ADD BOOT CODE
for ($i = 0; $i -lt $Bytes_Sector; $i++) {
    $Disk[$i] = $BootCode[$i]
}

# GENERATE FILE ENTRIES
foreach ($i in $Files) {
    # Generate file data
    $Path = $i.Substring(0, $i.lastIndexOf('\'))
    $HostDirectoryClusterNum = $FileClusters[$Path]
    $FileData = Get-Content -Path (".\" + $i) -AsByteStream -Raw
    $FileSize = $FileData.Length
    $Name = $i.Split('\')[-1]
    $Ext = $Name.Split('.')[1]
    $Name = $Name.Split('.')[0]
    if ($Name.Length -lt 8) {
        $Name += ' '*(8 - $Name.Length)
    }
    if ($Ext.Length -lt 3) {
        $Ext += ' '*(3 - $Ext.Length)
    }
    $Name += $Ext
    For ($j = 0; $j -lt 11; $j++) {
        $Directory_Entry[$j] = $Name[$j]
    }

    # Write file size to directory entry
    $Directory_Entry[11] = (Get-ItemProperty -Path (".\" + $i)).attributes.Value__
    if ($Ext.ToLower() -eq "sys") {
        $Directory_Entry[11] = $Directory_Entry[11] -bor 0x04 -bor 0x40 # bit 40 will represent the file being executable
    }
    if ($Ext.ToLower() -eq "bin") {
        $Directory_Entry[11] = $Directory_Entry[11] -bor 0x40 # bit 40 will represent the file being executable
    }
    for ($j = 0; $j -lt 4; $j++) {
        $Directory_Entry[28 + $j] = [byte] ($FileSize -shr (8*$j) -band 0xFF)
    }
    $ClustersChain = @()

    # Get starting cluster for file
    for ($j = 0; $j -lt $MaxClusterNumber; $j++) {
        if (!($UsedClusters -contains $j)) {
            $FileClusters[$i] = $j
            $Directory_Entry[26] = [byte] ($j -band 0xff)
            $Directory_Entry[27] = [byte] (($j -shr 8) -band 0xff)
            $ClustersChain += $j
            $UsedClusters += $j
            break
        }
    }
    $FileClustersNum = [Math]::Ceiling($FileSize / ($Bytes_Sector * $Sectors_Cluster))

    # Get rest of clusters for file
    For ($j = 0; ($j -lt $MaxClusterNumber) -and ($FileClustersNum -ne $ClustersChain.Length); $j++) {
        if (!($UsedClusters -contains $j)) {
            $ClustersChain += $j
            $UsedClusters += $j
        }
    }

    # Write directory entry
    for ($j = 0; $j -lt ($Bytes_Sector * $Sectors_Cluster); $j += 32) {
        if ($Disk[($ClusterZero + $HostDirectoryClusterNum * $Sectors_Cluster) * $Bytes_Sector + $j] -eq 0) {
            for ($k = 0; $k -lt 32; $k++) {
                $Disk[($ClusterZero + $HostDirectoryClusterNum * $Sectors_Cluster) * $Bytes_Sector + $j + $k] = $Directory_Entry[$k]
            }
        }
    }

    # Write file to disk clusters
    $FileDataPointer = 0;
    $FileData += [byte[]](0) * (($FileClustersNum * $Bytes_Sector * $Sectors_Cluster) - $FileSize)
    foreach($j in $ClustersChain) {
        for ($k = 0; $k -lt ($Bytes_Sector * $Sectors_Cluster); $k++) {
            $Disk[($ClusterZero + $j * $Sectors_Cluster) * $Bytes_Sector + $k] = $FileData[$FileDataPointer]
            $FileDataPointer++
        }
    }

    $ClustersChain += 0xffff # end-of-chain identifier

    # Write to FAT
    for ($j = ($Reserved_Sector * $Bytes_Sector); $j -lt (($Sectors_Fat + $Reserved_Sector) * $Bytes_Sector); $j += 2) {
        $Checksum = 0;
        for ($k = 0; $k -lt ($ClustersChain.Length * 2); $k++) {
            $Checksum += $Disk[$j]
        }
        if ($Checksum -eq 0) {
            for ($k = 0; $k -lt $ClustersChain.Length; $k++) {
                for ($l = 0; $l -lt $Number_Fats; $l++) {
                    $Disk[$j + ($Sectors_Fat * $Bytes_Sector * $l) + 2*$k] = ($ClustersChain[$k] -band 0xff)
                    $Disk[$j + ($Sectors_Fat * $Bytes_Sector * $l) + 2*$k + 1] = (($ClustersChain[$k] -shr 8) -band 0xff)
                }
            }
            break
        }
    }
}

[IO.File]::WriteAllBytes("./disk.img", $Disk)