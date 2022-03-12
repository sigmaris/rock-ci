#!/usr/bin/env python3
import argparse
import pathlib

SCRIPT_DIR = pathlib.Path(__file__).parent

parser = argparse.ArgumentParser()
parser.add_argument("-i", "--idbloader", default="mmc_idbloader.img", help="idbloader filename to load via tftp")
parser.add_argument("-u", "--u-boot", default="u-boot.itb", help="u-boot FIT filename to load via tftp")
parser.add_argument("out_path", help="Location to write the generated script", type=pathlib.Path)
group = parser.add_mutually_exclusive_group(required=True)
group.add_argument("--sdcard", action="store_true", help="Script should erase eMMC and write u-boot to SDCard")
group.add_argument("--emmc", action="store_true", help="Script should write u-boot to eMMC")
args = parser.parse_args()

with open(SCRIPT_DIR / "test.scr.tmpl", "r") as tmpl_file:
    template = tmpl_file.read()
content = template.replace(
    "%idbloader_file%", args.idbloader
).replace(
    "%u_boot_file%", args.u_boot
).replace(
    "%mmc_dev%", "0" if args.emmc else "1"
)
with open(args.out_path, "w") as outfile:
    outfile.write(content)
