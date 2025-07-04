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

PROGRAM="program"
pass=0
fail=0
i=0

# ANSI colors
RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"; RESET="\e[0m"

printf "%-6s | %-6s | %-10s | %-5s | %-8s | %-8s\n" "Iter" "Result" "Status" "Exit" "Time(s)" "Mem(KB)"
echo "----------------------------------------------------------------------"

while read -r infile okfile; do
  i=$(( i + 1 ))

  #skip missing files
  if [[ ! -f "$infile" || ! -f "$okfile" ]]; then
    echo -e "${YELLOW}SKIP${RESET} (missing '$infile' or '$okfile')"
    continue
  fi

  sandbox_dir=$(isolate --init)

  cp "$PROGRAM" "$sandbox_dir/box/program"
  cp "$infile" "$sandbox_dir/box/input.txt"

  set +eo pipefail
  isolate --chdir=/box --meta=res.txt --mem=$MEM_LIMIT_KB --time=$TIME_LIMIT --wall-time=5 --run -- ./program > /dev/null 2>&1 || true
  set -eo pipefail
  #--processes=8
  #--stdin=file1.txt \
  #--stdout=output.txt \
  #--stderr=errors.txt \

  META="res.txt"

  # Read values
  EXITCODE=$(grep -m1 '^exitcode:' "$META" | cut -d: -f2 || echo "-")
  CG_MEM=$(grep -m1 '^max-rss:' "$META" | cut -d: -f2)
  TIME=$(grep -m1 '^time:' "$META" | cut -d: -f2)
  STATUS=$(grep -m1 '^status:' "$META" | cut -d: -f2 || echo "OK")
 
  if [[ "$STATUS" == "OK" && "$EXITCODE" == "0" ]]; then
    if diff -q -Z --strip-trailing-cr "$sandbox_dir/box/output.txt" "$okfile" >/dev/null; then
      printf "%-6s | %-6b   | %-10b         | %-5s | %-8s | %-8s\n" "$i" "${GREEN}PASS${RESET}" "${GREEN}OK${RESET}" "$EXITCODE" "$TIME" "$CG_MEM"
      pass=$(( pass + 1 ))
    else
      printf "%-6s | %-6b   | %-10b         | %-5s | %-8s | %-8s\n" "$i" "${RED}FAIL${RESET}" "${RED}WA${RESET}" "$EXITCODE" "$TIME" "$CG_MEM"
      fail=$(( fail + 1 ))
    fi
  else
    printf "%-6s | %-6b   | %-10b         | %-5s | %-8s | %-8s\n" "$i" "${RED}FAIL${RESET}" "${RED}${STATUS}${RESET}" "$EXITCODE" "$TIME" "$CG_MEM"
    fail=$(( fail + 1 ))
  fi

  # cleanup for next test
  isolate --cleanup
done < "$MANIFEST"

echo "----------------------------------------------------------------------"
echo
echo "Summary: $pass passed, $fail failed out of $i tests."
exit $(( fail>0 ))
