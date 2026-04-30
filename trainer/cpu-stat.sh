#!/bin/bash
# Usage: cpu-stat {pkg|max|cores}
case "${1:-pkg}" in
    pkg)
        sensors -u coretemp-isa-0000 2>/dev/null | awk '/Package id 0/{getline; printf "%d", $2; exit}'
        ;;
    max)
        sensors -u coretemp-isa-0000 2>/dev/null | awk '/_input/{if($2>m)m=$2}END{printf "%d", m}'
        ;;
    cores)
        sensors 2>/dev/null | awk '/^Core [0-9]+:/{gsub("[+]","",$3); printf "%s ", $3}'
        ;;
esac
