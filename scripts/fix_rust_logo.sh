#!/bin/bash
# ==============================================================================
# fix_rust_logo.sh v1.1 - PASTE-SAFE EDITION (ZERO heredocs!)
# Rust logo letoltes 6 szerveres fallback lánccal, integritás-ellenőrzéssel
# (PNG magic bytes / SVG tag), majd README.html automatikus patch.
# Hibakodok: ERR-301 .. ERR-306
# ==============================================================================

PROJECT_DIR="$HOME/secure-passgen"
DOC_DIR="$PROJECT_DIR/documentation_v2"
ASSETS_DIR="$DOC_DIR/assets"
HTML_FILE="$DOC_DIR/README.html"
TMP_DL="/tmp/rust_logo_dl.$$"
SELECTED_SOURCE=""
FINAL_EXT=""
FINAL_FILE=""

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# Kozponti hibakezelo - egyedi kod + uzenet + tipp
die() {
    echo
    echo -e "${RED}[FATAL ERR-$1] $2${NC}"
    echo -e "${YELLOW}Hint: $3${NC}"
    echo
    exit "$1"
}

echo -e "${CYAN}============================================================${NC}"
echo -e "${BOLD}  Rust Logo Fixer v1.1 (multi-server, no-heredoc edition)${NC}"
echo -e "${CYAN}============================================================${NC}"
echo

# --- [1/4] ELOFELTETELEK ELLENORZESE ---
echo -e "${BOLD}[1/4] Checking prerequisites...${NC}"
[ -d "$DOC_DIR" ] || die 301 "Documentation directory not found: $DOC_DIR" "Run ./readme_html_patch.sh first."
[ -f "$HTML_FILE" ] || die 301 "README.html not found in documentation_v2" "Run ./readme_html_patch.sh first."
command -v wget >/dev/null || command -v curl >/dev/null || die 302 "Neither wget nor curl installed" "sudo apt install wget curl"
echo -e "  ${GREEN}OK${NC} docs dir + README.html + download tool found"

# --- [2/4] LETOLTES 6 SZERVERES FALLBACK LANCCAL ---
download_one() {
    if command -v wget >/dev/null; then
        wget -q --user-agent="Mozilla/5.0 (X11; Linux x86_64) secure-passgen/1.0" --timeout=25 --tries=2 -O "$1" "$2" 2>/dev/null
    else
        curl -fsSL --connect-timeout 15 --max-time 60 --retry 2 -A "Mozilla/5.0 (X11; Linux x86_64) secure-passgen/1.0" -o "$1" "$2" 2>/dev/null
    fi
}

validate_one() {
    # Csak VALODI kepet fogadunk el: PNG magic bytes vagy SVG tag.
    # Ha a szerver HTML hiboldalt kuld kep helyett -> elutasitas.
    local f="$1" ext="$2" size
    [ -s "$f" ] || return 1
    size=$(stat -c%s "$f" 2>/dev/null || echo 0)
    [ "$size" -ge 512 ] || return 1
    if [ "$ext" = "png" ]; then
        head -c 8 "$f" | od -An -tx1 | tr -d ' \n' | grep -qi '^89504e470d0a1a0a'
    else
        grep -qa '<svg' "$f"
    fi
}

echo
echo -e "${BOLD}[2/4] Trying 6 servers in order...${NC}"

URLS=(
"https://cdn.jsdelivr.net/gh/rust-lang/www.rust-lang.org@master/static/images/rust-logo-256x256.png"
"https://raw.githubusercontent.com/rust-lang/www.rust-lang.org/master/static/images/rust-logo-256x256.png"
"https://www.rust-lang.org/logos/rust-logo-256x256.png"
"https://upload.wikimedia.org/wikipedia/commons/thumb/d/d5/Rust_programming_language_black.svg/240px-Rust_programming_language_black.svg.png"
"https://raw.githubusercontent.com/rust-lang/rust/master/src/doc/logo.png"
"https://upload.wikimedia.org/wikipedia/commons/d/d5/Rust_programming_language_black.svg"
)
EXTS=(png png png png png svg)
NAMES=(jsDelivr-CDN GitHub-raw rust-lang.org Wikimedia-PNG rust-repo Wikimedia-SVG)

for i in "${!URLS[@]}"; do
    n=$((i+1))
    echo -e "  ${BLUE}[$n/6]${NC} ${NAMES[$i]}: ${URLS[$i]}"
    rm -f "$TMP_DL"
    if download_one "$TMP_DL" "${URLS[$i]}" && validate_one "$TMP_DL" "${EXTS[$i]}"; then
        SELECTED_SOURCE="${URLS[$i]}"
        FINAL_EXT="${EXTS[$i]}"
        echo -e "    ${GREEN}OK${NC} valid image received ($(stat -c%s "$TMP_DL") bytes)"
        break
    fi
    echo -e "    ${YELLOW}FAIL${NC} - moving to next server"
    sleep 1
done

# Ha mind a 6 szerver megbukott: professzionalis helyi SVG generalasa
# (soronkenti echo-kkal, here-document NELKUL - paste-safe!)
if [ -z "$FINAL_EXT" ]; then
    echo -e "${YELLOW}  All servers failed - generating local SVG fallback...${NC}"
    {
        echo '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">'
        echo '  <rect width="256" height="256" rx="48" fill="#0a0e14"/>'
        echo '  <circle cx="128" cy="128" r="92" fill="#f74c00"/>'
        echo '  <circle cx="128" cy="128" r="70" fill="none" stroke="#0a0e14" stroke-width="8"/>'
        echo '  <circle cx="128" cy="36" r="10" fill="#0a0e14"/>'
        echo '  <circle cx="128" cy="220" r="10" fill="#0a0e14"/>'
        echo '  <circle cx="36" cy="128" r="10" fill="#0a0e14"/>'
        echo '  <circle cx="220" cy="128" r="10" fill="#0a0e14"/>'
        echo '  <text x="128" y="156" font-family="Arial Black,Arial,sans-serif" font-size="76" font-weight="900" fill="#ffffff" text-anchor="middle">R</text>'
        echo '</svg>'
    } > "$ASSETS_DIR/rust_logo.svg"
    SELECTED_SOURCE="local-generator (all 6 servers failed)"
    FINAL_EXT="svg"
    FINAL_FILE="$ASSETS_DIR/rust_logo.svg"
    echo -e "  ${GREEN}OK${NC} local SVG logo generated"
fi

# --- [3/4] TELEPITES + README.html PATCH ---
echo
echo -e "${BOLD}[3/4] Installing logo and patching README.html...${NC}"
rm -f "$ASSETS_DIR/rust_logo.png" "$ASSETS_DIR/rust_logo.png.svg" 2>/dev/null

if [ -z "$FINAL_FILE" ]; then
    FINAL_FILE="$ASSETS_DIR/rust_logo.$FINAL_EXT"
    cp "$TMP_DL" "$FINAL_FILE"
fi
rm -f "$TMP_DL"

# HTML referenciak normalizalasa a telepített tipusra
if [ "$FINAL_EXT" = "png" ]; then
    sed -i 's|assets/rust_logo\.svg|assets/rust_logo.png|g' "$HTML_FILE"
else
    sed -i 's|assets/rust_logo\.png|assets/rust_logo.svg|g' "$HTML_FILE"
fi

grep -q "assets/rust_logo.$FINAL_EXT" "$HTML_FILE" || die 305 "Failed to patch README.html" "Check file permissions on $HTML_FILE"
[ -f "$FINAL_FILE" ] || die 306 "Logo file missing after install" "Re-run this script."
echo -e "  ${GREEN}OK${NC} logo installed: $FINAL_FILE"
echo -e "  ${GREEN}OK${NC} README.html now references assets/rust_logo.$FINAL_EXT"

# --- [4/4] VEGSO RIPORT ---
echo
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  SUCCESS - RUST LOGO FIXED${NC}"
echo -e "${GREEN}============================================================${NC}"
echo -e "  Source : $SELECTED_SOURCE"
echo -e "  File   : $FINAL_FILE ($(stat -c%s "$FINAL_FILE" 2>/dev/null) bytes)"
echo -e "  SHA256 : $(sha256sum "$FINAL_FILE" 2>/dev/null | cut -c1-32)..."
echo -e "  HTML   : assets/rust_logo.$FINAL_EXT"
echo
echo -e "  Open: ${CYAN}xdg-open $HTML_FILE${NC}"
echo

# ===== END OF SCRIPT v1.1 - ha ez a sor hianyzik, a paste csonkolodott! =====
