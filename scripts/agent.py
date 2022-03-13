#!/usr/bin/env python3
import argparse
import io
import logging
import os
import sys
import time

from pexpect import fdpexpect
from periphery import GPIO, Serial

class SerialLogWrapper(io.TextIOWrapper):
    
    def write(self, __s: str) -> int:
        if not hasattr(self, '_written_line') or not self._written_line:
            super().write("SERIAL: ")
            self._written_line = True
        return super().write(__s.replace("\n", "\nSERIAL: "))

parser = argparse.ArgumentParser()
parser.add_argument("-s", "--script", default="boot.scr.uimg", help="script filename to load via TFTP")
args = parser.parse_args()

logging.basicConfig(level=logging.DEBUG)

with (
    Serial('/dev/serial0', 1500000) as ser,
    os.fdopen(sys.stdout.fileno(), "wb", closefd=False) as stdout,
    GPIO("/dev/gpiochip0", 17, "out", bias="pull_down") as reset_gpio,
    GPIO("/dev/gpiochip0", 27, "out", bias="pull_down") as disable_spi_gpio
):
    logger = logging.getLogger('agent')
    logger.info("Enable SPI...")
    disable_spi_gpio.write(False)
    logger.info("Resetting...")
    reset_gpio.write(True)
    reset_at = time.monotonic_ns()
    # Clear any old input from serial:
    ser.read(ser.input_waiting(), timeout=1)
    p = fdpexpect.fdspawn(ser.fd, encoding='utf-8', codec_errors='replace', logfile=SerialLogWrapper(stdout))
    now = time.monotonic_ns()
    elapsed = now - reset_at
    # assert reset for at least 5us
    if elapsed < 5000:
        time.sleep((5000 - elapsed) * 1e-9)
    reset_gpio.write(False)
    logger.info("Reset.")
    p.expect("Hit any key to stop autoboot")
    # Send Ctrl-C equivalent to interrupt
    p.send("\x03")
    p.expect("=> ")
    print("")
    logger.info("At U-boot prompt, disable SPI and DHCP-boot")
    disable_spi_gpio.write(True)
    p.send('setexpr dashaddr gsub : - ${ethaddr}\n')
    p.expect("=> ")
    p.send('setenv boot_script_dhcp "${dashaddr}/')
    # Wait for command echo
    p.expect('setenv boot_script_dhcp')
    p.send(args.script)
    p.send('"\n')
    p.expect("=> ")
    p.send("run bootcmd_dhcp\n")
    # Test script should run:
    p.expect("SELECT_MMC")
    p.expect("WRITE_IDBLOADER")
    p.expect("WRITE_UBOOT")
    p.expect("DONE_RESET")
    # Now, new install should boot after reset...
    p.expect("Hit any key to stop autoboot")
    p.send("\x03")
    p.expect("=> ")
    print("")
    logger.info("New version booted to U-boot prompt, enable SPI")
    disable_spi_gpio.write(False)
