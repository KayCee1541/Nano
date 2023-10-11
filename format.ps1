$image = "./disk.img"

# boot sector data
$biospb = 0xeb, 0x3c, 0x90, '1','6','m',' ','i','d','e','n', 0x00, 0x02, 0x04, 0x02, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 
#         Loop code         OEM ident                      sector size  sec/c  reserved  # fats # rde  total sect  mdt   sec/fat