#!/usr/bin/env python3
import argparse
import base64
import subprocess
import io
import http.server
import logging
import os
import socketserver
import sys
import tempfile
import textwrap
import threading
import time
from paramiko import DSSKey, Ed25519Key, RSAKey

from paramiko.client import SSHClient
from paramiko.ecdsakey import ECDSAKey
from pexpect import fdpexpect
from periphery import GPIO, Serial

ROCKCHIP_BAUD_RATE = 1500000
TESTS_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "../tests"))

class SerialLogWrapper(io.TextIOWrapper):
    
    def write(self, __s: str) -> int:
        if not hasattr(self, '_written_line') or not self._written_line:
            super().write("SERIAL: ")
            self._written_line = True
        return super().write(__s.replace("\n", "\nSERIAL: "))


class CloudInitHTTPRequestHandler(http.server.BaseHTTPRequestHandler):
    USER_DATA = textwrap.dedent('''\
        #cloud-config
        ssh_authorized_keys:
        - '{ssh_pubkey}'
        # Hack to stop network device that nbd is using from being downed on shutdown
        runcmd:
        - [ "rm", "/run/network/interfaces.d/eth0" ]
    ''')
    META_DATA = textwrap.dedent('''\
        instance-id: iid-local01
        local-hostname: '{board_name}'
    ''')

    def __init__(self, board_name: str, ssh_pubkey: str, request: bytes, client_address: tuple[str, int], server: socketserver.BaseServer) -> None:
        self.board_name = board_name
        self.ssh_pubkey = ssh_pubkey
        super().__init__(request, client_address, server)

    def do_HEAD(self):
        self.headers()

    def do_GET(self):
        response = self._send_headers()
        self.wfile.write(response)

    def _send_headers(self) -> bytes:
        status = http.HTTPStatus.OK

        if self.path == "/user-data":
            content = self.USER_DATA.format(ssh_pubkey=self.ssh_pubkey)
        elif self.path == "/meta-data":
            content = self.META_DATA.format(board_name=self.board_name)
        elif self.path == "/vendor-data":
            content = ""
        else:
            status = http.HTTPStatus.NOT_FOUND
            content = "404 Not Found"

        response = content.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/plain;charset=utf-8")
        self.send_header("Content-Length", str(len(response)))
        self.end_headers()
        return response


def main():
    logging.basicConfig(level=logging.DEBUG, format='%(levelname)-10s %(name)-23s %(message)s')
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--serialport", default="/dev/serial0", help="serial port for board console")
    parser.add_argument("-c", "--gpio-chip", default="/dev/gpiochip0", help="GPIO chip device")
    parser.add_argument("-r", "--reset-gpio", default=17, type=int, help="GPIO number for reset")
    parser.add_argument("-f", "--disable-spi-gpio", default=27, type=int, help="GPIO number for disabling SPI")
    subparsers = parser.add_subparsers()

    u_boot_parser = subparsers.add_parser("u-boot", help="Test u-boot")
    u_boot_parser.set_defaults(mode="u-boot")
    u_boot_parser.add_argument("-s", "--script", default="boot.scr.uimg", help="script filename to load via TFTP")

    linux_parser = subparsers.add_parser("linux", help="Test Linux")
    linux_parser.set_defaults(mode="linux")
    linux_parser.add_argument("-b", "--board", default="rockpro1", help="board name, used for hostname")
    linux_parser.add_argument("board_ip", help="board IP address")
    linux_parser.add_argument("tftp_run_dir", help="subdirectory of TFTP server holding files")
    linux_parser.add_argument("qcow2_image", help="QCOW2 image of Debian")

    args = parser.parse_args()
    if args.mode == "u-boot":
        test_uboot(args.serialport, args.gpio_chip, args.reset_gpio, args.disable_spi_gpio, args.script)
    elif args.mode == "linux":
        test_linux(args.serialport, args.gpio_chip, args.reset_gpio, args.disable_spi_gpio, args.board, args.board_ip, args.tftp_run_dir, args.qcow2_image)


def send_text_with_wait(p, text: str):
    for line in text.splitlines(keepends=True):
        for i in range(0, len(line), 16):
            chunk = line[i:i+16]
            p.send(chunk)
            p.expect(chunk)


def test_linux(ser_port, gpio_chip, reset_gpio_num, disable_spi_gpio_num, board, board_ip, tftp_run_dir, qcow2_image):
    with (
        Serial(ser_port, ROCKCHIP_BAUD_RATE) as ser,
        os.fdopen(sys.stdout.fileno(), "wb", closefd=False) as stdout,
        GPIO(gpio_chip, reset_gpio_num, "out", bias="pull_down") as reset_gpio,
        GPIO(gpio_chip, disable_spi_gpio_num, "out", bias="pull_down") as disable_spi_gpio,
        tempfile.TemporaryDirectory() as tmpdir
    ):
        logger = logging.getLogger('agent')
        p = boot_board_from_spi(ser, stdout, reset_gpio, disable_spi_gpio, logger)

        ssh_key = ECDSAKey.generate()

        nbdserver = "192.168.1.1"  # TODO parameter
        with subprocess.Popen(
            [
                "qemu-nbd",
                "--verbose",
                f"--bind={nbdserver}",
                "--format=qcow2",
                "--snapshot",
                "--aio=io_uring",
                "--export-name=debian",
                "--persistent",
                qcow2_image
            ]
        ) as qemu_nbd:
            metadata_service = http.server.HTTPServer(('', 8000), lambda req, client_addr, server: CloudInitHTTPRequestHandler(
                board_name=board, ssh_pubkey=f"{ssh_key.get_name()} {ssh_key.get_base64()} rock-ci", request=req, client_address=client_addr, server=server
            ))
            metadata_thread = threading.Thread(group=None, target=metadata_service.serve_forever, name="MetadataService", daemon=True)
            metadata_thread.start()
            try:
                p.expect_exact("Hit any key to stop autoboot")
                # Send Ctrl-C equivalent to interrupt
                p.send("\x03")
                p.expect_exact("=>")

                p.send("dhcp\n")
                p.expect_exact("=>")

                p.send(f"setenv nbdserver {nbdserver}\n")
                p.expect_exact("=>")

                p.send('setenv boot_script_dhcp "rock-ci/' + tftp_run_dir + '/bootlinux.scr.uimg"\n')
                p.expect_exact("=>")

                p.send("run bootcmd_dhcp\n")
                login_prompt = False
                got_host_keys = False
                with SSHClient() as ssh_client:
                    while not (login_prompt and got_host_keys):
                        index = p.expect(["-----BEGIN SSH HOST KEY KEYS-----", f"{board} login:"], timeout=100)
                        if index == 0:
                            read_host_keys(p, board_ip, ssh_client)
                            got_host_keys = True
                        elif index == 1:
                            login_prompt = True

                    logger.info("Booted Linux successfully")

                    ssh_client.connect(board_ip, username="debian", pkey=ssh_key, allow_agent=False, look_for_keys=False)
                    ssh_cmd(ssh_client, f'echo \'Acquire::http {{ Proxy "http://{nbdserver}:3142"; }}\' | sudo tee /etc/apt/apt.conf.d/proxy')
                    copy_tests_to_board(logger, ssh_client)
                    ssh_cmd(ssh_client, 'pytest-3')
            except:
                # qemu_nbd will normally not exit until client disconnects
                qemu_nbd.kill()
                raise
            finally:
                metadata_service.shutdown()
                metadata_thread.join()
        
            qemu_nbd.terminate()

def copy_tests_to_board(logger, ssh_client):
    with ssh_client.open_sftp() as sftp_client:
        sftp_client.chdir("/home/debian")
        sftp_client.mkdir("tests")
        sftp_client.chdir("tests")
        for root, dirs, files in os.walk(TESTS_PATH):
            remote_rel_path = os.path.relpath(root, TESTS_PATH)
            remote_path = os.path.normpath("/home/debian/tests/" + remote_rel_path)
            if remote_rel_path != ".":
                sftp_client.chdir(remote_path)
            for d in dirs:
                sftp_client.mkdir(d)
            for f in files:
                local_path = os.path.join(root, f)
                logger.debug("%s -> %s/%s", local_path, remote_path, f)
                sftp_client.put(local_path, f)


def ssh_cmd(ssh_client: SSHClient, cmd: str):
    logger = logging.getLogger("agent.sshcmd")
    stdin, stdout, stderr = ssh_client.exec_command(cmd)
    output = ['', '']
    def reader():
        while line := stderr.readline():
            logger.debug("STDERR: %s", line.strip())
            output[1] += line
    stderr_reader = threading.Thread(target=reader)
    stderr_reader.start()
    while line := stdout.readline():
        logger.debug("STDOUT: %s", line.strip())
        output[0] += line
    stderr_reader.join()
    if returncode := stdout.channel.recv_exit_status() != 0:
        raise subprocess.CalledProcessError(returncode, cmd, output[0], output[1])
    return output[0], output[1]


def read_host_keys(p, board_ip, ssh_client):
    hostkeys = ssh_client.get_host_keys()
    while True:
        line = p.readline().rstrip()
        if line == "-----END SSH HOST KEY KEYS-----":
            break
        elif not line:
            continue
        else:
            # XXX: serial line missing chars may mean this is too error-prone
            key_type, key_base64, *_ = line.split()
            try:
                if key_type == "ssh-rsa":
                    key = RSAKey(data=base64.b64decode(key_base64))
                elif key_type == "ssh-dss":
                    key = DSSKey(data=base64.b64decode(key_base64))
                elif key_type in ECDSAKey.supported_key_format_identifiers():
                    key = ECDSAKey(data=base64.b64decode(key_base64), validate_point=False)
                elif key_type == "ssh-ed25519":
                    key = Ed25519Key(data=base64.b64decode(key_base64))
                else:
                    raise ValueError(f"Unable to handle key of type {key_type}")
                hostkeys.add(hostname=board_ip, keytype=key_type, key=key)
            except Exception as exc:
                print(f"Error parsing host key: {exc}")


def test_uboot(ser_port, gpio_chip, reset_gpio_num, disable_spi_gpio_num, script):
    with (
        Serial(ser_port, ROCKCHIP_BAUD_RATE) as ser,
        os.fdopen(sys.stdout.fileno(), "wb", closefd=False) as stdout,
        GPIO(gpio_chip, reset_gpio_num, "out", bias="pull_down") as reset_gpio,
        GPIO(gpio_chip, disable_spi_gpio_num, "out", bias="pull_down") as disable_spi_gpio
    ):
        logger = logging.getLogger('agent')
        p = boot_board_from_spi(ser, stdout, reset_gpio, disable_spi_gpio, logger)
        p.expect("Hit any key to stop autoboot")
        # Send Ctrl-C equivalent to interrupt
        p.send("\x03")
        p.expect("=> ")
        print("")
        logger.info("At U-boot prompt, disable SPI and DHCP-boot")
        disable_spi_gpio.write(True)
        p.send('setenv boot_script_dhcp "rock-ci/')
        # Wait for command echo
        p.expect('setenv boot_script_dhcp')
        p.send(script)
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


def boot_board_from_spi(ser, stdout, reset_gpio, disable_spi_gpio, logger):
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
    return p


if __name__ == "__main__":
    main()
