#!/usr/bin/python3

import subprocess

# Grabs the most recent commit and tries to apply it to all previous branches.
# The name of the previous branch is in the PREVIOUS_BRANCH file. If this file is empty, there is no previous
# branch, but it's an error if the file is not found.

try:

    result = subprocess.run(['git', 'rev-parse', 'HEAD'], check=True, capture_output=True, text=True)
    commit = result.stdout.strip()
    print(f"Latest commit is {commit}")

    while True:
        with open('PREVIOUS_BRANCH', 'r') as file:
            previous_branch = file.read().strip()
        if not previous_branch:
            print(f"Done");
            exit(0)

        print(f"Backporting {commit} to {previous_branch}")

        subprocess.run(['git', 'checkout', previous_branch], check=True)
        subprocess.run(['git', 'cherry-pick', commit], check=True);
        subprocess.run(['git', 'push'], check=True);

except FileNotFoundError:
    print(f"PREVIOUS_BRANCH not found")
except subprocess.CalledProcessError as e:
    print(f"git failed with exit code {e.returncode}")
    exit(1) 

