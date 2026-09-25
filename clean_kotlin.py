#!/usr/bin/env python3
"""Clean up Kotlin daemon files and lockfiles."""
import os
import glob
import subprocess

def clean_kotlin():
    kotlin_dir = os.path.expanduser("~/.kotlin")
    daemon_dir = os.path.join(kotlin_dir, "daemon")
    print(f"Kotlin dir: {kotlin_dir}")
    print(f"Daemon dir: {daemon_dir}")

    if os.path.exists(daemon_dir):
        for f in os.listdir(daemon_dir):
            fpath = os.path.join(daemon_dir, f)
            try:
                os.remove(fpath)
                print(f"  Removed: {f}")
            except Exception as e:
                print(f"  Skip {f}: {e}")

    # Kill any running kotlin daemon processes
    result = subprocess.run(["pkill", "-f", "kotlin-daemon"], capture_output=True)
    if result.returncode == 0:
        print("Killed kotlin-daemon processes")
    else:
        print("No kotlin-daemon processes found or pkill failed")

    # Also kill any java processes that might be the kotlin daemon
    result = subprocess.run(
        ["pkill", "-f", "kotlin.*compile"],
        capture_output=True
    )
    if result.returncode == 0:
        print("Killed kotlin compile processes")

    print("\nDone.")

if __name__ == "__main__":
    clean_kotlin()
