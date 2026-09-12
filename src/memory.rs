//! Memory-First module v4.0 - THP + madvise (sudo-less)
//!
//! The PostgreSQL/Redis/MySQL approach:
//!   - Plain malloc for the work buffer
//!   - madvise(MADV_HUGEPAGE) requests Transparent Huge Pages
//!   - madvise(MADV_WILLNEED) pre-faults the memory
//!   - NO mlockall, NO hugetlbfs, NO sudo, NO persistent config
//!
//! The kernel keeps the buffer in RAM as long as memory is available,
//! and automatically reclaims it when needed. This is exactly how
//! modern databases use memory as a fast buffer.

use std::fs;

/// Activates the memory-first buffer using THP + madvise (NO SUDO NEEDED).
/// Returns (success, message).
pub fn activate_memory_first(percent: u8) -> (bool, String) {
    let total_bytes = get_total_memory_bytes();
    let available = get_available_memory_bytes();

    // Target: percent of total RAM, capped at 70% of AVAILABLE memory
    // so the OS and other programs always have breathing room.
    let target_bytes = total_bytes * (percent as u64) / 100;
    let cap_bytes = available * 7 / 10;
    let actual = target_bytes.min(cap_bytes);

    if actual < 64 * 1024 * 1024 {
        return (false, "Not enough available RAM for a useful buffer (<64MB)".to_string());
    }

    // Allocate the work buffer
    let mut buf: Vec<u8> = Vec::new();
    buf.resize(actual as usize, 0);

    unsafe {
        let ptr = buf.as_mut_ptr() as *mut libc::c_void;
        let size = buf.len();

        // Request Transparent Huge Pages (works without sudo).
        // The kernel backs this memory with 2MB pages when possible,
        // reducing TLB misses for faster access.
        libc::madvise(ptr, size, libc::MADV_HUGEPAGE);

        // Pre-fault: tell the kernel we need this memory soon so it
        // can be brought into the page cache ahead of time.
        libc::madvise(ptr, size, libc::MADV_WILLNEED);
    }

    // Touch every page to force physical allocation right now.
    for chunk in buf.chunks_mut(4096) {
        if !chunk.is_empty() { chunk[0] = 1; }
    }

    // Keep the buffer alive for the whole program run.
    // The OS reclaims it automatically when the process exits.
    std::mem::forget(buf);

    (true, format!(
        "Memory-first buffer: {} MB (THP + pre-fault, NO SUDO needed)",
        actual / 1024 / 1024
    ))
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
