remove-item ./image.iso
# the following are an emulation of limine.sh

wsl make -C ./limine
wsl mkdir -p ./iso_root
wsl cp -v ./myos.elf ./limine.cfg ./limine/limine-bios.sys ./limine/limine-bios-cd.bin ./limine/limine-uefi-cd.bin ./iso_root/
wsl mkdir -p ./iso_root/EFI/BOOT
wsl cp -v ./limine/BOOTX64.EFI ./iso_root/EFI/BOOT/
wsl cp -v ./limine/BOOTIA32.EFI ./iso_root/EFI/BOOT/
wsl xorriso -as mkisofs -b limine-bios-cd.bin -no-emul-boot -boot-load-size 4 -boot-info-table --efi-boot limine-uefi-cd.bin -efi-boot-part --efi-boot-image --protective-msdos-label ./iso_root -o image.iso
wsl ./limine/limine bios-install image.iso