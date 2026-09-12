#!/bin/bash

if ! declare -F _error > /dev/null; then
  function _error(){ echo -e "\033[1;31m${@}\033[0m" >&2; exit 1; }
fi

case "${TARGET_BUILD_MODE^^}" in
  DEBUG) TARGET_BUILD_MODE=DEBUG;;
  *) TARGET_BUILD_MODE=RELEASE;;
esac

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
BUILD_DIR="${REPO_ROOT}/Build/gts8Pkg/${TARGET_BUILD_MODE}_CLANGPDB/FV"
FD_IMAGE="${BUILD_DIR}/GTS8_UEFI.fd"
BOOTSHIM_IMAGE="${FD_IMAGE}-bootshim"
BOOTSHIM_IMAGE_GZ="${BOOTSHIM_IMAGE}.gz"
BOOTPAYLOAD="${BUILD_DIR}/bootpayload.bin"
DTB_IMAGE="${REPO_ROOT}/Resources/DTBs/gts8.dtb"
RAMDISK_IMAGE="${REPO_ROOT}/Resources/ramdisk"

[ -f "${SCRIPT_DIR}/mkbootimg.py" ] || _error "\nmkbootimg.py not found: ${SCRIPT_DIR}/mkbootimg.py\n"
[ -f "${REPO_ROOT}/BootShim/BootShim.bin" ] || _error "\nBootShim binary not found: ${REPO_ROOT}/BootShim/BootShim.bin\n"
[ -f "${FD_IMAGE}" ] || _error "\nUEFI image not found for gts8: ${FD_IMAGE}\n"
[ -f "${DTB_IMAGE}" ] || _error "\ngts8 DTB not found: ${DTB_IMAGE}\n"
[ -f "${RAMDISK_IMAGE}" ] || _error "\nRamdisk not found: ${RAMDISK_IMAGE}\n"

# Build an Android kernel that is actually UEFI disguised as the Kernel
cat "${REPO_ROOT}/BootShim/BootShim.bin" "${FD_IMAGE}" > "${BOOTSHIM_IMAGE}"||exit 1
gzip -c < "${BOOTSHIM_IMAGE}" > "${BOOTSHIM_IMAGE_GZ}"||exit 1
cat "${BOOTSHIM_IMAGE_GZ}" "${DTB_IMAGE}" > "${BOOTPAYLOAD}"||exit 1

# Create bootable Android boot.img
python3 "${SCRIPT_DIR}/mkbootimg.py" \
  --kernel "${BOOTPAYLOAD}" \
  --ramdisk "${RAMDISK_IMAGE}" \
  --kernel_offset 0x00000000 \
  --ramdisk_offset 0x00000000 \
  --tags_offset 0x00000000 \
  --os_version 13.0.0 \
  --os_patch_level "$(date '+%Y-%m')" \
  --header_version 1 \
  -o boot.img \
  ||_error "\nFailed to create Android Boot Image!\n"

# Compress Boot Image in a tar File for Odin/heimdall Flash
tar -c boot.img -f Mu-gts8.tar||exit 1
mv boot.img Mu-gts8.img||exit 1
