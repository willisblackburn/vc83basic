#!/usr/bin/python3

import sys

# Accepts source file names on the command line and outputs lines with comments not aligned to tabs.

def check_semicolon_position(line):
    semicolon_index = line.find('; ')
    return semicolon_index != -1 and ((semicolon_index > 0 and semicolon_index < 40) or semicolon_index % 4 != 0)

for filename in sys.argv[1:]:
    with open(filename, 'r') as f:
        for n, line in enumerate(f):
            if check_semicolon_position(line):
                print(f"{filename}:{n + 1}: {line}", end='')

