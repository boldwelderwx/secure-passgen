#!/bin/bash
# ==============================================================================
# rerun_fixed.sh v2.0 - Re-measures the corrupted suites with FIXED recording
# Fixes: ${10}/${11} param bug, -pass file: (shell-proof), disk report
# ==============================================================================
PROJECT_DIR="$HOME/secure-passgen"
BIN="$PROJECT_DIR/target/release/secure-passgen"
TS=$(date +%Y%m%d_%H%M%S)
TEST_DIR="$PROJECT_DIR/rerun_fixed_$TS"
RES="$TEST_DIR/results.csv"
LOG="$TEST_DIR/rerun.log"
SHM="/dev/shm/spgen_tmp"
RESERVE_MB=1024

mkdir -p "$TEST_DIR" "$SHM" || { echo "ERR: cannot create dir"; exit 1; }
echo "suite,name,charset,lang,length,count,cipher,time_s,thr,maxrss_kb,status" > "$RES"
: > "$LOG"

log(){ echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
now(){ date +%s.%N; }
dur(){ awk -v a="$1" -v b="$2" 'BEGIN{printf "%.3f", b-a}'; }
free_mb(){ df -Pk "$TEST_DIR" | awk 'NR==2{print int($4/1024)}'; }

record(){
  # FIXED: ${10} and ${11} - the 10th/11th positional params!
  echo "$1,$2,$3,$4,$5,$6,$7,$8,$9,${10},${11}" >> "$RES"
  log "  $1 | $2 | L=$5 N=$6 cip=$7 t=${8}s thr=${9} rss=${10}KB [${11}]"
}

measure(){
  local tf="$1" rf="$2"; shift 2
  local t0 t1
  t0=$(now)
  if [ -x /usr/bin/time ]; then
    /usr/bin/time -v "$@" >/dev/null 2>"$TEST_DIR/.tt"
    echo "$?" > "$TEST_DIR/.rc"
    t1=$(now)
    grep "Maximum resident" "$TEST_DIR/.tt" | awk '{print $NF}' > "$rf"
  else
    "$@" >/dev/null 2>&1
    echo "$?" > "$TEST_DIR/.rc"
    t1=$(now); echo 0 > "$rf"
  fi
  dur "$t0" "$t1" > "$tf"
  cat "$TEST_DIR/.rc"
}

log "=== RERUN FIXED v2.0 ==="
log "Disk free: $(free_mb) MB | Reserve: ${RESERVE_MB} MB"
[ "$(free_mb)" -lt 2048 ] && log "WARNING: low disk space - some CSV tests may SKIP_DISK"

# --- A: CSV DISK LADDER (fixed recording) ---
log "--- A: CSV disk ladder ---"
for cell in "16:500000" "1024:500000" "8192:100000" "8192:500000" "16000:10000" "16000:100000" "16000:500000"; do
  L="${cell%%:*}"; N="${cell##*:}"
  need=$(awk -v c="$N" -v l="$L" 'BEGIN{printf "%d", (c*(l+70))/1048576 + 1}')
  if [ "$(free_mb)" -le $((need + RESERVE_MB)) ]; then
    record csv "L${L}" latin en "$L" "$N" none 0 0 0 SKIP_DISK
    continue
  fi
  out="$TEST_DIR/csv_${L}_${N}.csv"
  rc=$(measure "$TEST_DIR/.t" "$TEST_DIR/.r" -- "$BIN" -c -n -s -l "$L" --count "$N" -o "$out")
  t=$(cat "$TEST_DIR/.t"); rss=$(cat "$TEST_DIR/.r")
  th=$(awk -v c="$N" -v x="$t" 'BEGIN{if(x>0)printf "%.2f", c/x; else print 0}')
  sz=$(du -m "$out" 2>/dev/null | cut -f1)
  [ "$rc" = "0" ] && st=OK || st=FAIL
  record csv "L${L}_file${sz}MB" latin en "$L" "$N" none "$t" "$th" "$rss" "$st"
  log "    file size: ${sz} MB"
  rm -f "$out"
done

# grid mode
rc=$(measure "$TEST_DIR/.t" "$TEST_DIR/.r" -- "$BIN" --password-db -c -n -l 12 --count 500000 -o "$TEST_DIR/grid.csv")
t=$(cat "$TEST_DIR/.t"); rss=$(cat "$TEST_DIR/.r")
th=$(awk -v x="$t" 'BEGIN{if(x>0)printf "%.2f", 500000/x; else print 0}')
[ "$rc" = "0" ] && st=OK || st=FAIL
record csv grid_500k latin en 12 500000 grid "$t" "$th" "$rss" "$st"
rm -f "$TEST_DIR/grid.csv"

# --- B: OPENSSL FUSION with -pass file: (SHELL-PROOF!) ---
log "--- B: OpenSSL fusion via -pass file: (shell-proof) ---"
head -c 1048576 /dev/zero | tr '\0' 'A' > "$TEST_DIR/input.txt"
echo "ProbePass123" > "$SHM/pwf"

CIPHERS="aes-128-ecb aes-128-cbc aes-128-cfb aes-128-ofb aes-192-cbc aes-192-ecb aes-192-cfb aes-192-ofb aes-256-cbc aes-256-ecb aes-256-cfb aes-256-ofb des-cbc des-ecb des-cfb des-ofb des3-cbc des3-ecb des3-cfb des3-ofb rc4 rc2-cbc rc2-ecb rc2-cfb rc2-ofb seed-cbc seed-ecb seed-cfb seed-ofb aes-128-gcm aes-192-gcm aes-256-gcm"
WORKING=""
for c in $CIPHERS; do
  if openssl enc "-$c" -in "$TEST_DIR/input.txt" -out "$SHM/p.enc" -pass file:"$SHM/pwf" >/dev/null 2>&1; then
    WORKING="$WORKING $c"
  else
    record openssl "probe_$c" latin en 0 0 "$c" 0 0 0 SKIP_CIPHER
  fi
done
rm -f "$SHM/p.enc"
log "Working ciphers: $(echo $WORKING | wc -w) of 32"

CHARSETS="latin hu zh ja ko ar he hi bn th el ru hy ka ta te kn ml pa si"
LENGTHS="16 32 128 1024 2048 4096"
for cs in $CHARSETS; do
  for L in $LENGTHS; do
    "$BIN" --charset "$cs" -c -n -s -l "$L" --count 1 -o "$SHM/pw.csv" >/dev/null 2>&1
    pw=$(sed -n '2p' "$SHM/pw.csv" | cut -d',' -f2)
    [ -z "$pw" ] && pw="FallbackPass123!"
    printf '%s' "$pw" > "$SHM/pwf"
    rm -f "$SHM/pw.csv"
    for c in $WORKING; do
      cmd="openssl enc -$c -in $TEST_DIR/input.txt -out $SHM/o.enc -pass file:$SHM/pwf"
      t0=$(now); eval "$cmd" >/dev/null 2>&1; rc=$?; t1=$(now)
      t=$(dur "$t0" "$t1")
      [ "$rc" = "0" ] && st=OK || st=FAIL
      record openssl "cs_${cs}_L${L}" "$cs" en "$L" 1 "$c" "$t" 0 0 "$st"
    done
  done
done
rm -f "$SHM/o.enc" "$SHM/pwf"

# --- C: MINI SUMMARY ---
log "--- C: Summary ---"
log "Total rows: $(tail -n +2 "$RES" | wc -l)"
tail -n +2 "$RES" | awk -F',' '{n[$11]++} END{for(k in n) printf "  status %-12s : %d\n", k, n[k]}' | tee -a "$LOG"
log "CSV suite:"
grep "^csv," "$RES" | awk -F',' '{printf "  %-22s t=%-8s thr=%-12s [%s]\n", $2, $8, $9, $11}' | tee -a "$LOG"
log "OpenSSL fastest/slowest (valid only):"
grep "^openssl," "$RES" | awk -F',' '$11=="OK" && $8+0>0 {if(f==""||$8+0<f+0){f=$8;fn=$7}; if($8+0>s+0){s=$8;sn=$7}} END{printf "  fastest: %s (%s s) | slowest: %s (%s s)\n", fn, f, sn, s}' | tee -a "$LOG"
log "DONE. Reports: $RES"
log "Run analyzer: ~/secure-passgen/mega_test_20260904_103010/analyze_results.sh $TEST_DIR"

# ===== END OF SCRIPT v2.0 - ha ez a sor hianyzik, a paste csonkolodott! =====
