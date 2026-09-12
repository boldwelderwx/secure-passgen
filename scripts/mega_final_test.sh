#!/bin/bash
# ==============================================================================
# Script Name : mega_final_test.sh
# Version     : 1.0.0 - HYPER SUPER GIGA FINAL
# Description : Tobb oras, 4-magos parhuzamos stressz-teszt
#               Showcase fazis: elso 60 masodperc htop-megfigyeleshez
# ==============================================================================

PROJECT_DIR="$HOME/secure-passgen"
BIN="$PROJECT_DIR/target/release/secure-passgen"
TS=$(date +%Y%m%d_%H%M%S)
TEST_DIR="$PROJECT_DIR/mega_final_$TS"
RES="$TEST_DIR/results.csv"
LOG="$TEST_DIR/mega.log"
SHM="/dev/shm/spgen_final"
RESERVE_MB=2048
START_TS=$(date +%s)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# --- UTIL FUGGVENYEK ---
log()  { echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
now()  { date +%s.%N; }
dur()  { awk -v a="$1" -v b="$2" 'BEGIN{printf "%.3f", b-a}'; }
free_mb(){ df -Pk "$TEST_DIR" 2>/dev/null | awk 'NR==2{print int($4/1024)}'; }
eta(){
    local done_count=$1 total=$2 elapsed=$3
    if [ "$done_count" -gt 0 ] && [ "$elapsed" -gt 0 ]; then
        local remaining=$(( total - done_count ))
        local sec_remaining=$(( remaining * elapsed / done_count ))
        local h=$(( sec_remaining / 3600 ))
        local m=$(( (sec_remaining % 3600) / 60 ))
        local s=$(( sec_remaining % 60 ))
        printf "%dh %02dm %02ds" "$h" "$m" "$s"
    else
        echo "calculating..."
    fi
}

# JAVITOTT record - ${10} es ${11} bash positional parameterek!
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

# ============================================================================
# PHASE 0: INIT
# ============================================================================
phase0() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}MEGA FINAL TEST v1.0 - HYPER SUPER GIGA${NC}                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}4-magos parhuzamos, tobb oras, katonai szintu${NC}                ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"

    [ -x "$BIN" ] || { echo -e "${RED}HIBA: binaris nem talalhato: $BIN${NC}"; exit 1; }
    mkdir -p "$TEST_DIR" "$SHM" || { echo -e "${RED}HIBA: konyvtar letrehozasi hiba${NC}"; exit 1; }
    echo "suite,name,charset,lang,length,count,cipher,time_s,thr_pw_s,maxrss_kb,status" > "$RES"
    : > "$LOG"

    log "${BOLD}PHASE 0: INIT${NC}"
    log "  CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    log "  Cores: $(nproc) logical | Threads: $(nproc)"
    log "  RAM: $(free -h | awk '/^Mem:/{print $2}')"
    log "  Disk free: $(free_mb) MB"
    log "  OpenSSL: $(openssl version 2>/dev/null)"
    log "  Start: $(date)"
}

# ============================================================================
# PHASE 1: SHOWCASE (60 masodperc - htop megfigyeleshez!)
# ============================================================================
phase1_showcase() {
    log "${BOLD}${YELLOW}PHASE 1: SHOWCASE (60 masodperc)${NC}"
    log "${YELLOW}   >>> NYISS MOST EGY MASODIK TERMINALT ES GEPELD: htop <<<${NC}"
    log "${YELLOW}   >>> FIGYELD A 4 MAGOT - MIND ~100%-ON KELL FUTJON! <<<${NC}"
    log "${YELLOW}   >>> 60 masodperc mulva folytatjuk a valodi teszttel <<<${NC}"

    # Deep Entropy 1M iteracio - ez fogja legjobban terhelni a CPU-t
    # ~0.39 sec/jelszo, 150 jelszo = ~58 masodperc
    log "  Showcase: 150 jelszo, 1M iteracio (Deep Entropy), 64 karakter"
    rc=$(measure "$TEST_DIR/.t" "$TEST_DIR/.r" -- "$BIN" \
        -c -n -s -l 64 \
        --extreme-random --extreme-iter 1000000 \
        --count 150 \
        -o "$SHM/showcase.csv")
    t=$(cat "$TEST_DIR/.t"); rss=$(cat "$TEST_DIR/.r")
    th=$(awk -v c=150 -v x="$t" 'BEGIN{if(x>0)printf "%.2f", c/x; else print 0}')
    [ "$rc" = "0" ] && st=OK || st=FAIL
    record showcase "deep_1M_iter" latin en 64 150 entropy "$t" "$th" "$rss" "$st"
    rm -f "$SHM/showcase.csv"

    log "  Showcase kesz. ${GREEN}A htop-ban lattad a 4 mag zakatolasat?${NC}"
    log "  Most indul a valodi tobb oras teszt..."
    sleep 3
}

# ============================================================================
# PHASE 2: PARALLEL GEN LADDER (CPU stress)
# ============================================================================
phase2_gen() {
    log "${BOLD}PHASE 2: Parallel generation ladder (/dev/shm)${NC}"
    # Nagyobb darabszamok, hogy lathato legyen a parhuzamositas
    local cells="16:1000000 16:5000000 16:10000000 128:1000000 128:5000000 1024:500000 1024:1000000 2048:500000 2048:1000000 4096:500000 4096:1000000 8192:500000 8192:1000000 8192:5000000"

    local total=${#cells[@]}
    local i=0
    for cell in $cells; do
        i=$((i+1))
        local L="${cell%%:*}" N="${cell##*:}"
        local elapsed=$(( $(date +%s) - START_TS ))
        local et; et=$(eta "$i" "$total" "$elapsed")
        log "  [$i/$total] ETA: $et | L=$L N=$N"

        local out="$SHM/gen_${L}_${N}.csv"
        rc=$(measure "$TEST_DIR/.t" "$TEST_DIR/.r" -- "$BIN" -c -n -s -l "$L" --count "$N" -o "$out")
        t=$(cat "$TEST_DIR/.t"); rss=$(cat "$TEST_DIR/.r")
        th=$(awk -v c="$N" -v x="$t" 'BEGIN{if(x>0)printf "%.2f", c/x; else print 0}')
        cs_per=$(awk -v c="$N" -v L="$L" -v x="$t" 'BEGIN{if(x>0)printf "%.0f", c*L/x; else print 0}')
        [ "$rc" = "0" ] && st=OK || st=FAIL
        record gen "latin_L${L}" latin en "$L" "$N" none "$t" "$th" "$rss" "$st"
        log "    chars/sec: $cs_per"
        rm -f "$out"
    done
}

# ============================================================================
# PHASE 3: DISK CSV LADDER (ha van hely)
# ============================================================================
phase3_csv() {
    log "${BOLD}PHASE 3: CSV disk ladder${NC}"
    local cells="16:500000 1024:500000 4096:100000 8192:100000 8192:500000 16000:10000 16000:100000"
    local total=${#cells[@]}
    local i=0

    for cell in $cells; do
        i=$((i+1))
        local L="${cell%%:*}" N="${cell##*:}"
        local need; need=$(awk -v c="$N" -v l="$L" 'BEGIN{printf "%d", (c*(l+70))/1048576 + 1}')
        local avail; avail=$(free_mb)

        if [ "$avail" -le $((need + RESERVE_MB)) ]; then
            record csv "L${L}" latin en "$L" "$N" none 0 0 0 SKIP_DISK
            log "  [$i/$total] SKIP_DISK: need ${need}MB, have ${avail}MB"
            continue
        fi

        local out="$TEST_DIR/csv_${L}_${N}.csv"
        log "  [$i/$total] L=$L N=$N (need ${need}MB, have ${avail}MB)"

        rc=$(measure "$TEST_DIR/.t" "$TEST_DIR/.r" -- "$BIN" -c -n -s -l "$L" --count "$N" -o "$out")
        t=$(cat "$TEST_DIR/.t"); rss=$(cat "$TEST_DIR/.r")
        th=$(awk -v c="$N" -v x="$t" 'BEGIN{if(x>0)printf "%.2f", c/x; else print 0}')
        sz=$(du -m "$out" 2>/dev/null | cut -f1)
        [ "$rc" = "0" ] && st=OK || st=FAIL
        record csv "L${L}_file${sz}MB" latin en "$L" "$N" none "$t" "$th" "$rss" "$st"
        log "    file size: ${sz} MB"
        rm -f "$out"
    done
}

# ============================================================================
# PHASE 4: ALL 20 CHARSETS PARALLEL
# ============================================================================
phase4_charsets() {
    log "${BOLD}PHASE 4: All 20 charsets (parallel)${NC}"
    local CHARSETS="latin hu zh ja ko ar he hi bn th el ru hy ka ta te kn ml pa si"
    local i=0

    for cs in $CHARSETS; do
        i=$((i+1))
        log "  [$i/20] Charset: $cs"
        rc=$(measure "$TEST_DIR/.t" "$TEST_DIR/.r" -- "$BIN" \
            --charset "$cs" -c -n -l 128 --count 100000 -o "$SHM/cs_$cs.csv")
        t=$(cat "$TEST_DIR/.t"); rss=$(cat "$TEST_DIR/.r")
        th=$(awk -v c=100000 -v x="$t" 'BEGIN{if(x>0)printf "%.2f", c/x; else print 0}')
        [ "$rc" = "0" ] && st=OK || st=FAIL
        record charset "$cs" "$cs" en 128 100000 none "$t" "$th" "$rss" "$st"
        rm -f "$SHM/cs_$cs.csv"
    done
}

# ============================================================================
# PHASE 5: ALL 20 UI LANGUAGES
# ============================================================================
phase5_uilang() {
    log "${BOLD}PHASE 5: All 20 UI languages${NC}"
    local LANGS="en hu es zh hi ar bn pt ru ja de fr ko tr vi it pl uk nl ro"
    local i=0

    for lg in $LANGS; do
        i=$((i+1))
        log "  [$i/20] Language: $lg"
        t0=$(now)
        "$BIN" --language "$lg" -c -n -l 16 --count 10000 -o "$SHM/ui_$lg.csv" >/dev/null 2>&1
        rc=$?
        t1=$(now)
        t=$(dur "$t0" "$t1")
        th=$(awk -v c=10000 -v x="$t" 'BEGIN{if(x>0)printf "%.2f", c/x; else print 0}')
        [ "$rc" = "0" ] && st=OK || st=FAIL
        record uilang "$lg" latin "$lg" 16 10000 none "$t" "$th" 0 "$st"
        rm -f "$SHM/ui_$lg.csv"
    done
}

# ============================================================================
# PHASE 6: DEEP ENTROPY LADDER
# ============================================================================
phase6_entropy() {
    log "${BOLD}PHASE 6: Deep Entropy iteration ladder${NC}"
    local iters="1000 10000 100000 1000000"
    local counts="1000 100 10 1"
    local i=0
    local tot=4

    for it in $iters; do
        i=$((i+1))
        # A counts lista ugyanabban a sorrendben megy
        N=$(echo "$counts" | awk -v i="$i" '{print $i}')
        log "  [$i/$tot] Iterations: $it | N=$N"

        rc=$(measure "$TEST_DIR/.t" "$TEST_DIR/.r" -- "$BIN" \
            -c -n -s -l 16 \
            --extreme-random --extreme-iter "$it" \
            --count "$N" \
            -o "$SHM/ent_$it.csv")
        t=$(cat "$TEST_DIR/.t"); rss=$(cat "$TEST_DIR/.r")
        th=$(awk -v c="$N" -v x="$t" 'BEGIN{if(x>0)printf "%.2f", c/x; else print 0}')
        [ "$rc" = "0" ] && st=OK || st=FAIL
        record entropy "iter_${it}" latin en 16 "$N" none "$t" "$th" "$rss" "$st"
        rm -f "$SHM/ent_$it.csv"
    done
}

# ============================================================================
# PHASE 7: OPENSSL FUSION (SHELL-PROOF: -pass file:)
# ============================================================================
phase7_openssl() {
    log "${BOLD}PHASE 7: OpenSSL fusion (shell-proof, 1MB input)${NC}"
    head -c 1048576 /dev/zero | tr '\0' 'A' > "$TEST_DIR/input.txt"
    echo "ProbePass123" > "$SHM/pwf"

    local CIPHERS="aes-128-ecb aes-128-cbc aes-128-cfb aes-128-ofb aes-192-cbc aes-192-ecb aes-192-cfb aes-192-ofb aes-256-cbc aes-256-ecb aes-256-cfb aes-256-ofb des-cbc des-ecb des-cfb des-ofb des3-cbc des3-ecb des3-cfb des3-ofb rc4 rc2-cbc rc2-ecb rc2-cfb rc2-ofb seed-cbc seed-ecb seed-cfb seed-ofb"

    # Probe: melyik cipher mukodik
    log "  Probing ciphers..."
    local WORKING=""
    for c in $CIPHERS; do
        if openssl enc "-$c" -in "$TEST_DIR/input.txt" -out "$SHM/p.enc" -pass file:"$SHM/pwf" >/dev/null 2>&1; then
            WORKING="$WORKING $c"
        else
            record openssl "probe_$c" latin en 0 0 "$c" 0 0 0 SKIP_CIPHER
        fi
    done
    rm -f "$SHM/p.enc"
    local nw; nw=$(echo $WORKING | wc -w)
    log "  Working: $nw ciphers"

    local CHARSETS="latin hu zh ja ko ar he hi bn th el ru hy ka ta te kn ml pa si"
    local LENGTHS="16 32 128 1024 2048 4096"
    local total_expected=$(( nw * 20 * 6 ))
    log "  Expected cells: $total_expected"
    local i=0

    for cs in $CHARSETS; do
        for L in $LENGTHS; do
            # Jelszo generalas (parhuzamos!)
            "$BIN" --charset "$cs" -c -n -s -l "$L" --count 1 -o "$SHM/pw.csv" >/dev/null 2>&1
            pw=$(sed -n '2p' "$SHM/pw.csv" | cut -d',' -f2)
            [ -z "$pw" ] && pw="FallbackPass123!"
            printf '%s' "$pw" > "$SHM/pwf"
            rm -f "$SHM/pw.csv"

            for c in $WORKING; do
                i=$((i+1))
                if [ $((i % 50)) -eq 0 ]; then
                    local elapsed=$(( $(date +%s) - START_TS ))
                    local et; et=$(eta "$i" "$total_expected" "$elapsed")
                    log "  [$i/$total_expected] ETA: $et | cs=$cs L=$L c=$c"
                fi

                t0=$(now)
                openssl enc "-$c" -in "$TEST_DIR/input.txt" -out "$SHM/o.enc" -pass file:"$SHM/pwf" >/dev/null 2>&1
                rc=$?
                t1=$(now)
                t=$(dur "$t0" "$t1")
                [ "$rc" = "0" ] && st=OK || st=FAIL
                record openssl "cs_${cs}_L${L}" "$cs" en "$L" 1 "$c" "$t" 0 0 "$st"
            done
        done
    done
    rm -f "$SHM/o.enc" "$SHM/pwf" "$TEST_DIR/input.txt"
}

# ============================================================================
# PHASE 8: SHANNON ENTROPY (minosegi ellenorzes)
# ============================================================================
phase8_quality() {
    log "${BOLD}PHASE 8: Shannon entropy quality check${NC}"
    local CHARSETS="latin hu zh ja ko ar he hi bn th el ru hy ka ta te kn ml pa si"
    for cs in $CHARSETS; do
        "$BIN" --charset "$cs" -c -n -s -l 64 --count 50 -o "$SHM/sh.csv" >/dev/null 2>&1
        if [ -f "$SHM/sh.csv" ]; then
            tail -n +2 "$SHM/sh.csv" | cut -d',' -f2 > "$TEST_DIR/.sample"
            ent=$(fold -w1 "$TEST_DIR/.sample" 2>/dev/null | awk '{c[$0]++} END{n=NR; s=0; for(k in c){p=c[k]/n; s-=p*log(p)/log(2)} printf "%.3f", s}')
            record quality "shannon_$cs" "$cs" en 64 50 none 0 "$ent" 0 OK
        fi
        rm -f "$SHM/sh.csv"
    done
}

# ============================================================================
# PHASE 9: FINAL ANALYSIS
# ============================================================================
phase9_analyze() {
    log "${BOLD}PHASE 9: Final analysis${NC}"

    local total ok fail skip
    total=$(tail -n +2 "$RES" | wc -l)
    ok=$(tail -n +2 "$RES" | awk -F',' '$11=="OK"' | wc -l)
    fail=$(tail -n +2 "$RES" | awk -F',' '$11 ~ /FAIL/' | wc -l)
    skip=$(tail -n +2 "$RES" | awk -F',' '$11 ~ /SKIP/' | wc -l)
    local maxthr maxrss
    maxthr=$(tail -n +2 "$RES" | awk -F',' '$9+0>0{print $9}' | sort -n | tail -1)
    maxrss=$(tail -n +2 "$RES" | awk -F',' '$10+0>0{print $10}' | sort -n | tail -1)

    # TXT REPORT
    local TXT="$TEST_DIR/final_report.txt"
    {
        echo "==============================================================================="
        echo "         SECURE-PASSGEN FINAL REPORT - HYPER SUPER GIGA"
        echo "==============================================================================="
        echo "Host: $(hostname) | $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
        echo "Cores: $(nproc) | RAM: $(free -h | awk '/^Mem:/{print $2}')"
        echo "Start: $(date -d @$START_TS) | End: $(date)"
        echo "Duration: $(( $(date +%s) - START_TS )) seconds"
        echo
        echo "=== SUMMARY ==="
        echo "Total cells : $total"
        echo "OK          : $ok"
        echo "FAIL        : $fail"
        echo "SKIP        : $skip"
        echo "Max pw/s    : $maxthr"
        echo "Peak RSS    : ${maxrss}KB"
        echo
        echo "=== SUITE BREAKDOWN ==="
        tail -n +2 "$RES" | awk -F',' '{n[$1]++; if($11=="OK")ok[$1]++; if($11~/FAIL/)fl[$1]++; if($11~/SKIP/)sk[$1]++} END{for(s in n) printf "%-10s cells=%-5d ok=%-5d fail=%-4d skip=%-4d\n", s, n[s], ok[s]+0, fl[s]+0, sk[s]+0}'
        echo
        echo "=== GEN LADDER (parhuzamos) ==="
        grep "^gen," "$RES" | awk -F',' '{printf "L=%-6s N=%-10s t=%-10s thr=%-14s rss=%-6sKB\n", $5, $6, $8, $9, $10}'
        echo
        echo "=== SHOWCASE ==="
        grep "^showcase," "$RES"
        echo
        echo "=== DEEP ENTROPY ==="
        grep "^entropy," "$RES" | awk -F',' '{printf "%-15s N=%-5s t=%-10s thr=%s pw/s\n", $2, $6, $8, $9}'
        echo
        echo "=== OPENSSL SUMMARY ==="
        grep "^openssl," "$RES" | awk -F',' '$11=="OK" && $8+0>0 {cnt[$7]++; sum[$7]+=$8} END{for(c in cnt) printf "%-14s n=%-4d avg=%.5fs\n", c, cnt[c], sum[c]/cnt[c]}' | sort -k3 -n
        echo
        echo "=== SHANNON ENTROPY (byte-level) ==="
        grep "^quality," "$RES" | awk -F',' '{printf "%-8s %.3f\n", $3, $9}' | sort -k2 -n
    } > "$TXT"

    log "${GREEN}Final report: $TXT${NC}"
    cat "$TXT"
}

# --- CTRL+C trap ---
trap 'echo; log "${YELLOW}Ctrl+C - finalizing partial report...${NC}"; phase9_analyze; exit 130' INT TERM

# --- MAIN ---
phase0
phase1_showcase
phase2_gen
phase3_csv
phase4_charsets
phase5_uilang
phase6_entropy
phase7_openssl
phase8_quality
phase9_analyze

echo
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC} ${BOLD}MEGA FINAL TEST COMPLETED${NC}                                    ${GREEN}║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo -e "  Full results: ${CYAN}$RES${NC}"
echo -e "  Final report: ${CYAN}$TEST_DIR/final_report.txt${NC}"
echo -e "  Full log    : ${CYAN}$LOG${NC}"
echo

# ===== END OF SCRIPT v1.0 - ha ez a sor hianyzik, a paste csonkolodott! =====
