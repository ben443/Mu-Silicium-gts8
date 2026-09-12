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
BOOTSHIM_IMAGE_TMP="${BOOTSHIM_IMAGE}.tmp"
BOOTSHIM_IMAGE_GZ_TMP="${BOOTSHIM_IMAGE_GZ}.tmp"
BOOTPAYLOAD_TMP="${BOOTPAYLOAD}.tmp"
BOOT_IMAGE="boot.img"
BOOT_IMAGE_TMP="${BOOT_IMAGE}.tmp"
BOOT_TAR="Mu-gts8.tar"
BOOT_TAR_TMP="${BOOT_TAR}.tmp"
BOOT_IMAGE_OUTPUT="Mu-gts8.img"
DTB_IMAGE="${REPO_ROOT}/Resources/DTBs/gts8.dtb"
RAMDISK_IMAGE="${REPO_ROOT}/Resources/ramdisk"

[ -f "${SCRIPT_DIR}/mkbootimg.py" ] || _error "\nmkbootimg.py not found: ${SCRIPT_DIR}/mkbootimg.py\n"
[ -f "${REPO_ROOT}/BootShim/BootShim.bin" ] || _error "\nBootShim binary not found: ${REPO_ROOT}/BootShim/BootShim.bin\n"
[ -d "${BUILD_DIR}" ] || _error "\ngts8 build output directory not found: ${BUILD_DIR}\n"
[ -f "${FD_IMAGE}" ] || _error "\nUEFI image not found for gts8: ${FD_IMAGE}\n"
[ -f "${DTB_IMAGE}" ] || _error "\ngts8 DTB not found: ${DTB_IMAGE}\n"
[ -f "${RAMDISK_IMAGE}" ] || _error "\nRamdisk not found: ${RAMDISK_IMAGE}\n"

# Build an Android kernel that is actually UEFI disguised as the Kernel
rm -f "${BOOTSHIM_IMAGE_TMP}" "${BOOTSHIM_IMAGE_GZ_TMP}" "${BOOTPAYLOAD_TMP}"
cat "${REPO_ROOT}/BootShim/BootShim.bin" "${FD_IMAGE}" > "${BOOTSHIM_IMAGE_TMP}" && mv -f "${BOOTSHIM_IMAGE_TMP}" "${BOOTSHIM_IMAGE}" || { rm -f "${BOOTSHIM_IMAGE_TMP}"; _error "\nFailed to append BootShim to the gts8 UEFI image.\n"; }
gzip -c < "${BOOTSHIM_IMAGE}" > "${BOOTSHIM_IMAGE_GZ_TMP}" && mv -f "${BOOTSHIM_IMAGE_GZ_TMP}" "${BOOTSHIM_IMAGE_GZ}" || { rm -f "${BOOTSHIM_IMAGE_GZ_TMP}"; _error "\nFailed to compress the gts8 BootShim image.\n"; }
cat "${BOOTSHIM_IMAGE_GZ}" "${DTB_IMAGE}" > "${BOOTPAYLOAD_TMP}" && mv -f "${BOOTPAYLOAD_TMP}" "${BOOTPAYLOAD}" || { rm -f "${BOOTPAYLOAD_TMP}"; _error "\nFailed to build the gts8 bootpayload.\n"; }

# Create bootable Android boot.img
rm -f "${BOOT_IMAGE_TMP}" "${BOOT_TAR_TMP}"
python3 "${SCRIPT_DIR}/mkbootimg.py" \
  --kernel "${BOOTPAYLOAD}" \
  --ramdisk "${RAMDISK_IMAGE}" \
  --kernel_offset 0x00000000 \
  --ramdisk_offset 0x00000000 \
  --tags_offset 0x00000000 \
  --os_version 13.0.0 \
  --os_patch_level "$(date '+%Y-%m')" \
  --header_version 1 \
  -o "${BOOT_IMAGE_TMP}" \
  || _error "\nFailed to create the gts8 Android boot image.\n"
mv -f "${BOOT_IMAGE_TMP}" "${BOOT_IMAGE}" || { rm -f "${BOOT_IMAGE_TMP}"; _error "\nFailed to finalize the gts8 Android boot image.\n"; }

# Compress Boot Image in a tar File for Odin/heimdall Flash
tar -c -f "${BOOT_TAR_TMP}" "${BOOT_IMAGE}" || { rm -f "${BOOT_TAR_TMP}"; _error "\nFailed to create the gts8 Odin tarball.\n"; }
mv -f "${BOOT_TAR_TMP}" "${BOOT_TAR}" || { rm -f "${BOOT_TAR_TMP}"; _error "\nFailed to finalize the gts8 Odin tarball.\n"; }
mv -f "${BOOT_IMAGE}" "${BOOT_IMAGE_OUTPUT}" || _error "\nFailed to rename the gts8 boot image output.\n"
