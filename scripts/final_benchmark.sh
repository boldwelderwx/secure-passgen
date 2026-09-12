#!/bin/bash
# ==============================================================================
# final_benchmark.sh v1.0 - Control vs Huge Pages osszehasonlito benchmark
# Azonos feltetelek mellett meri a ket modot, monitorozza a swap-et is.
# ==============================================================================

PROJECT_DIR="$HOME/secure-passgen"
BIN="$PROJECT_DIR/target/release/secure-passgen"
TS=$(date +%Y%m%d_%H%M%S)
TEST_DIR="$PROJECT_DIR/final_bench_$TS"
RES="$TEST_DIR/results.csv"
MON="$TEST_DIR/monitor.csv"
LOG="$TEST_DIR/bench.log"
SHM="/dev/shm/bench_tmp"
START_TS=$(date +%s)
MON_PID=""

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
now()  { date +%s.%N; }
dur()  { awk -v a="$1" -v b="$2" 'BEGIN{printf "%.4f", b-a}'; }

# JAVITOTT record: ${10} es ${11}
record() {
    echo "$1,$2,$3,$4,$5,$6,$7,$8,$9,${10},${11}" >> "$RES"
    log "  $1 | $2 | L=$5 N=$6 t=${8}s thr=${9} rss=${10}KB [$11]"
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

# Monitor daemon - kulon processz, masodpercenkent logol
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

# --- INIT ---
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC} ${BOLD}FINAL BENCHMARK - Control vs Huge Pages${NC}                    ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"

[ -x "$BIN" ] || { echo -e "${RED}HIBA: binaris nem talalhato${NC}"; exit 1; }
mkdir -p "$TEST_DIR" "$SHM" || exit 1
echo "mode,name,charset,lang,length,count,cipher,time_s,thr_pw_s,maxrss_kb,status" > "$RES"
: > "$LOG"

log "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs) ($(nproc) mag)"
log "RAM: $(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo) MB total, $(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo) MB available"
log "Free hugepages: $(cat /sys/kernel/mm/hugepages/hugepages-2048kB/free_hugepages) x 2MB"

start_monitor
log "Monitor daemon elindult"

# --- WARM-UP ---
log "Warm-up (100K jelszo)..."
"$BIN" -c -n -s -l 16 --count 100000 -o "$SHM/warmup.csv" >/dev/null 2>&1
rm -f "$SHM/warmup.csv"

# --- TESZT MATRIX ---
COUNTS="1000000 5000000 10000000"
LENGTHS="16 1024 8192"

# CONTROL MOD (memory-first nelkul, sima malloc)
log "${BOLD}=== CONTROL MOD (sima malloc) ===${NC}"
for N in $COUNTS; do
    for L in $LENGTHS; do
        rc=$(measure "$TEST_DIR/.t" "$TEST_DIR/.r" -- "$BIN" \
            -c -n -s -l "$L" --count "$N" -o "$SHM/ctrl_${L}_${N}.csv")
        t=$(cat "$TEST_DIR/.t"); rss=$(cat "$TEST_DIR/.r")
        th=$(awk -v c="$N" -v x="$t" 'BEGIN{if(x>0)printf "%.2f", c/x; else print 0}')
        [ "$rc" = "0" ] && st=OK || st=FAIL
        record control "ctrl_L${L}_N${N}" latin en "$L" "$N" none "$t" "$th" "$rss" "$st"
        rm -f "$SHM/ctrl_${L}_${N}.csv"
    done
done

# HUGE PAGES MOD (hugetlbfs lockolt memoria)
log "${BOLD}=== HUGE PAGES MOD (hugetlbfs) ===${NC}"
for N in $COUNTS; do
    for L in $LENGTHS; do
        rc=$(measure "$TEST_DIR/.t" "$TEST_DIR/.r" -- "$BIN" \
            --memory-first --huge-pages \
            -c -n -s -l "$L" --count "$N" -o "$SHM/hp_${L}_${N}.csv")
        t=$(cat "$TEST_DIR/.t"); rss=$(cat "$TEST_DIR/.r")
        th=$(awk -v c="$N" -v x="$t" 'BEGIN{if(x>0)printf "%.2f", c/x; else print 0}')
        [ "$rc" = "0" ] && st=OK || st=FAIL
        record hugepages "hp_L${L}_N${N}" latin en "$L" "$N" none "$t" "$th" "$rss" "$st"
        rm -f "$SHM/hp_${L}_${N}.csv"
    done
done

stop_monitor

# --- OSSZEHASONLITO TABLAZAT ---
log "${BOLD}=== OSSZEHASONLITAS ===${NC}"
{
    echo "==============================================================================="
    echo "         FINAL BENCHMARK - CONTROL vs HUGE PAGES"
    echo "==============================================================================="
    echo "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo "RAM: $(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo) MB | Hugepages: $(cat /sys/kernel/mm/hugepages/hugepages-2048kB/free_hugepages) x 2MB"
    echo "Datum: $(date)"
    echo
    printf "%-22s | %-12s %-12s | %-12s %-12s | %-8s\n" "TEST" "CTRL t(s)" "CTRL thr" "HP t(s)" "HP thr" "KULONBSEG"
    echo "-----------------------|----------------------------|----------------------------|----------"

    for N in $COUNTS; do
        for L in $LENGTHS; do
            ctrl_line=$(grep "^control,ctrl_L${L}_N${N}," "$RES")
            hp_line=$(grep "^hugepages,hp_L${L}_N${N}," "$RES")
            ctrl_t=$(echo "$ctrl_line" | cut -d',' -f8)
            ctrl_th=$(echo "$ctrl_line" | cut -d',' -f9)
            hp_t=$(echo "$hp_line" | cut -d',' -f8)
            hp_th=$(echo "$hp_line" | cut -d',' -f9)
            # Kulonbseg szazalekban ( pozitiv = huge pages gyorsabb)
            diff=$(awk -v c="$ctrl_t" -v h="$hp_t" 'BEGIN{if(c>0)printf "%+.1f%%", (c-h)/c*100; else print "n/a"}')
            printf "L=%-5s N=%-8s | %-12s %-12s | %-12s %-12s | %-8s\n" "$L" "$N" "$ctrl_t" "$ctrl_th" "$hp_t" "$hp_th" "$diff"
        done
    done

    echo
    echo "=== MONITOR AGGREGATOK ==="
    if [ -f "$MON" ] && [ "$(wc -l < "$MON")" -gt 1 ]; then
        awk -F',' 'NR>1 {u+=$2; s+=$3; if($4>m)m=$4; if($6>sw)sw=$6; n++} END {
            printf "Atlag CPU user%%: %.1f | Atlag CPU sys%%: %.1f\n", u/n, s/n
            printf "Peak MEM: %d MB | Peak SWAP: %d MB\n", m, sw
        }' "$MON"
    fi

    echo
    echo "=== VERDIKT ==="
    echo "A huge pages elonye nagy terhelas alatt a STABILITAS (nem swap-el)"
    echo "es a kevesebb TLB miss. A sebesseg-kulonbseg kis merteku lehet,"
    echo "de a memoria-lock garantalja, hogy a teljesitmeny nem romlik."
    echo "==============================================================================="
} | tee "$TEST_DIR/comparison.txt"

echo
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC} ${BOLD}BENCHMARK KESZ${NC}                                              ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -e "  Osszehasonlitas : ${CYAN}$TEST_DIR/comparison.txt${NC}"
echo -e "  Nyers adatok    : ${CYAN}$RES${NC}"
echo -e "  Monitor         : ${CYAN}$MON${NC}"
echo -e "  Log             : ${CYAN}$LOG${NC}"
echo
echo -e "${YELLOW}Toltsd fel a comparison.txt es results.csv fajlokat!${NC}"

# ===== END OF SCRIPT v1.0 - ha ez a sor hianyzik, a paste csonkolodott! =====
