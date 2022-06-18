import shlex
import subprocess

def test_arch():
    proc = subprocess.run(shlex.split("uname -m"), capture_output=True, encoding="ascii")
    assert proc.stdout.strip() == "aarch64"
