#!/bin/bash

if [ "$(id -u)" -ne "0" ]; then
  echo "This script requires root."
  exit 1
fi

set -ex

data="$(curl --silent "https://raw.githubusercontent.com/XiaomiFirmwareUpdater/miui-updates-tracker/master/data/latest.yml")"
url="$(echo "$data" | grep "beryllium_global_images_V" | cut -d " " -f 4)"
version="$(echo "$url" | cut -d "/" -f 4)"

file="rom-$version.tar.gz"
if [ ! -f "$file" ]; then
  wget "$url" -O "$file"
  rm -rf rom
  mkdir -p rom
  tar -xzf "$file" -C rom --strip 1
fi

function cleanup() {
  umount rom/{bluetooth,modem,dsp,vendor} || true
}
trap cleanup EXIT

if file rom/images/vendor.img | grep -q "sparse"; then
  cp rom/images/vendor.img /tmp/vendor.img
  simg2img /tmp/vendor.img rom/images/vendor.img
  rm /tmp/vendor.img
fi

for image in "bluetooth" "modem" "dsp" "vendor"; do
  mkdir -p rom/$image
  mount -o loop rom/images/$image.img rom/$image
done

dir="build/lib/firmware"
rm -rf build
mkdir -p $dir/ath10k/WCN3990/hw1.0 $dir/qca $dir/qcom/sdm845/beryllium
cp rom/bluetooth/image/{crbtfw21.tlv,crnv21.bin} $dir/qca
cp rom/modem/image/{adspr,adspua,cdspr,modemr,modemuw}.jsn $dir/qcom/sdm845/beryllium
cp rom/modem/image/{mba,wlanmdsp}.mbn $dir/qcom/sdm845/beryllium
cp rom/vendor/firmware/a630_{gmu.bin,sqe.fw} $dir/qcom
cp rom/vendor/firmware/tas2559_uCDSP.bin $dir
pil-squasher $dir/ipa_fws.mbn rom/vendor/firmware/ipa_fws.mdt
pil-squasher $dir/qcom/sdm845/beryllium/a630_zap.mbn rom/vendor/firmware/a630_zap.mdt
pil-squasher $dir/qcom/sdm845/beryllium/adsp.mbn rom/modem/image/adsp.mdt
pil-squasher $dir/qcom/sdm845/beryllium/cdsp.mbn rom/modem/image/cdsp.mdt
pil-squasher $dir/qcom/sdm845/beryllium/modem.mbn rom/modem/image/modem.mdt

wget https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/ath10k/WCN3990/hw1.0/firmware-5.bin -O $dir/ath10k/WCN3990/hw1.0/firmware-5.bin
wget https://github.com/kvalo/ath10k-firmware/raw/master/WCN3990/hw1.0/board-2.bin -O $dir/ath10k/WCN3990/hw1.0/board-2.bin

rm firmware*.tar.gz -rf
# Force time so we always get the same hash for the archive
tar -czf firmware.tar.gz -C build lib --mtime='1970-01-01'

hash="$(sha256sum firmware.tar.gz | cut -d " " -f 1)"
latest="$(curl --silent "https://api.github.com/repos/arch-beryllium/firmware/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')"

if [ "$latest" != "$hash" ]; then
  echo "Creating a new release"
  gh release create "$hash" firmware.tar.gz -t "$hash" -n ""
else
  echo "Latest firmware already released"
fi
