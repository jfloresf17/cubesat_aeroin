#!/usr/bin/env python3
"""Audit the real source fixture; write independent sample reference CSVs.

This is a development/reference check, not the implementation of the MATLAB
downloader. Its fixed 37 s TAI-UTC is used ONLY for the September 2026 fixture;
the MATLAB utility uses MathWorks' leap-aware TT2000 conversion for all dates.
No third-party Python dependencies or network access are needed.
SPDX-License-Identifier: MIT
"""
from __future__ import annotations

import csv
import hashlib
import json
import math
import re
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "planet_ephemerides" / "raw"
OUT = ROOT / "data" / "reference"
DATES = {"20260901": 99, "20260902": 98, "20260903": 97}
IDS = {"24bd", "24d1"}
CATIDS = {"24bd": "58320", "24d1": "58327"}


def check(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def checksum(line: str) -> int:
    return sum(int(c) if c.isdigit() else int(c == "-") for c in line[:68]) % 10


def tle_epoch(raw: str) -> datetime:
    yy = int(raw[:2])
    year = (1900 if yy >= 57 else 2000) + yy
    seconds = (Decimal(raw[2:]) - 1) * 86400
    return datetime(year, 1, 1, tzinfo=timezone.utc) + timedelta(seconds=float(seconds))


def state_epoch_2026(raw: str) -> datetime:
    # J2000 is noon TT, not noon UTC. For this fixture, TT-UTC = 69.184 s.
    seconds = Decimal(raw) - Decimal("69.184")
    result = datetime(2000, 1, 1, 12, tzinfo=timezone.utc) + timedelta(seconds=float(seconds))
    check(result.year == 2026, "Reference converter is restricted to this 2026 fixture")
    return result


def iso(value: datetime) -> str:
    return value.isoformat(timespec="microseconds").replace("+00:00", "Z")


def write_csv(path: Path, rows: list[dict]) -> None:
    check(bool(rows), f"No reference rows for {path.name}")
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    receipts = []
    for path in sorted(RAW.rglob("*.receipt.json")):
        receipt = json.loads(path.read_text())
        source = Path(str(path).removesuffix(".receipt.json"))
        payload = source.read_bytes()
        check(receipt["SHA256"] == hashlib.sha256(payload).hexdigest(), f"Hash mismatch: {source}")
        check(receipt["Bytes"] == len(payload), f"Byte count mismatch: {source}")
        check(receipt["HTTPStatus"] == 200, f"Source not HTTP 200: {source}")
        check(receipt["URL"].startswith("https://ephemerides.planet-labs.com/"), "Unexpected origin")
        receipts.append({"File": source.relative_to(ROOT).as_posix(),
                         "SHA256": receipt["SHA256"], "Bytes": len(payload),
                         "URL": receipt["URL"], "RetrievedUTC": receipt["RetrievedUTC"]})
    check(len(receipts) == 8, "Expected six daily products and two metadata snapshots")

    catalog = {}
    report = RAW / "metadata" / "20261025_source" / "18SPCS_matches_v1.txt"
    for line in report.read_text().splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        fields = re.split(r"\s{2,}", line.strip())
        check(len(fields) == 10, "Unexpected matching-report columns")
        check(fields[0].lower() not in catalog, "Duplicate catalog HWID")
        catalog[fields[0].lower()] = fields
    for hwid, catid in CATIDS.items():
        check(catalog[hwid][3] == catid, f"Unexpected fixture catalog ID for {hwid}")

    selected_tle, selected_states, availability, day_counts = [], [], [], []
    checksums_checked = 0
    for date, expected in DATES.items():
        label = f"{date[:4]}-{date[4:6]}-{date[6:]}"
        tle_path = RAW / "daily" / "2026" / "09" / f"planet_mc_{date}.tle"
        state_path = RAW / "daily" / "2026" / "09" / f"planet_{date}.states"
        tle_lines = tle_path.read_text().splitlines()
        state_lines = state_path.read_text().splitlines()
        check(len(tle_lines) == expected * 3, f"Unexpected TLE count for {date}")
        check(len(state_lines) == expected, f"Unexpected state count for {date}")
        t_by_id, s_by_id = {}, {}
        for i in range(0, len(tle_lines), 3):
            name, line1, line2 = tle_lines[i:i + 3]
            check(name.startswith("0 "), "Expected named TLE in real fixture")
            for line in (line1, line2):
                check(len(line) == 69, "TLE line is not 69 columns")
                check(checksum(line) == int(line[-1]), "Bad source TLE checksum")
                checksums_checked += 1
            check(line1[2:7] == line2[2:7], "Catalog numbers differ between TLE lines")
            hwid = name.split()[-1].lower()
            check(hwid not in t_by_id, "Duplicate daily TLE identity")
            t_by_id[hwid] = (name, line1, line2)
            if hwid in IDS:
                check(name.startswith("0 FLOCK 4Q "), "Wrong selected flock")
                check(line1[2:7] == CATIDS[hwid], "Unexpected selected catalog ID")
                selected_tle.append(dict(Flock="4q", HWID=hwid, ArchiveDate=label,
                    CatalogID=line1[2:7], EpochYYDDD=line1[18:32],
                    EpochUTC=iso(tle_epoch(line1[18:32])), BStar_raw=line1[53:61],
                    Line1=line1, Line2=line2,
                    SourceFile=tle_path.relative_to(ROOT).as_posix()))
        for raw_line in state_lines:
            fields = raw_line.split()
            check(len(fields) == 10, "State row is not ten columns")
            hwid = fields[0].lower()
            check(hwid not in s_by_id, "Duplicate daily state identity")
            values = [float(x) for x in fields[1:]]
            check(all(math.isfinite(x) for x in values[:7]), "Nonfinite epoch/state")
            check(all(x > 0 for x in values[7:]), "Invalid ballistic coefficient")
            s_by_id[hwid] = fields
            if hwid in IDS:
                selected_states.append(dict(Flock="4q", HWID=hwid, ArchiveDate=label,
                    EpochTT_text=fields[1], EpochUTC=iso(state_epoch_2026(fields[1])),
                    X_m=fields[2], Y_m=fields[3], Z_m=fields[4],
                    VX_m_s=fields[5], VY_m_s=fields[6], VZ_m_s=fields[7],
                    DragBC_kg_m2=fields[8], SRPBC_kg_m2=fields[9],
                    SourceFile=state_path.relative_to(ROOT).as_posix()))
        check(t_by_id.keys() == s_by_id.keys(), f"Fixture HWID sets differ for {date}")
        for hwid in sorted(IDS):
            check(hwid in t_by_id and hwid in s_by_id, f"Missing selected HWID {hwid}")
            te = tle_epoch(t_by_id[hwid][1][18:32])
            se = state_epoch_2026(s_by_id[hwid][1])
            availability.append(dict(Flock="4q", HWID=hwid, ArchiveDate=label,
                TLECount=1, StateCount=1, HasBoth=True,
                NativeEpochSeparation_s=f"{(te-se).total_seconds():.6f}"))
        day_counts.append(dict(ArchiveDate=label, TLERecords=expected, StateRecords=expected))

    check(len(selected_tle) == len(selected_states) == len(availability) == 6, "Selection is not six rows")
    check(state_epoch_2026("841560375.184000") ==
          datetime(2026, 9, 1, 18, 45, 6, tzinfo=timezone.utc), "Known UTC reference differs")
    write_csv(OUT / "selected_tle.csv", selected_tle)
    write_csv(OUT / "selected_states.csv", selected_states)
    write_csv(OUT / "availability.csv", availability)
    write_csv(OUT / "source_manifest.csv", receipts)
    for hwid in sorted(IDS):
        folder = OUT / "by_flock" / "4q" / hwid
        t = [row for row in selected_tle if row["HWID"] == hwid]
        s = [row for row in selected_states if row["HWID"] == hwid]
        write_csv(folder / "tle.csv", t)
        write_csv(folder / "states.csv", s)
        tle_text, state_text = [], []
        for date in DATES:
            lines = (RAW / "daily" / "2026" / "09" / f"planet_mc_{date}.tle").read_text().splitlines()
            for i in range(0, len(lines), 3):
                if lines[i].split()[-1].lower() == hwid:
                    tle_text.extend(lines[i:i + 3])
            lines = (RAW / "daily" / "2026" / "09" / f"planet_{date}.states").read_text().splitlines()
            state_text.extend(line for line in lines if line.split()[0].lower() == hwid)
        (folder / "records.tle").write_text("\n".join(tle_text) + "\n")
        (folder / "records.states").write_text("\n".join(state_text) + "\n")
    report = dict(Status="passed", Audit="Independent Python source-fixture audit",
        MATLABExecuted=False, SourceFiles=8, CatalogRows=len(catalog),
        Days=day_counts, TotalTLERecords=294, TotalStateRecords=294,
        TLEChecksumsVerified=checksums_checked, SelectedHWIDs=sorted(IDS),
        SelectedTLERows=6, SelectedStateRows=6, SelectedPairedDays=6,
        ReferenceTimeScope="September 2026 only; TT-UTC=69.184 s")
    (OUT / "audit.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
