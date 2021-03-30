# firmware

A script to extract the latest firmware files.

## Usage

Install https://github.com/andersson/pil-squasher and `simg2img`, then:

```bash
git submodule init
git submodule update
./build.sh
```

The result will be `firmware.tar.gz`.

## Notes

The script for creating the `board-2.bin` file comes from https://github.com/jhugo/linux/tree/5.5rc2_wifi