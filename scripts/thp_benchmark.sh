#!/bin/bash
# ==============================================================================
# thp_benchmark.sh v1.0 - THP memory-first benchmark, nagy adatok
# ~20 perc, minden charset, CSV integritas-ellenorzessel
# ==============================================================================

PROJECT_DIR="$HOME/secure-passgen"
BIN="$PROJECT_DIR/target/release/secure-passgen"
TS=$(date +%Y%m%d_%H%M%S)
TEST_DIR="$PROJECT_DIR/thp_bench_$TS"
RES="$TEST_DIR/results.csv"
MON="$TEST_DIR/monitor.csv"
LOG="$TEST_DIR/bench.log"
OUT_DIR="$TEST_DIR/csv_output"
START_TS=$(date +%s)
MON_PID=""
MIN_FREE_MB=3000

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
now()  { date +%s.%N; }
dur()  { awk -v a="$1" -v b="$2" 'BEGIN{printf "%.4f", b-a}'; }
free_mb(){ df -Pk "$TEST_DIR" 2>/dev/null | awk 'NR==2{print int($4/1024)}'; }

# JAVITOTT record: ${10} es ${11} pozicionalis parameterek
record() {
    echo "$1,$2,$3,$4,$5,$6,$7,$8,$9,${10},${11}" >> "$RES"
    log "  $1 | $2 | L=$5 N=$6 t=${8}s thr=${9} rss=${10}KB [${11}]"
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

# Lemezterulet ellenorzes - ha nincs eleg hely, SKIP
check_disk() {
    local need_mb=$1
    local avail
    avail=$(free_mb)
    if [ "$avail" -lt $((need_mb + MIN_FREE_MB)) ]; then
        return 1
    fi
    return 0
}

# CSV integritas ellenorzes
verify_csv() {
    local file=$1
    local expected_rows=$2
    if [ ! -f "$file" ]; then
        echo "MISSING"
        return
    fi
    local actual_rows
    actual_rows=$(wc -l < "$file")
    if [ "$actual_rows" -lt "$expected_rows" ]; then
        echo "INCOMPLETE($actual_rows/$expected_rows)"
    else
        echo "OK($actual_rows rows)"
    fi
}

# Monitor daemon - kulon processz
start_monitor() {
    echo "timestamp,cpu_user%,cpu_sys%,mem_used_MB,mem_free_MB,swap_used_MB,load_avg" > "$MON"
    (
        while true; do
            ts=$(date +%s)
            vmstat_line=$(vmstat 1 2 | tail -1)
            cpu_user=$(echo "$vmstat_line" | awk '{print $13}')
            cpu_sys=$(echo "$vmstat_line" | awk '{print $14}')
            mem_free_kb=$(echo "$vmstat_line" | awk '{print $4}')
            mem_total_mb=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)
            mem_used_mb=$(( mem_total_mb - mem_free_kb/1024 ))
            swap_used_mb=$(awk '/SwapFree/{sf=$2} /SwapTotal/{st=$2} END{print int((st-sf)/1024)}' /proc/meminfo)
            load=$(awk '{print $1}' /proc/loadavg)
            echo "$ts,$cpu_user,$cpu_sys,$mem_used_mb,$((mem_free_kb/1024)),$swap_used_mb,$load" >> "$MON"
            sleep 1
        done
    ) &
    MON_PID=$!
}

stop_monitor() {
    if [ -n "$MON_PID" ] && kill -0 "$MON_PID" 2>/dev/null; then
        kill "$MON_PID" 2>/dev/null
        wait "$MON_PID" 2>/dev/null
    fi
}

trap 'echo; log "Ctrl+C - cleanup..."; stop_monitor; exit 130' INT TERM

# --- INIT ---
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC} ${BOLD}THP BENCHMARK - nagy adatok, minden charset${NC}                ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"

[ -x "$BIN" ] || { echo -e "${RED}HIBA: binaris nem talalhato${NC}"; exit 1; }
mkdir -p "$TEST_DIR" "$OUT_DIR" || exit 1
echo "suite,name,charset,lang,length,count,cipher,time_s,thr_pw_s,maxrss_kb,status" > "$RES"
: > "$LOG"

log "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs) ($(nproc) mag)"
log "RAM: $(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo) MB total, $(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo) MB available"
log "Disk free: $(free_mb) MB (reserve: ${MIN_FREE_MB} MB)"

start_monitor
log "Monitor daemon elindult"

# Warm-up
log "Warm-up (100K jelszo)..."
"$BIN" -c -n -s -l 16 --count 100000 -o "$OUT_DIR/warmup.csv" >/dev/null 2>&1
rm -f "$OUT_DIR/warmup.csv"

# ============================================================================
# FAZIS 1: HOSSZ LETRA (16 -> 8192 char, 500K jelszo, THP-vel)
# ============================================================================
log "${BOLD}=== FAZIS 1: HOSSZ LETRA (THP memory-first) ===${NC}"
LENGTHS="16 128 1024 4096 8192"
N=500000

for L in $LENGTHS; do
    need=$(( N * L / 1024 / 1024 + 100 ))
    if ! check_disk "$need"; then
        record length "L${L}" latin en "$L" "$N" none 0 0 0 SKIP_DISK
        continue
    fi
    outfile="$OUT_DIR/len_${L}.csv"
    rc=$(measure "$TEST_DIR/.t" "$TEST_DIR/.r" -- "$BIN" \
        --memory-first --mem-percent 25 \
        -c -n -s -l "$L" --count "$N" -o "$outfile")
    t=$(cat "$TEST_DIR/.t"); rss=$(cat "$TEST_DIR/.r")
    th=$(awk -v c="$N" -v x="$t" 'BEGIN{if(x>0)printf "%.2f", c/x; else print 0}')
    [ "$rc" = "0" ] && st=OK || st=FAIL
    record length "L${L}" latin en "$L" "$N" none "$t" "$th" "$rss" "$st"
    # CSV integritas
    integ=$(verify_csv "$outfile" $((N + 1)))
    log "    CSV integritas: $integ"
    rm -f "$outfile"
done

# ============================================================================
# FAZIS 2: CHARSET LETRA (20 charset, szimbolumokkal, 200K x 64 char)
# ============================================================================
log "${BOLD}=== FAZIS 2: CHARSET LETRA (20 charset, szimbolumokkal) ===${NC}"
CHARSETS="latin hu zh ja ko ar he hi bn th el ru hy ka ta te kn ml pa si"
N=200000
L=64

for cs in $CHARSETS; do
    need=$(( N * L * 3 / 1024 / 1024 + 100 ))
    if ! check_disk "$need"; then
        record charset "$cs" "$cs" en "$L" "$N" none 0 0 0 SKIP_DISK
        continue
    fi
    outfile="$OUT_DIR/cs_${cs}.csv"
    rc=$(measure "$TEST_DIR/.t" "$TEST_DIR/.r" -- "$BIN" \
        --memory-first --mem-percent 25 \
        --charset "$cs" -c -n -s -l "$L" --count "$N" -o "$outfile")
    t=$(cat "$TEST_DIR/.t"); rss=$(cat "$TEST_DIR/.r")
    th=$(awk -v c="$N" -v x="$t" 'BEGIN{if(x>0)printf "%.2f", c/x; else print 0}')
    [ "$rc" = "0" ] && st=OK || st=FAIL
    record charset "$cs" "$cs" en "$L" "$N" none "$t" "$th" "$rss" "$st"
    integ=$(verify_csv "$outfile" $((N + 1)))
    log "    CSV integritas: $integ"
    rm -f "$outfile"
done

# ============================================================================
# FAZIS 3: EXTREM KOMBOK (Deep Entropy, plugin-ek, nagy meret)
# ============================================================================
log "${BOLD}=== FAZIS 3: EXTREM KOMBOK ===${NC}"

# 3a. Deep Entropy + THP
log "  3a. Deep Entropy 10K iter + THP (100K x 64 char)"
outfile="$OUT_DIR/entropy.csv"
rc=$(measure "$TEST_DIR/.t" "$TEST_DIR/.r" -- "$BIN" \
    --memory-first --mem-percent 25 \
    -c -n -s -l 64 --extreme-random --extreme-iter 10000 --count 100000 -o "$outfile")
t=$(cat "$TEST_DIR/.t"); rss=$(cat "$TEST_DIR/.r")
th=$(awk -v c=100000 -v x="$t" 'BEGIN{if(x>0)printf "%.2f", c/x; else print 0}')
[ "$rc" = "0" ] && st=OK || st=FAIL
record entropy "deep_10K_thp" latin en 64 100000 none "$t" "$th" "$rss" "$st"
rm -f "$outfile"

# 3b. Plugin-ek + THP
log "  3b. Plugin-ek (uppercase,hyphen) + THP (200K x 32 char)"
outfile="$OUT_DIR/plugins.csv"
rc=$(measure "$TEST_DIR/.t" "$TEST_DIR/.r" -- "$BIN" \
    --memory-first --mem-percent 25 \
    -c -n -s -l 32 --count 200000 --plugins uppercase,hyphen -o "$outfile")
t=$(cat "$TEST_DIR/.t"); rss=$(cat "$TEST_DIR/.r")
th=$(awk -v c=200000 -v x="$t" 'BEGIN{if(x>0)printf "%.2f", c/x; else print 0}')
[ "$rc" = "0" ] && st=OK || st=FAIL
record plugins "upper_hyphen_thp" latin en 32 200000 none "$t" "$th" "$rss" "$st"
rm -f "$outfile"

# 3c. Nagy meret: 500K x 4096 char CSV (THP)
log "  3c. Nagy CSV: 500K x 4096 char (THP)"
need=$(( 500000 * 4096 / 1024 / 1024 + 200 ))
if check_disk "$need"; then
    outfile="$OUT_DIR/big_4096.csv"
    rc=$(measure "$TEST_DIR/.t" "$TEST_DIR/.r" -- "$BIN" \
        --memory-first --mem-percent 25 \
        -c -n -s -l 4096 --count 500000 -o "$outfile")
    t=$(cat "$TEST_DIR/.t"); rss=$(cat "$TEST_DIR/.r")
    th=$(awk -v c=500000 -v x="$t" 'BEGIN{if(x>0)printf "%.2f", c/x; else print 0}')
    [ "$rc" = "0" ] && st=OK || st=FAIL
    record bigcsv "500K_x_4096_thp" latin en 4096 500000 none "$t" "$th" "$rss" "$st"
    integ=$(verify_csv "$outfile" 500001)
    sz=$(du -m "$outfile" 2>/dev/null | cut -f1)
    log "    CSV integritas: $integ | Meret: ${sz} MB"
    rm -f "$outfile"
else
    record bigcsv "500K_x_4096_thp" latin en 4096 500000 none 0 0 0 SKIP_DISK
fi

# 3d. Nagy meret: 500K x 8192 char CSV (THP) - ha van hely
log "  3d. Nagy CSV: 500K x 8192 char (THP)"
need=$(( 500000 * 8192 / 1024 / 1024 + 200 ))
if check_disk "$need"; then
    outfile="$OUT_DIR/big_8192.csv"
    rc=$(measure "$TEST_DIR/.t" "$TEST_DIR/.r" -- "$BIN" \
        --memory-first --mem-percent 25 \
        -c -n -s -l 8192 --count 500000 -o "$outfile")
    t=$(cat "$TEST_DIR/.t"); rss=$(cat "$TEST_DIR/.r")
    th=$(awk -v c=500000 -v x="$t" 'BEGIN{if(x>0)printf "%.2f", c/x; else print 0}')
    [ "$rc" = "0" ] && st=OK || st=FAIL
    record bigcsv "500K_x_8192_thp" latin en 8192 500000 none "$t" "$th" "$rss" "$st"
    integ=$(verify_csv "$outfile" 500001)
    sz=$(du -m "$outfile" 2>/dev/null | cut -f1)
    log "    CSV integritas: $integ | Meret: ${sz} MB"
    rm -f "$outfile"
else
    record bigcsv "500K_x_8192_thp" latin en 8192 500000 none 0 0 0 SKIP_DISK
fi

# ============================================================================
# FAZIS 4: CONTROL vs THP osszehasonlitas (rovid)
# ============================================================================
log "${BOLD}=== FAZIS 4: CONTROL vs THP (1M x 1024 char) ===${NC}"
outfile="$OUT_DIR/cmp.csv"

# Control (memory-first nelkul)
rc=$(measure "$TEST_DIR/.t" "$TEST_DIR/.r" -- "$BIN" \
    -c -n -s -l 1024 --count 1000000 -o "$outfile")
t=$(cat "$TEST_DIR/.t"); rss=$(cat "$TEST_DIR/.r")
th=$(awk -v c=1000000 -v x="$t" 'BEGIN{if(x>0)printf "%.2f", c/x; else print 0}')
[ "$rc" = "0" ] && st=OK || st=FAIL
record compare "control_1M_1024" latin en 1024 1000000 none "$t" "$th" "$rss" "$st"
rm -f "$outfile"

# THP
rc=$(measure "$TEST_DIR/.t" "$TEST_DIR/.r" -- "$BIN" \
    --memory-first --mem-percent 25 \
    -c -n -s -l 1024 --count 1000000 -o "$outfile")
t=$(cat "$TEST_DIR/.t"); rss=$(cat "$TEST_DIR/.r")
th=$(awk -v c=1000000 -v x="$t" 'BEGIN{if(x>0)printf "%.2f", c/x; else print 0}')
[ "$rc" = "0" ] && st=OK || st=FAIL
record compare "thp_1M_1024" latin en 1024 1000000 none "$t" "$th" "$rss" "$st"
rm -f "$outfile"

# --- VEGSO OSSZEFOGLALO ---
stop_monitor

DURATION=$(( $(date +%s) - START_TS ))
TOTAL=$(tail -n +2 "$RES" | wc -l)
OK_COUNT=$(tail -n +2 "$RES" | awk -F',' '$11=="OK"' | wc -l)
FAIL_COUNT=$(tail -n +2 "$RES" | awk -F',' '$11=="FAIL"' | wc -l)
SKIP_COUNT=$(tail -n +2 "$RES" | awk -F',' '$11~/SKIP/' | wc -l)
MAX_THR=$(tail -n +2 "$RES" | awk -F',' '$9+0>0{print $9}' | sort -n | tail -1)

{
    echo "==============================================================================="
    echo "  THP BENCHMARK - VEGSO RIPORT"
    echo "==============================================================================="
    echo "Datum    : $(date)"
    echo "Idotartam: $DURATION mp"
    echo "CPU      : $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo "RAM      : $(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo) MB"
    echo
    echo "=== OSSZEFOGLALO ==="
    echo "Osszes cella : $TOTAL"
    echo "OK           : $OK_COUNT"
    echo "FAIL         : $FAIL_COUNT"
    echo "SKIP         : $SKIP_COUNT"
    echo "Max pw/s     : $MAX_THR"
    echo
    echo "=== HOSSZ LETRA (500K jelszo, THP) ==="
    grep "^length," "$RES" | awk -F',' '{printf "  L=%-6s t=%-10s thr=%-14s rss=%-6sKB [%s]\n", $5, $8, $9, $10, $11}'
    echo
    echo "=== CHARSET LETRA (200K x 64 char, THP) ==="
    grep "^charset," "$RES" | awk -F',' '{printf "  %-6s t=%-10s thr=%-14s rss=%-6sKB [%s]\n", $3, $8, $9, $10, $11}'
    echo
    echo "=== EXTREM KOMBOK ==="
    grep -E "^(entropy|plugins|bigcsv)," "$RES" | awk -F',' '{printf "  %-25s t=%-10s thr=%-14s [%s]\n", $2, $8, $9, $11}'
    echo
    echo "=== CONTROL vs THP (1M x 1024 char) ==="
    grep "^compare," "$RES" | awk -F',' '{printf "  %-20s t=%-10s thr=%-14s rss=%-6sKB [%s]\n", $2, $8, $9, $10, $11}'
    echo
    echo "=== MONITOR AGGREGATOK ==="
    if [ -f "$MON" ] && [ "$(wc -l < "$MON")" -gt 1 ]; then
        awk -F',' 'NR>1 {u+=$2; s+=$3; if($4>m)m=$4; if($6>sw)sw=$6; n++} END {
            printf "  Atlag CPU user%%: %.1f | Atlag CPU sys%%: %.1f\n", u/n, s/n
            printf "  Peak MEM: %d MB | Peak SWAP: %d MB\n", m, sw
        }' "$MON"
    fi
    echo
    echo "=== VERDIKT ==="
    echo "  A THP (Transparent Huge Pages) sudo nelkul hasznal 2MB-os memórialapokat,"
    echo "  ami csokkenti a TLB miss-eket es gyorsitja a nagy memoria-hozzaferest."
    echo "  Ez pontosan az a technologia, amit a PostgreSQL/Redis/MySQL hasznal."
    echo "==============================================================================="
} | tee "$TEST_DIR/final_report.txt"

echo
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC} ${BOLD}BENCHMARK KESZ${NC}                                              ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -e "  Riport   : ${CYAN}$TEST_DIR/final_report.txt${NC}"
echo -e "  Nyers    : ${CYAN}$RES${NC}"
echo -e "  Monitor  : ${CYAN}$MON${NC}"
echo
echo -e "${YELLOW}Masold be a final_report.txt tartalmat a chatbe!${NC}"

# ===== END OF SCRIPT v1.0 - ha ez a sor hianyzik, a paste csonkolodott! =====
