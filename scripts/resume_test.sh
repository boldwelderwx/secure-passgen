#!/bin/bash
# ==============================================================================
# resume_test.sh - Folytatja a mega_final_test-et onnan, ahol abbamaradt
# ==============================================================================

PROJECT_DIR="$HOME/secure-passgen"
BIN="$PROJECT_DIR/target/release/secure-passgen"

# Keresd meg a legutolso test konyvtarat
TEST_DIR=$(ls -1d "$PROJECT_DIR"/mega_final_20*/ 2>/dev/null | sort | tail -1)
[ -z "$TEST_DIR" ] && { echo "Nem talalok mega_final_20*/ konyvtarat"; exit 1; }

RES="$TEST_DIR/results.csv"
LOG="$TEST_DIR/resume.log"
SHM="/dev/shm/spgen_final"

echo "Folytatas: $TEST_DIR"
echo "Eddig lefutott cellak: $(tail -n +2 "$RES" | wc -l)"
echo

log()  { echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
now()  { date +%s.%N; }
dur()  { awk -v a="$1" -v b="$2" 'BEGIN{printf "%.3f", b-a}'; }
free_mb(){ df -Pk "$TEST_DIR" 2>/dev/null | awk 'NR==2{print int($4/1024)}'; }

record() {
    echo "$1,$2,$3,$4,$5,$6,$7,$8,$9,${10},${11}" >> "$RES"
    log "  $1 | $2 | L=$5 N=$6 cip=$7 t=${8}s thr=${9} rss=${10}KB [${11}]"
}

measure() {
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

# --- PHASE 2: folytatas a kimaradt cellakkal ---
log "PHASE 2: Generation ladder (folytatas)"
# Ezek maradtak ki: 16:5000000 (mar megvan), 16:10000000 (mar megvan), 128-tol felfele
cells="128:1000000 128:5000000 1024:500000 1024:1000000 2048:500000 2048:1000000 4096:500000 4096:1000000 8192:500000 8192:1000000 8192:5000000"

for cell in $cells; do
    L="${cell%%:*}"; N="${cell##*:}"
    log "  L=$L N=$N"
    out="$SHM/gen_${L}_${N}.csv"
    rc=$(measure "$TEST_DIR/.t" "$TEST_DIR/.r" -- "$BIN" -c -n -s -l "$L" --count "$N" -o "$out")
    t=$(cat "$TEST_DIR/.t"); rss=$(cat "$TEST_DIR/.r")
    th=$(awk -v c="$N" -v x="$t" 'BEGIN{if(x>0)printf "%.2f", c/x; else print 0}')
    [ "$rc" = "0" ] && st=OK || st=FAIL
    record gen "latin_L${L}" latin en "$L" "$N" none "$t" "$th" "$rss" "$st"
    rm -f "$out"
done

# --- PHASE 3-9: ugyanaz, mint a mega_final_test.sh-ben ---
log "PHASE 3: CSV disk ladder"
cells="16:500000 1024:500000 4096:100000 8192:100000 8192:500000 16000:10000 16000:100000"
for cell in $cells; do
    L="${cell%%:*}"; N="${cell##*:}"
    need=$(awk -v c="$N" -v l="$L" 'BEGIN{printf "%d", (c*(l+70))/1048576 + 1}')
    avail=$(free_mb)
    if [ "$avail" -le $((need + 2048)) ]; then
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
    rm -f "$out"
done

log "PHASE 4-8: charsets, languages, entropy, openssl, quality"
# (Ezeket bemásolhatod a mega_final_test.sh Phase 4-8 szekcióiból)

log "KESZ! Eredmenyek: $RES"

# ===== END OF SCRIPT v1.0 - ha ez a sor hianyzik, a paste csonkolodott! =====
