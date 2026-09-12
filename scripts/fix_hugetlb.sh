#!/bin/bash
# fix_hugetlb.sh - hugetlbfs alapu mmap (sudo nelkul mukodik)
SRC="$HOME/secure-passgen/src"
cd "$HOME/secure-passgen" || exit 1

cat > "$SRC/memory.rs" << 'MEM_EOF'
//! Memory-First module v3.3.0 - hugetlbfs based (sudo-less)
//!
//! Strategies:
//!   1. --huge-pages   : hugetlbfs file + mmap (NO SUDO, works with chmod 1777)
//!   2. --pre-touch    : mmap(MAP_POPULATE) + touch (NO SUDO)
//!   3. mlockall       : needs sudo OR systemd LimitMEMLOCK=infinity
//!   4. Fallback       : plain malloc, still fast

use std::fs;
use std::io::Write;

pub fn activate_memory_first(percent: u8, huge_pages: bool, pre_touch: bool) -> (bool, String) {
    let total_bytes = get_total_memory_bytes();
    let target_bytes = total_bytes * (percent as u64) / 100;
    let available = get_available_memory_bytes();
    let actual = target_bytes.min(available * 9 / 10);

    if actual == 0 {
        return (false, "No RAM available to reserve".to_string());
    }

    // --- Strategy 1: Huge Pages via hugetlbfs (SUDO-LESS) ---
    if huge_pages {
        match try_hugetlbfs(actual as usize) {
            Ok(msg) => return (true, msg),
            Err(e) => {
                return (false, format!(
                    "Huge pages unavailable: {}. Falling back.", e
                ));
            }
        }
    }

    // --- Strategy 2: Pre-touch (SUDO-LESS) ---
    if pre_touch {
        unsafe {
            let flags = libc::MAP_PRIVATE | libc::MAP_ANONYMOUS | libc::MAP_POPULATE;
            let ptr = libc::mmap(
                std::ptr::null_mut(), actual as usize,
                libc::PROT_READ | libc::PROT_WRITE, flags, -1, 0,
            );
            if ptr == libc::MAP_FAILED {
                return (false, "mmap with MAP_POPULATE failed".to_string());
            }
            let slice = std::slice::from_raw_parts_mut(ptr as *mut u8, actual as usize);
            for chunk in slice.chunks_mut(4096) {
                if !chunk.is_empty() { chunk[0] = 1; }
            }
            return (true, format!(
                "Pre-touch mode: {} MB allocated + faulted (NO SUDO needed)",
                actual / 1024 / 1024
            ));
        }
    }

    // --- Strategy 3: mlockall (sudo or systemd) ---
    let rc = unsafe { libc::mlockall(libc::MCL_CURRENT | libc::MCL_FUTURE) };
    if rc == 0 {
        let mut buf: Vec<u8> = Vec::new();
        buf.reserve(actual as usize);
        buf.resize(actual as usize, 0);
        for chunk in buf.chunks_mut(4096) {
            if !chunk.is_empty() { chunk[0] = 1; }
        }
        return (true, format!(
            "Memory-first active: {}% RAM locked (~{} MB) [mlockall]",
            percent, actual / 1024 / 1024
        ));
    }

    // --- Fallback: plain malloc ---
    let mut buf: Vec<u8> = Vec::new();
    buf.reserve(actual as usize);
    buf.resize(actual as usize, 0);
    for chunk in buf.chunks_mut(4096) {
        if !chunk.is_empty() { chunk[0] = 1; }
    }

    (true, format!(
        "Memory-first (BEST-EFFORT): {} MB allocated. Not locked - use --huge-pages for sudo-less locking.",
        actual / 1024 / 1024
    ))
}

/// Try to allocate huge pages via hugetlbfs (works without sudo if /dev/hugepages is writable)
fn try_hugetlbfs(size_bytes: usize) -> Result<String, String> {
    let huge_page_size: usize = 2 * 1024 * 1024;
    let num_pages = size_bytes / huge_page_size;
    if num_pages == 0 {
        return Err("Not enough RAM for huge pages".to_string());
    }
    let actual_size = num_pages * huge_page_size;

    let hugetlb_path = format!("/dev/hugepages/spgen_{}", std::process::id());

    unsafe {
        // Create the file path as C string
        let path_cstr = std::ffi::CString::new(hugetlb_path.clone())
            .map_err(|e| format!("CString error: {}", e))?;

        // Open/create file on hugetlbfs
        let fd = libc::open(
            path_cstr.as_ptr(),
            libc::O_CREAT | libc::O_RDWR,
            0o644,
        );
        if fd < 0 {
            let err = std::io::Error::last_os_error();
            return Err(format!(
                "Cannot create file on /dev/hugepages ({}). Fix: sudo chmod 1777 /dev/hugepages",
                err
            ));
        }

        // Set the file size (this reserves the huge pages)
        if libc::ftruncate(fd, actual_size as libc::off_t) != 0 {
            let err = std::io::Error::last_os_error();
            libc::close(fd);
            let _ = fs::remove_file(&hugetlb_path);
            return Err(format!("ftruncate failed: {}", err));
        }

        // mmap the file (no MAP_ANONYMOUS since it's file-backed)
        let ptr = libc::mmap(
            std::ptr::null_mut(),
            actual_size,
            libc::PROT_READ | libc::PROT_WRITE,
            libc::MAP_SHARED,
            fd,
            0,
        );

        if ptr == libc::MAP_FAILED {
            let err = std::io::Error::last_os_error();
            libc::close(fd);
            let _ = fs::remove_file(&hugetlb_path);
            return Err(format!("mmap on hugetlbfs failed: {}", err));
        }

        // Touch each huge page to ensure it's resident
        let slice = std::slice::from_raw_parts_mut(ptr as *mut u8, actual_size);
        for chunk in slice.chunks_mut(huge_page_size) {
            if !chunk.is_empty() { chunk[0] = 1; }
        }

        // Unlink the file so it's automatically cleaned up on exit
        // (the mmap keeps the memory alive)
        let _ = fs::remove_file(&hugetlb_path);
        libc::close(fd);

        Ok(format!(
            "Huge-pages mode (hugetlbfs): {} pages × 2MB = {} MB locked (NO SUDO needed)",
            num_pages, actual_size / 1024 / 1024
        ))
    }
}

pub fn get_total_memory_bytes() -> u64 {
    fs::read_to_string("/proc/meminfo").ok()
        .and_then(|s| s.lines().find(|l| l.starts_with("MemTotal:")).map(|l| l.to_string()))
        .and_then(|l| l.split_whitespace().nth(1).and_then(|v| v.parse::<u64>().ok()))
        .map(|kb| kb * 1024).unwrap_or(0)
}

pub fn get_available_memory_bytes() -> u64 {
    fs::read_to_string("/proc/meminfo").ok()
        .and_then(|s| s.lines().find(|l| l.starts_with("MemAvailable:")).map(|l| l.to_string()))
        .and_then(|l| l.split_whitespace().nth(1).and_then(|v| v.parse::<u64>().ok()))
        .map(|kb| kb * 1024).unwrap_or(0)
}
MEM_EOF

echo "Build..."
cargo build --release || { echo "HIBA: build sikertelen"; exit 1; }
echo
echo "=== KESZ ==="
echo "Teszt (SUDO NELKUL):"
echo "  ./target/release/secure-passgen --memory-first --huge-pages -c -n -s -l 16 --count 500000 -o /dev/shm/hp3.csv"

# ===== END OF SCRIPT v1.0 =====
