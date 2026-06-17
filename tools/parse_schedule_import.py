#!/usr/bin/env python3
"""Parse 卡司排期汇总表.md and generate lib/data/schedule_import_bundle.dart."""
import re
from pathlib import Path

YEAR = 2026
MONTH_MAP = {f"{i}月": f"{i:02d}" for i in range(1, 13)}


def parse_date(raw: str) -> str:
    """Convert '8月1日' -> '2026-08-01'."""
    m = re.match(r"(\d{1,2})月(\d{1,2})日", raw.strip())
    if not m:
        raise ValueError(f"Unknown date format: {raw}")
    month = int(m.group(1))
    day = int(m.group(2))
    return f"{YEAR}-{month:02d}-{day:02d}"


def normalize_time(raw: str) -> str:
    """Keep HH:MM."""
    return raw.strip()


def parse_markdown(path: Path):
    text = path.read_text(encoding="utf-8")
    lines = [ln.rstrip() for ln in text.splitlines()]
    shows = []
    current = None

    title_re = re.compile(r"^《([^》]+)》(.+)$")
    for ln in lines:
        m = title_re.match(ln.strip())
        if m:
            if current is not None:
                shows.append(current)
            current = {
                "name": m.group(1).strip(),
                "theater": m.group(2).strip(),
                "performances": [],
                "roles": [],
            }
            continue

        if current is None:
            continue

        if ln.startswith("|") and "日期" in ln and "时间" in ln:
            header_cells = [c.strip() for c in ln.split("|")[1:-1]]
            current["roles"] = header_cells[2:]
            continue

        if ln.startswith("|") and current["roles"]:
            if re.match(r"^\|[\s\-|]+\|$", ln):
                continue
            cells = [c.strip() for c in ln.split("|")[1:-1]]
            if len(cells) < 2 + len(current["roles"]):
                continue
            date_raw, time_raw = cells[0], cells[1]
            cast = []
            for role, actor in zip(current["roles"], cells[2:]):
                if actor:
                    cast.append({"role": role, "actor": actor})
            current["performances"].append({
                "date": parse_date(date_raw),
                "time": normalize_time(time_raw),
                "cast": cast,
            })

    if current is not None:
        shows.append(current)

    # Strip helper field
    for s in shows:
        s.pop("roles", None)
    return shows


def escape_dart_string(s: str) -> str:
    return s.replace("\\", "\\\\").replace("'", "\\'")


def generate_dart(shows, out_path: Path):
    lines = [
        "// GENERATED FILE - do not edit by hand",
        "// Generated from 卡司排期汇总表.md",
        "",
        "class ScheduleImportCast {",
        "  final String role;",
        "  final String actor;",
        "  const ScheduleImportCast({required this.role, required this.actor});",
        "}",
        "",
        "class ScheduleImportPerformance {",
        "  final String date; // YYYY-MM-DD",
        "  final String time; // HH:MM",
        "  final List<ScheduleImportCast> cast;",
        "  const ScheduleImportPerformance({",
        "    required this.date,",
        "    required this.time,",
        "    required this.cast,",
        "  });",
        "}",
        "",
        "class ScheduleImportShow {",
        "  final String name;",
        "  final String theater;",
        "  final List<ScheduleImportPerformance> performances;",
        "  const ScheduleImportShow({",
        "    required this.name,",
        "    required this.theater,",
        "    required this.performances,",
        "  });",
        "}",
        "",
        "const List<ScheduleImportShow> scheduleImportBundle = [",
    ]
    for show in shows:
        lines.append("  ScheduleImportShow(")
        lines.append(f"    name: '{escape_dart_string(show['name'])}',")
        lines.append(f"    theater: '{escape_dart_string(show['theater'])}',")
        lines.append("    performances: [")
        for perf in show["performances"]:
            lines.append("      ScheduleImportPerformance(")
            lines.append(f"        date: '{perf['date']}',")
            lines.append(f"        time: '{perf['time']}',")
            lines.append("        cast: [")
            for cast in perf["cast"]:
                lines.append("          ScheduleImportCast(")
                lines.append(f"            role: '{escape_dart_string(cast['role'])}',")
                lines.append(f"            actor: '{escape_dart_string(cast['actor'])}',")
                lines.append("          ),")
            lines.append("        ],")
            lines.append("      ),")
        lines.append("    ],")
        lines.append("  ),")
    lines.append("];")
    out_path.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parent.parent
    md_path = repo_root / "卡司排期汇总表.md"
    out_path = repo_root / "lib" / "data" / "schedule_import_bundle.dart"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    shows = parse_markdown(md_path)
    generate_dart(shows, out_path)
    print(f"Generated {out_path} with {len(shows)} shows and "
          f"{sum(len(s['performances']) for s in shows)} performances.")
