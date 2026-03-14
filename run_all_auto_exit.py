#!/usr/bin/env python3
import argparse
import os
import pty
import re
import select
import subprocess
import sys
from pathlib import Path


PROMPT_PATTERNS = [
    re.compile(r"legacy_genus:/> ?$"),
    re.compile(r"innovus\s+\d+> ?$"),
]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run source run_all.sh and auto-send 'exit' on specific tool prompts."
    )
    parser.add_argument(
        "run_dir",
        nargs="?",
        default=".",
        help="Directory containing run_all.sh (default: current directory)",
    )
    parser.add_argument(
        "--log",
        default=None,
        help="Log file path (default: <run_dir>/run_all_auto_exit.log)",
    )
    args = parser.parse_args()

    run_dir = Path(args.run_dir).resolve()
    if not run_dir.is_dir():
        print(f"Error: run directory does not exist: {run_dir}", file=sys.stderr)
        return 1
    run_all = run_dir / "run_all.sh"
    if not run_all.exists():
        print(f"Error: run_all.sh not found in: {run_dir}", file=sys.stderr)
        return 1

    log_path = Path(args.log).resolve() if args.log else (run_dir / "run_all_auto_exit.log")
    log_path.parent.mkdir(parents=True, exist_ok=True)

    print(f"Run directory: {run_dir}")
    print(f"Log file: {log_path}")
    print("Starting: source run_all.sh (auto-exit enabled)")

    master_fd, slave_fd = pty.openpty()
    cmd = f'cd "{run_dir}" && source run_all.sh'
    proc = subprocess.Popen(
        ["/bin/bash", "-lc", cmd],
        stdin=slave_fd,
        stdout=slave_fd,
        stderr=slave_fd,
        close_fds=True,
    )
    os.close(slave_fd)

    buffer = ""
    with open(log_path, "ab") as logf:
        while True:
            if proc.poll() is not None:
                # Drain remaining data
                while True:
                    r, _, _ = select.select([master_fd], [], [], 0)
                    if not r:
                        break
                    data = os.read(master_fd, 4096)
                    if not data:
                        break
                    os.write(sys.stdout.fileno(), data)
                    logf.write(data)
                break

            r, _, _ = select.select([master_fd], [], [], 0.2)
            if not r:
                continue

            data = os.read(master_fd, 4096)
            if not data:
                break

            os.write(sys.stdout.fileno(), data)
            logf.write(data)
            logf.flush()

            try:
                text = data.decode("utf-8", errors="ignore")
            except Exception:
                text = ""
            buffer += text
            if len(buffer) > 3000:
                buffer = buffer[-3000:]

            lines = buffer.splitlines()
            last_line = lines[-1] if lines else buffer
            for pat in PROMPT_PATTERNS:
                if pat.search(last_line):
                    msg = f"\n[auto-exit] detected prompt '{last_line.strip()}' -> sending exit\n"
                    os.write(sys.stdout.fileno(), msg.encode())
                    logf.write(msg.encode())
                    os.write(master_fd, b"exit\n")
                    break

    os.close(master_fd)
    code = proc.wait()
    if code != 0:
        print(f"[auto-exit] run_all.sh exited with code {code}", file=sys.stderr)
        print(f"Log file: {log_path}", file=sys.stderr)
    else:
        print("Completed successfully.")
    return code


if __name__ == "__main__":
    sys.exit(main())
