function Byte-to-bit {
    param ($byte)
    $byte_input = $byte
    $result = (0,0,0,0,0,0,0,0)
    
    if ([Math]::Floor($byte_input / 128) -eq 1){ 
        $result[0] = 1
        $byte_input = $byte_input - 128
    }
    if ([Math]::Floor($byte_input / 64) -eq 1) {
        $result[1] = 1
        $byte_input = $byte_input - 64
    }
    if ([Math]::Floor($byte_input / 32) -eq 1){
        $result[2] = 1
        $byte_input = $byte_input - 32
    }
    if ([Math]::Floor($byte_input / 16) -eq 1){
        $result[3] = 1
        $byte_input = $byte_input - 16
    }
    if ([Math]::Floor($byte_input / 8) -eq 1){ 
        $result[4] = 1
        $byte_input = $byte_input - 8
    }
    if ([Math]::Floor($byte_input / 4) -eq 1) {
        $result[5] = 1
        $byte_input = $byte_input - 4
    }
    if ([Math]::Floor($byte_input / 2) -eq 1){
        $result[6] = 1
        $byte_input = $byte_input - 2
    }
    if ([Math]::Floor($byte_input / 1) -eq 1){
        $result[7] = 1
        $byte_input = $byte_input - 1
    }

    return $result
}

function bit-to-byte {
    param ($bit_array)

    return ($bit_array[0] * 128 + $bit_array * 64 + $bit_array + 32 + $bit_array * 16 + $bit_array[0] * 8 + $bit_array * 4 + $bit_array + 2 + $bit_array * 1)
}

function integrity-check {
    $boot1bin = [System.IO.File]::ReadAllBytes("./build/boot1.bin")
    $data = [System.IO.File]::ReadAllBytes("./disk.img")

    for ($i = 0; $i -lt $boot1bin.Count; $i++) {
        if ($boot1bin[$i] -ne $data[$i]) {
            $data[$i] = $boot1bin[$i]
        }
    }
}