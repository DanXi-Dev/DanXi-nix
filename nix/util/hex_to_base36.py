#!/usr/bin/env python3

import sys


def base36_encode(num: int) -> str:
    if num == 0:
        return "0"
    mod_arr = []
    while num > 0:
        num, mod = divmod(num, 36)
        mod_arr.append(mod)

    alphabet = "0123456789abcdefghijklmnopqrstuvwxyz"
    return "".join(alphabet[mod] for mod in mod_arr[::-1])

if __name__ == "__main__":
    if len(sys.argv) > 1:
        if len(sys.argv) > 1:
            input_data = sys.argv[1]
        else:
            input_data = sys.stdin.read().strip()

    assert len(input_data) == 32 and all(c in "0123456789abcdef" for c in input_data.lower()), "Invalid input"
    num = int(input_data, 16)
    base36_data = base36_encode(num)
    print(base36_data, end = "")
