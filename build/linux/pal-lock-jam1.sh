#!/bin/sh
echo -ne '\033c\033]0;pal-lock-jam1\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/pal-lock-jam1.x86_64" "$@"
