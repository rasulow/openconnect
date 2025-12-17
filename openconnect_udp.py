from __future__ import annotations

import argparse
import os
import shlex
import shutil
import signal
import subprocess
import sys
from getpass import getpass
from pathlib import Path
from typing import Optional


def _which_openconnect(explicit: Optional[str]) -> str:
    if explicit:
        p = Path(explicit).expanduser()
        if p.is_file():
            return str(p)
        raise FileNotFoundError(f"openconnect not found at: {p}")
    found = shutil.which("openconnect")
    if not found:
        raise FileNotFoundError("openconnect not found. Install it (e.g. sudo apt-get install openconnect).")
    return found


def _check_root_or_sudo() -> None:
    if os.name != "posix":
        raise RuntimeError("This script targets Linux/Unix (Ubuntu Server).")
    if os.geteuid() != 0:
        raise PermissionError("Must run as root (use sudo) because openconnect needs a tun device.")


def _pid_running(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def _read_pid(pid_file: Path) -> Optional[int]:
    try:
        s = pid_file.read_text(encoding="utf-8").strip()
        if not s:
            return None
        return int(s)
    except Exception:
        return None


def _write_pid(pid_file: Path, pid: int) -> None:
    pid_file.parent.mkdir(parents=True, exist_ok=True)
    pid_file.write_text(str(pid), encoding="utf-8")


def _remove_pid(pid_file: Path) -> None:
    try:
        pid_file.unlink(missing_ok=True)  # Python 3.8+
    except Exception:
        pass


def connect(
    server: str,
    username: str,
    password: str,
    authgroup: Optional[str],
    interface: str,
    pid_file: Path,
    log_file: Optional[Path],
    openconnect_path: str,
    servercert: Optional[str],
    no_dtls: bool,
    background: bool,
    extra_args: list[str],
) -> int:
    args = [
        openconnect_path,
        "--protocol=anyconnect",
        "--user",
        username,
        "--interface",
        interface,
        "--passwd-on-stdin",
        "--pid-file",
        str(pid_file),
        server,
    ]
    if authgroup:
        args.extend(["--authgroup", authgroup])
    if servercert:
        args.extend(["--servercert", servercert])
    if no_dtls:
        args.append("--no-dtls")
    if background:
        args.append("--background")
    if log_file:
        args.extend(["--log", str(log_file)])
    args.extend(extra_args)

    proc = subprocess.run(
        args,
        input=password + "\n",
        text=True,
    )
    return proc.returncode


def disconnect(pid_file: Path, timeout_s: int = 10) -> int:
    pid = _read_pid(pid_file)
    if not pid:
        print(f"No PID found in {pid_file}. Are you connected?")
        return 1
    if not _pid_running(pid):
        print(f"PID {pid} is not running. Cleaning PID file.")
        _remove_pid(pid_file)
        return 0

    os.kill(pid, signal.SIGINT)
    for _ in range(timeout_s * 10):
        if not _pid_running(pid):
            _remove_pid(pid_file)
            return 0
        try:
            import time

            time.sleep(0.1)
        except KeyboardInterrupt:
            break

    os.kill(pid, signal.SIGTERM)
    return 0


def status(pid_file: Path) -> int:
    pid = _read_pid(pid_file)
    if not pid:
        print("DISCONNECTED")
        return 1
    if _pid_running(pid):
        print(f"CONNECTED pid={pid}")
        return 0
    print(f"STALE pid_file (pid={pid} not running)")
    return 2


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Ubuntu/OpenConnect helper for AnyConnect-compatible VPN (DTLS/UDP).")
    parser.add_argument("--openconnect-path", help="Path to openconnect binary (optional).")
    parser.add_argument(
        "--pid-file",
        default="/run/openconnect_anyconnect.pid",
        help="PID file to manage connect/disconnect/status.",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_conn = sub.add_parser("connect", help="Connect using openconnect (AnyConnect protocol).")
    p_conn.add_argument("server", help="VPN server hostname or URL (e.g. vpn.company.com).")
    p_conn.add_argument("--username", required=False, help="VPN username.")
    p_conn.add_argument("--authgroup", help="Auth group/profile if your server asks for it.")
    p_conn.add_argument("--interface", default="tun0", help="TUN interface name (default: tun0).")
    p_conn.add_argument("--log-file", help="Write openconnect logs to this file.")
    p_conn.add_argument(
        "--servercert",
        help='Pin server certificate (recommended). Example: "pin-sha256:BASE64..."',
    )
    p_conn.add_argument("--no-dtls", action="store_true", help="Disable DTLS/UDP (force TLS/TCP).")
    p_conn.add_argument(
        "--foreground",
        action="store_true",
        help="Run in foreground (default runs in background if supported).",
    )
    p_conn.add_argument(
        "--extra",
        default="",
        help='Extra openconnect args (string), e.g. \'--reconnect-timeout 10 --dump-http-traffic\'.',
    )

    p_disc = sub.add_parser("disconnect", help="Disconnect using PID file.")
    p_disc.add_argument("--timeout", type=int, default=10, help="Seconds to wait before SIGTERM.")

    sub.add_parser("status", help="Show basic connection status (based on PID file).")

    args = parser.parse_args(argv)
    openconnect_path = _which_openconnect(args.openconnect_path)
    pid_file = Path(args.pid_file)

    if args.cmd == "connect":
        _check_root_or_sudo()

        username = args.username or input("Username: ").strip()
        password = getpass("Password: ")

        extra_args = shlex.split(args.extra) if args.extra else []
        log_file = Path(args.log_file) if args.log_file else None
        background = not args.foreground

        return connect(
            server=args.server,
            username=username,
            password=password,
            authgroup=args.authgroup,
            interface=args.interface,
            pid_file=pid_file,
            log_file=log_file,
            openconnect_path=openconnect_path,
            servercert=args.servercert,
            no_dtls=args.no_dtls,
            background=background,
            extra_args=extra_args,
        )

    if args.cmd == "disconnect":
        _check_root_or_sudo()
        return disconnect(pid_file, timeout_s=args.timeout)

    if args.cmd == "status":
        return status(pid_file)

    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))


