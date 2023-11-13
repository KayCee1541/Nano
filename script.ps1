# wsl dd if=/dev/zero of=./disk.img bs=1048576 count=1
wsl nasm -f bin ./src/boot1.asm -o ./build/boot1.bin
wsl nasm -f bin ./src/boot2.asm -o ./build/boot2.bin

# wsl dd if=./build/boot1.bin of=./disk.img conv=notrunc bs=512 count=2