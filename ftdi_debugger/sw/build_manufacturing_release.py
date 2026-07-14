#!/usr/bin/env python3
"""Build and verify a deterministic Rev A manufacturing release archive."""

from __future__ import annotations

from pathlib import Path
import argparse
import hashlib
import zipfile


FIXED_ZIP_TIME = (2026, 7, 14, 12, 0, 0)


def sha256(payload: bytes) -> str:
    """Return the lowercase SHA-256 digest for one payload."""
    return hashlib.sha256(payload).hexdigest()


def collect_files(module: Path) -> dict[str, bytes]:
    """Collect generated CAM data and controlled release documents."""
    files: dict[str, bytes] = {}
    manufacturing = module / "build/manufacturing"
    for path in sorted(manufacturing.rglob("*")):
        if path.is_file():
            files[f"manufacturing/{path.relative_to(manufacturing).as_posix()}"] = path.read_bytes()

    controlled = {
        "bom/wasp1_ft2232h_debugger_revA_bom.csv": module / "hw/bom/wasp1_ft2232h_debugger_revA_bom.csv",
        "fabrication/wasp1_ft2232h_debugger_revA_fabrication_notes.md": module / "hw/fabrication/wasp1_ft2232h_debugger_revA_fabrication_notes.md",
        "fabrication/wasp1_ft2232h_debugger_revA_release_checklist.md": module / "hw/fabrication/wasp1_ft2232h_debugger_revA_release_checklist.md",
        "assembly/wasp1_ft2232h_debugger_revA_assembly_notes.md": module / "hw/assembly/wasp1_ft2232h_debugger_revA_assembly_notes.md",
        "reports/ftdi_debugger_revA_pcb_final_drc.rpt": module / "logs/ftdi_debugger_revA_pcb_final_drc.rpt",
        "reports/ftdi_debugger_manufacturing_review_report.md": module / "docs/ftdi_debugger_manufacturing_review_report.md",
        "schematic/wasp1_ft2232h_debugger_revA.pdf": module / "hw/schematic/wasp1_ft2232h_debugger_revA.pdf",
    }
    for archive_name, path in controlled.items():
        if not path.is_file():
            raise AssertionError(f"missing release input: {path}")
        files[archive_name] = path.read_bytes()
    return files


def write_archive(output: Path, files: dict[str, bytes]) -> str:
    """Write sorted entries plus an internal digest manifest and verify them."""
    manifest = "".join(
        f"{sha256(payload)}  {name}\n"
        for name, payload in sorted(files.items())
    ).encode("ascii")
    archived = {**files, "SHA256SUMS.txt": manifest}
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, payload in sorted(archived.items()):
            info = zipfile.ZipInfo(name, date_time=FIXED_ZIP_TIME)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, payload)

    with zipfile.ZipFile(output, "r") as archive:
        if set(archive.namelist()) != set(archived):
            raise AssertionError("release archive entry list changed during write")
        for name, expected in archived.items():
            if archive.read(name) != expected:
                raise AssertionError(f"release archive verification failed: {name}")
    archive_digest = sha256(output.read_bytes())
    output.with_suffix(output.suffix + ".sha256").write_text(
        f"{archive_digest}  {output.name}\n", encoding="ascii"
    )
    return archive_digest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--module", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    files = collect_files(args.module)
    digest = write_archive(args.output, files)
    print(f"PASS manufacturing release archive: {len(files)} controlled payloads")
    print(f"PASS manufacturing release SHA-256: {digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
