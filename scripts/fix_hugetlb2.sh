#!/bin/bash
# fix_hugetlb2.sh - automatikus free-hugepages detektalas
SRC="$HOME/secure-passgen/src"
cd "$HOME/secure-passgen" || exit 1

# Hozzaadjuk a free hugepages olvaso fuggvenyt es a korlatozast
python3 - "$SRC/memory.rs" << 'PYEOF'
import sys
path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

# 1. Uj fuggveny: free hugepages beolvasasa
helper_fn = '''
/// Reads the number of FREE huge pages and returns it in bytes
fn get_free_hugepages_bytes() -> u64 {
    fs::read_to_string("/proc/meminfo").ok()
        .and_then(|s| s.lines().find(|l| l.starts_with("HugePages_Free:")).map(|l| l.to_string()))
        .and_then(|l| l.split_whitespace().nth(1).and_then(|v| v.parse::<u64>().ok()))
        .map(|pages| pages * 2 * 1024 * 1024)
        .unwrap_or(0)
}

/// Try to allocate huge pages via hugetlbfs'''

# Lecsereljuk a regi fuggveny-fejlecet az ujra (ami tartalmazza a helper-t is)
old_header = "/// Try to allocate huge pages via hugetlbfs"
if old_header in content and "get_free_hugepages_bytes" not in content:
    content = content.replace(old_header, helper_fn, 1)

# 2. A try_hugetlbfs elejen korlatozzuk a meretet a szabad huge pages-re
old_alloc = '''    let huge_page_size: usize = 2 * 1024 * 1024;
    let num_pages = size_bytes / huge_page_size;'''

new_alloc = '''    let huge_page_size: usize = 2 * 1024 * 1024;
    // AUTO-LIMIT: only use as many huge pages as are actually FREE
    let free_huge_bytes = get_free_hugepages_bytes();
    let size_bytes = size_bytes.min(free_huge_bytes as usize);
    let num_pages = size_bytes / huge_page_size;'''

if old_alloc in content and "AUTO-LIMIT" not in content:
    content = content.replace(old_alloc, new_alloc, 1)

# 3. Finomabb hibaüzenet, ha 0 szabad lap van
old_err = 'return Err("Not enough RAM for huge pages".to_string());'
new_err = 'return Err("No free huge pages available (check: cat /proc/meminfo | grep HugePages_Free)".to_string());'
if old_err in content:
    content = content.replace(old_err, new_err, 1)

with open(path, 'w') as f:
    f.write(content)
print("OK: memory.rs patched")
PYEOF

echo "Build..."
cargo build --release || { echo "HIBA: build sikertelen"; exit 1; }
echo
echo "=== KESZ ==="
echo "Most mar a program MAGATOL annyi huge page-et foglal, amennyi szabad."
echo "Teszt: ./target/release/secure-passgen --memory-first --huge-pages -c -n -s -l 16 --count 500000 -o /dev/shm/hp5.csv"

# ===== END OF SCRIPT v1.0 =====
