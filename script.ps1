wsl nasm -f bin ./src/boot1.asm -o ./build/boot1.bin

wsl dd if=./build/boot1.bin of=./disk.img conv=notrunc bs=446 count=1
wsl dd if=./build/boot1.bin of=./disk.img conv=notrunc bs=1 count=2 skip=510 seek=510