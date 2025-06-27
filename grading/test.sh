#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 -m <manifest> [-t <time_limit_sec>] [-l <mem_limit_MB>]

  -m  Path to manifest file (each line: infile okfile)
  -t  CPU time limit per test, in seconds (default: 2)
  -l  Memory limit per test, in megabytes (default: 256)

Example:
  $0 -m tests.txt -t 1 -l 128
EOF
  exit 1
}

# Defaults
TIME_LIMIT=2
MEM_LIMIT_MB=256

while getopts "m:t:l:" opt; do
  case "$opt" in
    m) MANIFEST="$OPTARG" ;;
    t) TIME_LIMIT="$OPTARG" ;;
    l) MEM_LIMIT_MB="$OPTARG" ;;
    *) usage ;;
  esac
done
shift $((OPTIND -1))

# Manifest is required
if [[ -z "${MANIFEST-}" ]]; then
  echo "Error: manifest file is required."
  usage
fi
if [[ ! -f "$MANIFEST" ]]; then
  echo "Error: manifest file '$MANIFEST' not found."
  exit 2
fi

# Convert MB → KB
MEM_LIMIT_KB=$(( MEM_LIMIT_MB * 1024 ))

PROGRAM="../program"
pass=0
fail=0
i=0

# ANSI colors
RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"; RESET="\e[0m"

while read -r infile okfile; do
  ((i++))
  echo -n "Test #$i: "

  # skip missing files
  if [[ ! -f "$infile" || ! -f "$okfile" ]]; then
    echo -e "${YELLOW}SKIP${RESET} (missing '$infile' or '$okfile')"
    continue
  fi

  # prepare fixed I/O names
  cp "$infile" input.txt

  TMPTIME=$(mktemp)

  {
    ulimit -v "$MEM_LIMIT_KB"                   # cap virtual memory
    exec timeout "${TIME_LIMIT}s" \
      /usr/bin/time -f "TIME:%e\nMEM:%M" -o "$TMPTIME" \
      "$PROGRAM"                               # reads input.txt, writes output.txt
  } 2>/dev/null
  status=$?

  # read stats
  mapfile -t stats < "$TMPTIME"
  time_used=${stats[0]#TIME:}
  mem_used=${stats[1]#MEM:}

  if [ $status -eq 124 ]; then
    echo -e "${YELLOW}TIMEOUT${RESET} (${time_used}s)"
    ((fail++))
  elif [ $status -ne 0 ]; then
    echo -e "${RED}RUNTIME ERROR (exit $status)${RESET}"
    ((fail++))
  else
    if diff -q output.txt "$okfile" >/dev/null; then
      echo -e "${GREEN}PASS${RESET} (time=${time_used}s, mem=${mem_used}KB)"
      ((pass++))
    else
      echo -e "${RED}FAIL${RESET} (time=${time_used}s, mem=${mem_used}KB)"
      echo "  └─ infile:    $infile"
      echo "  └─ expected:  $okfile"
      echo "  └─ got:       output.txt"
      ((fail++))
    fi
  fi

  # cleanup for next test
  rm -f input.txt output.txt "$TMPTIME"
done < "$MANIFEST"

echo
echo "Summary: $pass passed, $fail failed out of $i tests."
exit $(( fail>0 ))
