#!/usr/bin/env python3
import os, time, subprocess

KEY_DIR = os.getenv("KEY_DIR", "/root/deklan")
REQUIRED = ["swarm.pem", "userapikey.json", "userData.json"]

def check():
    missing = []
    for f in REQUIRED:
        if not os.path.isfile(os.path.join(KEY_DIR, f)):
            missing.append(f)
    return missing

if __name__ == "__main__":
    miss = check()
    if miss:
        print("Missing starter files:", miss)
        # Do nothing else; bot will instruct user.
    else:
        print("All starters present.")
    # Optionally: loop and monitor basic service
    # while True:
    #     # add monitoring logic or exit
    #     time.sleep(60)
