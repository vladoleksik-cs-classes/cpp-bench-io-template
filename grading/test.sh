#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 -m <manifest> [-t <time_limit_sec>] [-l <mem_limit_MB>]

  -m  Path to manifest file (each line: input_file expected_output_file)
  -t  CPU time limit per test, in seconds (default: 2)
  -l  Memory limit per test, in megabytes (default: 256)

Example:
  $0 -m tests.txt -t 1 -l 128
EOF
  exit 1
}

# Default limits
TIME_LIMIT=2
MEM_LIMIT_MB=256

# Parse options
while getopts "m:t:l:" opt; do
  case "$opt" in
    m) MANIFEST="$OPTARG" ;;
    t) TIME_LIMIT="$OPTARG" ;;
    l) MEM_LIMIT_MB="$OPTARG" ;;
    *) usage ;;
  esac
done
shift $((OPTIND -1))

# Check mandatory manifest
if [[ -z "${MANIFEST-}" ]]; then
  echo "Error: manifest file is required."
  usage
fi

if [[ ! -f "$MANIFEST" ]]; then
  echo "Error: manifest file '$MANIFEST' not found."
  exit 2
fi

# Convert MB → KB for ulimit
MEM_LIMIT_KB=$(( MEM_LIMIT_MB * 1024 ))

PROGRAM="../program"
pass=0
fail=0
i=0

# ANSI colors
RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"; RESET="\e[0m"

while read -r infile expfile; do
  ((i++))
  echo -n "Test #$i: "

  if [[ ! -f "$infile" || ! -f "$expfile" ]]; then
    echo -e "${YELLOW}SKIP${RESET} (missing '$infile' or '$expfile')"
    continue
  fi

  TMPOUT=$(mktemp)
  TMPTIME=$(mktemp)

  {
    ulimit -v "$MEM_LIMIT_KB"
    exec timeout "${TIME_LIMIT}s" \
      /usr/bin/time -f "TIME:%e\nMEM:%M" -o "$TMPTIME" \
      "$PROGRAM" < "$infile" > "$TMPOUT"
  } 2>/dev/null
  status=$?

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
    if diff -q "$TMPOUT" "$expfile" >/dev/null; then
      echo -e "${GREEN}PASS${RESET} (time=${time_used}s, mem=${mem_used}KB)"
      ((pass++))
    else
      echo -e "${RED}FAIL${RESET} (time=${time_used}s, mem=${mem_used}KB)"
      echo "  └─ Input:    $infile"
      echo "  └─ Expected: $expfile"
      echo "  └─ Got:      $TMPOUT"
      ((fail++))
    fi
  fi

  rm -f "$TMPOUT" "$TMPTIME"
done < "$MANIFEST"

echo
echo "Summary: $pass passed, $fail failed out of $i tests."
exit $(( fail>0 ))
