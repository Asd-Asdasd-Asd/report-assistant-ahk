#!/usr/bin/env python3
"""Generate release/report_assistant.ahk and assets/publish/版本信息.md."""

from __future__ import annotations

import argparse
from datetime import datetime, timedelta, timezone
from pathlib import Path
import re
import subprocess

try:
    from scripts import ahk_bundle
except ModuleNotFoundError:  # executed directly from scripts/
    import ahk_bundle


ROOT = ahk_bundle.ROOT
SRC = ROOT / "src"
OUTPUT = ROOT / "release" / "report_assistant.ahk"
VERSION_INFO_OUTPUT = ROOT / "assets" / "publish" / "版本信息.md"
SHANGHAI_TIMEZONE = timezone(timedelta(hours=8))
GENERATED_METADATA_PATHS = (
    "release/report_assistant.ahk",
    "assets/publish/版本信息.md",
)

ORDER = [
    "app_metadata.ahk",
    "app_config.ahk",
    "automation_diagnostics.ahk",
    "app_startup.ahk",
    "Lib/UIA.ahk",
    "utils.ahk",
    "visual_feedback.ahk",
    "clipboard_html.ahk",
    "measurement_model.ahk",
    "measurement_parser.ahk",
    "measurement_clipboard.ahk",
    "mxnm_config_geometry_provider.ahk",
    "mxnm_config_path_cache.ahk",
    "context_measurement_provider.ahk",
    "mxnm_measurement_target_resolver.ahk",
    "mxnm_context_target_session.ahk",
    "mxnm_measurement_provider.ahk",
    "mxnm_annotation_cleaner.ahk",
    "mxnm_viewer_tool_commands.ahk",
    "medex_color_reset_logic.ahk",
    "medex_candidate_g_logic.ahk",
    "machine_profile.ahk",
    "diagnostics.ahk",
    "adapters/medex_report_editor.ahk",
    "medex_calibration.ahk",
    "report_editor.ahk",
    "feature_model.ahk",
    "hotstring_model.ahk",
    "hotstring_config.ahk",
    "template_renderer.ahk",
    "hotstring_normalization.ahk",
    "config_reconciliation.ahk",
    "mxnm_montage.ahk",
    "hotstring_config_migration.ahk",
    "hotstring_config_editor.ahk",
    "config_bootstrap.ahk",
    "hotstring_registration.ahk",
    "hotstrings.ahk",
    "feature_config.ahk",
    "feature_normalization.ahk",
    "hotkey_registration.ahk",
    "global_hjkl_arrows.ahk",
    "viewer_tool_hotkeys.ahk",
    "report_image_caption.ahk",
    "features.ahk",
    "settings_ui.ahk",
    "tray_menu.ahk",
    "main.ahk",
]


UIA_STANDALONE_ENTRYPOINT = ahk_bundle.UIA_STANDALONE_ENTRYPOINT
RELEASE_DIRECTIVES = ahk_bundle.RELEASE_DIRECTIVES

VERSION_PATTERN = re.compile(
    r"^(?P<major>0|[1-9]\d*)\."
    r"(?P<minor>0|[1-9]\d*)\."
    r"(?P<patch>0|[1-9]\d*)"
    r"(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$"
)


strip_leading_component_bom = ahk_bundle.strip_bom
read_component = ahk_bundle.read_component


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


def stamp_build_date(metadata: str, build_date: str) -> str:
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", build_date):
        raise ValueError(f"Build date is invalid: {build_date}")
    build_date_pattern = re.compile(r'static BuildDate := "[^"]*"')
    if not build_date_pattern.search(metadata):
        raise ValueError("AppMetadata.BuildDate was not found")
    return build_date_pattern.sub(
        f'static BuildDate := "{build_date}"', metadata, count=1
    )


def short_source_revision(source_revision: str) -> str:
    if source_revision == "UNSTAMPED":
        return "未标记"
    dirty_suffix = "-dirty"
    is_dirty = source_revision.endswith(dirty_suffix)
    revision = (
        source_revision[: -len(dirty_suffix)]
        if is_dirty
        else source_revision
    )
    short_revision = revision[:7]
    return f"{short_revision}{dirty_suffix if is_dirty else ''}"


def build_version_info_text(
    version: str,
    build_date: str,
    source_revision: str,
) -> str:
    lines = [
        "# 麦旋风版本信息",
        "",
        f"- 版本：{version}",
        f"- 构建日期：{build_date}",
        f"- 源代码版本：{short_source_revision(source_revision)}",
    ]
    if source_revision.endswith("-dirty"):
        lines.extend(
            [
                "",
                "> ⚠ 此构建包含未提交修改，仅用于测试。",
            ]
        )
    elif source_revision == "UNSTAMPED":
        lines.extend(
            [
                "",
                "> ⚠ 当前环境没有 Git 元数据，源代码版本未标记，仅用于临时测试。",
            ]
        )
    return "\n".join(lines) + "\n"


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
            [
                "git",
                "status",
                "--porcelain",
                "--untracked-files=no",
                "--",
                ".",
                *(
                    f":(exclude){path}"
                    for path in GENERATED_METADATA_PATHS
                ),
            ],
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
    if ahk_bundle.is_uia_component(relative_name):
        text = ahk_bundle.strip_uia_entrypoint(text)
    return ahk_bundle.strip_includes_and_directives(
        text, RELEASE_DIRECTIVES, strip_leading=False
    )


def build_release_text(
    source_dir: Path = SRC,
    order: list[str] = ORDER,
    timestamp: str | None = None,
    source_revision: str = "UNSTAMPED",
    build_date: str = "1970-01-01",
) -> str:
    if timestamp is None:
        timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    metadata = read_component(source_dir / "app_metadata.ahk")
    version = extract_app_version(metadata)
    file_version = windows_file_version(version)

    header = (
        "; Generated file. Edit src/*.ahk instead.",
        f"; Application version: {version}",
        f"; Source revision: {source_revision}",
        f"; Generated at: {timestamp}",
        f";@Ahk2Exe-SetFileVersion {file_version}",
        f";@Ahk2Exe-SetProductVersion {version}",
        ";@Ahk2Exe-SetName MedEx Report Assistant",
    )

    def stamp(component: str, name: str) -> str:
        if name == "app_metadata.ahk":
            component = stamp_source_revision(component, source_revision)
            component = stamp_build_date(component, build_date)
        return component

    def echo(name: str) -> None:
        path = source_dir / name
        try:
            display_path = path.relative_to(ROOT)
        except ValueError:
            display_path = path
        print(f"Adding {display_path}")

    return ahk_bundle.bundle(
        header,
        order,
        root=source_dir,
        directives=RELEASE_DIRECTIVES,
        transform=stamp,
        strip_leading=False,
        label="release",
        missing_message="Missing source file",
        echo=echo,
    )


def write_release_outputs(
    output: Path = OUTPUT,
    version_info_output: Path = VERSION_INFO_OUTPUT,
) -> None:
    output = output.resolve()
    version_info_output = version_info_output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    version_info_output.parent.mkdir(parents=True, exist_ok=True)
    built_at = datetime.now(timezone.utc)
    timestamp = built_at.strftime("%Y-%m-%d %H:%M:%S UTC")
    build_date = built_at.astimezone(SHANGHAI_TIMEZONE).strftime("%Y-%m-%d")
    source_revision = resolve_source_revision()
    metadata = read_component(SRC / "app_metadata.ahk")
    version = extract_app_version(metadata)
    release_text = build_release_text(
        timestamp=timestamp,
        source_revision=source_revision,
        build_date=build_date,
    )
    version_info_text = build_version_info_text(
        version,
        build_date,
        source_revision,
    )
    output.write_bytes(release_text.encode("utf-8"))
    version_info_output.write_bytes(version_info_text.encode("utf-8"))

    written_text = output.read_bytes().decode("utf-8")
    written_version_info = version_info_output.read_bytes().decode("utf-8")
    bom_count = written_text.count("\ufeff")
    if bom_count != 0:
        raise ValueError(f"Generated release BOM scan failed: count={bom_count}")
    if "\ufeff" in written_version_info:
        raise ValueError("Generated version info contains an embedded U+FEFF character")

    print(f"Wrote {output}")
    print(f"Wrote {version_info_output}")
    print(f"Build date: {build_date}")
    print(f"Source revision: {source_revision}")
    if source_revision == "UNSTAMPED":
        print(
            "WARNING: Git metadata is unavailable. "
            "This build is for temporary testing only."
        )
    print(f"Embedded U+FEFF count: {bom_count}")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate the standalone release AHK and version metadata."
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=OUTPUT,
        help="Destination for the generated standalone AHK.",
    )
    parser.add_argument(
        "--version-info-output",
        type=Path,
        default=VERSION_INFO_OUTPUT,
        help="Destination for generated version information.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    write_release_outputs(args.output, args.version_info_output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
