# Yes, this is ChatGPT generated. No, I dont care. I just want to program an OS, I dont want to have to deal with writing a custom fat16 floppy disk formatting routine.

#!/bin/bash
set -euo pipefail

# === CONFIGURATION ===
IMAGE="disk.img"
SIZE_KB=360
SECTORS=$((360 * 1024 / 512))  # 720 sectors
MOUNTPOINT="./mnt"
BUILD_DIR="./build"
BOOTBIN="OSBOOT-.bin"
BPB_OFFSET=11       # 0x0B
BPB_LENGTH=51       # 0x3D - 0x0B + 1 = 51

# === STEP 1: CREATE EMPTY IMAGE ===
echo "[*] Creating empty $SIZE_KB KB image..."
dd if=/dev/zero of="$IMAGE" bs=512 count=$SECTORS

# === STEP 2: FORMAT IMAGE AS FAT16 SUPERFLOPPY ===
echo "[*] Formatting image with FAT16 (superfloppy)..."
mkfs.fat -F 12 -S 512 -s 1 -h 0 -r 224 "$IMAGE"

# === STEP 3: COPY FILES USING MTOOLS (NO MOUNTING) ===
echo "[*] Copying files (excluding $BOOTBIN) with mcopy..."

# Create temporary MTOOLS configuration
MTOOLS_CONF="$(mktemp)"
echo "drive i: file=\"$(realpath $IMAGE)\"" > "$MTOOLS_CONF"

# Copy files from BUILD_DIR to root of image, skipping BOOTBIN
for file in "$BUILD_DIR"/*; do
    fname=$(basename "$file")
    if [ "$fname" != "$BOOTBIN" ]; then
        echo "  -> Copying $fname"
        MTOOLSRC="$MTOOLS_CONF" mcopy -i "$IMAGE" "$file" ::/
    fi
done

# Remove temporary config
rm -f "$MTOOLS_CONF"

# === STEP 4: PATCH BOOT SECTOR ===
echo "[*] Injecting $BOOTBIN into boot sector, preserving BPB..."

if [ ! -f "$BUILD_DIR/$BOOTBIN" ]; then
    echo "[!] $BOOTBIN not found in $BUILD_DIR"
    exit 1
fi

# Backup BPB from generated image
dd if="$IMAGE" of=bpb.bin bs=1 skip=$BPB_OFFSET count=$BPB_LENGTH status=none

# Copy OSBOOT-.bin into memory
cp "$BUILD_DIR/$BOOTBIN" bootsector.bin

# Patch bootsector.bin: overwrite BPB with preserved one
dd if=bpb.bin of=bootsector.bin bs=1 seek=$BPB_OFFSET count=$BPB_LENGTH conv=notrunc status=none

# Write patched bootsector back to image
dd if=bootsector.bin of="$IMAGE" bs=512 count=1 conv=notrunc status=none

# Cleanup temp files
rm -f bpb.bin bootsector.bin

echo "[✓] Disk image $IMAGE created and boot sector patched."