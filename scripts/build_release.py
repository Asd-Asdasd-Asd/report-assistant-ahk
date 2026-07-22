#!/usr/bin/env python3
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
OUTPUT = ROOT / "release" / "report_assistant.ahk"

ORDER = [
    "app_metadata.ahk",
    "app_config.ahk",
    "app_startup.ahk",
    "Lib/UIA.ahk",
    "config.example.ahk",
    "window_guard.ahk",
    "utils.ahk",
    "clipboard_html.ahk",
    "medex_color_reset_logic.ahk",
    "medex_candidate_g_logic.ahk",
    "machine_profile.ahk",
    "diagnostics.ahk",
    "adapters/medex_report_editor.ahk",
    "medex_calibration.ahk",
    "report_editor.ahk",
    "viewer_actions.ahk",
    "feature_model.ahk",
    "hotstring_model.ahk",
    "hotstring_config.ahk",
    "config_reconciliation.ahk",
    "config_bootstrap.ahk",
    "hotstring_normalization.ahk",
    "hotstring_registration.ahk",
    "hotstrings.ahk",
    "feature_config.ahk",
    "feature_normalization.ahk",
    "hotkey_registration.ahk",
    "global_hjkl_arrows.ahk",
    "features.ahk",
    "tray_menu.ahk",
    "main.ahk",
]


UIA_STANDALONE_ENTRYPOINT = (
    "if !A_IsCompiled && A_LineFile = A_ScriptFullPath\n"
    "    UIA.Viewer()\n"
)

RELEASE_DIRECTIVES = (
    "#Requires AutoHotkey v2.0",
    "#SingleInstance Off",
    "#Warn",
)

VERSION_PATTERN = re.compile(
    r"^(?P<major>0|[1-9]\d*)\."
    r"(?P<minor>0|[1-9]\d*)\."
    r"(?P<patch>0|[1-9]\d*)"
    r"(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$"
)


def strip_leading_component_bom(text: str) -> str:
    """Remove only a component's leading U+FEFF byte-order mark."""
    return text[1:] if text.startswith("\ufeff") else text


def read_component(path: Path) -> str:
    return strip_leading_component_bom(path.read_text(encoding="utf-8"))


def extract_app_version(metadata: str) -> str:
    version_marker = 'static Version := "'
    if version_marker not in metadata:
        raise ValueError("AppMetadata.Version was not found")
    version = metadata.split(version_marker, 1)[1].split('"', 1)[0]
    if not VERSION_PATTERN.fullmatch(version):
        raise ValueError(f"AppMetadata.Version is not valid semantic version: {version}")
    return version


def windows_file_version(version: str) -> str:
    match = VERSION_PATTERN.fullmatch(version)
    if match is None:
        raise ValueError(f"Application version is not valid semantic version: {version}")
    return ".".join(
        (match.group("major"), match.group("minor"), match.group("patch"), "0")
    )


def stamp_source_revision(metadata: str, source_revision: str) -> str:
    if not source_revision or any(char in source_revision for char in '"\r\n'):
        raise ValueError("Source revision is invalid")
    revision_pattern = re.compile(r'static SourceRevision := "[^"]*"')
    if not revision_pattern.search(metadata):
        raise ValueError("AppMetadata.SourceRevision was not found")
    return revision_pattern.sub(
        f'static SourceRevision := "{source_revision}"', metadata, count=1
    )


def resolve_source_revision(root: Path = ROOT) -> str:
    try:
        revision = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=root,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        dirty = subprocess.run(
            ["git", "status", "--porcelain", "--untracked-files=no"],
            cwd=root,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    except (FileNotFoundError, subprocess.CalledProcessError):
        return "UNSTAMPED"
    if not revision:
        return "UNSTAMPED"
    return f"{revision}-dirty" if dirty else revision


def prepare_source(text: str, relative_name: str) -> str:
    if relative_name == "Lib/UIA.ahk":
        if UIA_STANDALONE_ENTRYPOINT not in text:
            raise ValueError("UIA standalone entrypoint was not found")
        text = text.replace(UIA_STANDALONE_ENTRYPOINT, "", 1)

    lines = []
    for line in text.splitlines():
        if line.lstrip().lower().startswith("#include"):
            continue
        if line.strip().lower() in {directive.lower() for directive in RELEASE_DIRECTIVES}:
            continue
        lines.append(line.rstrip())
    return "\n".join(lines).rstrip() + "\n"


def build_release_text(
    source_dir: Path = SRC,
    order: list[str] = ORDER,
    timestamp: str | None = None,
    source_revision: str = "UNSTAMPED",
) -> str:
    if timestamp is None:
        timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    metadata = read_component(source_dir / "app_metadata.ahk")
    version = extract_app_version(metadata)
    file_version = windows_file_version(version)

    parts = [
        "; Generated file. Edit src/*.ahk instead.",
        f"; Application version: {version}",
        f"; Source revision: {source_revision}",
        f"; Generated at: {timestamp}",
        f";@Ahk2Exe-SetFileVersion {file_version}",
        f";@Ahk2Exe-SetProductVersion {version}",
        ";@Ahk2Exe-SetName MedEx Report Assistant",
        "",
        *RELEASE_DIRECTIVES,
        "",
    ]

    for name in order:
        path = source_dir / name
        if not path.exists():
            raise FileNotFoundError(f"Missing source file: {path}")

        try:
            display_path = path.relative_to(ROOT)
        except ValueError:
            display_path = path
        print(f"Adding {display_path}")
        parts.append(f"; --- BEGIN {name} ---")
        component = read_component(path)
        if name == "app_metadata.ahk":
            component = stamp_source_revision(component, source_revision)
        parts.append(prepare_source(component, name))
        parts.append(f"; --- END {name} ---")
        parts.append("")

    release_text = "\n".join(parts)
    if "\ufeff" in release_text:
        raise ValueError("Generated release contains an embedded U+FEFF character")
    return release_text


def main() -> int:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    source_revision = resolve_source_revision()
    release_text = build_release_text(source_revision=source_revision)
    OUTPUT.write_bytes(release_text.encode("utf-8"))

    written_text = OUTPUT.read_bytes().decode("utf-8")
    bom_count = written_text.count("\ufeff")
    if bom_count != 0:
        raise ValueError(f"Generated release BOM scan failed: count={bom_count}")

    print(f"Wrote {OUTPUT.relative_to(ROOT)}")
    print(f"Source revision: {source_revision}")
    print(f"Embedded U+FEFF count: {bom_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
