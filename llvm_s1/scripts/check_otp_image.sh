#!/bin/sh
# Self-check the wasp1 OTP image generation utility.

set -eu

log_file="${1:-logs/check_otp_image.log}"
work_dir="build/otp_image_check"
fixture_bin="$work_dir/fixture.bin"
fixture_hex="$work_dir/fixture.hex"
fixture_padded="$work_dir/fixture_padded.bin"
oversize_bin="$work_dir/oversize.bin"
mkdir -p "$(dirname "$log_file")" "$work_dir"
: > "$log_file"

failures=0

log()
{
  printf '%s\n' "$*" | tee -a "$log_file"
}

fail()
{
  log "FAIL $*"
  failures=$((failures + 1))
}

if ! command -v python3 >/dev/null 2>&1; then
  fail "python3 not found"
  log "RESULT FAIL OTP image generation check failures=$failures"
  exit "$failures"
fi

python3 - "$fixture_bin" <<'PY'
from pathlib import Path
import sys
Path(sys.argv[1]).write_bytes(bytes([1, 2, 3, 4, 0xaa]))
PY

if scripts/wasp1_make_otp_image.py \
    --format bin \
    --input "$fixture_bin" \
    --output-hex "$fixture_hex" \
    --output-bin "$fixture_padded" \
    --size 16 >> "$log_file" 2>&1; then
  log "PASS generate padded OTP image"
else
  fail "generate padded OTP image"
fi

line1=$(sed -n '1p' "$fixture_hex")
line2=$(sed -n '2p' "$fixture_hex")
line3=$(sed -n '3p' "$fixture_hex")
line4=$(sed -n '4p' "$fixture_hex")

[ "$line1" = "04030201" ] || fail "line1=$line1 expected=04030201"
[ "$line2" = "ffffffaa" ] || fail "line2=$line2 expected=ffffffaa"
[ "$line3" = "ffffffff" ] || fail "line3=$line3 expected=ffffffff"
[ "$line4" = "ffffffff" ] || fail "line4=$line4 expected=ffffffff"

padded_size=$(wc -c < "$fixture_padded" | tr -d ' ')
[ "$padded_size" = "16" ] || fail "padded_size=$padded_size expected=16"

python3 - "$oversize_bin" <<'PY'
from pathlib import Path
import sys
Path(sys.argv[1]).write_bytes(bytes(range(20)))
PY

if scripts/wasp1_make_otp_image.py \
    --format bin \
    --input "$oversize_bin" \
    --output-hex "$work_dir/oversize.hex" \
    --size 16 >> "$log_file" 2>&1; then
  fail "oversize image unexpectedly passed"
else
  log "PASS oversize image rejected"
fi

if [ "$failures" -eq 0 ]; then
  log "RESULT PASS OTP image generation check"
else
  log "RESULT FAIL OTP image generation check failures=$failures"
fi

exit "$failures"
