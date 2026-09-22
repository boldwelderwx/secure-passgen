# -*- coding: utf-8 -*-
import subprocess
from pathlib import Path

print("=== README TARTALOM ELEMZO ===\n")

content = Path("README.md").read_text(encoding='utf-8')
lines = content.split('\n')

print(f"Osszes sor: {len(lines)}")
print("\n--- ELSO 30 SOR ---")
for i, line in enumerate(lines[:30], 1):
    print(f"{i:3d}: {line[:80]}")

print("\n--- KERESÉS: §1NAME vagy hasonlo ---")
patterns = ["§1NAME", "1. NAME", "§1", "NAME", "SYNOPSIS", "DESCRIPTION"]
for pattern in patterns:
    for i, line in enumerate(lines, 1):
        if pattern in line:
            print(f"[{i:3d}. sor] Tartalmazza: '{pattern}' -> {line[:60]}")
            break
    else:
        print(f"Nincs talalat: '{pattern}'")

print("\n--- KERESÉS: HTML/CSS vége ---")
for i, line in enumerate(lines, 1):
    if "</style>" in line or "</head>" in line:
        print(f"[{i:3d}. sor] HTML/CSS vége: {line[:60]}")
        break

print("\n--- KERESÉS: Első üres sor után tartalom ---")
for i, line in enumerate(lines, 1):
    if line.strip() and not line.startswith('<') and not line.startswith('/*') and len(line) > 20:
        if any(word in line.lower() for word in ['secure-passgen', 'name', 'synopsis', 'description']):
            print(f"[{i:3d}. sor] Valoszinuleg itt kezdodik a tartalom: {line[:80]}")
            break
