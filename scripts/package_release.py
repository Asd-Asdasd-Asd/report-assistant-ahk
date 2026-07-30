#!/usr/bin/env python3
"""Create one validated, versioned release ZIP from the fixed publish staging."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
from pathlib import Path
import re
import shutil
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BUILD_ROOT = (ROOT.parent / "report-assistant-build").resolve()
REQUIRED_FILE_NAMES = (
    "麦旋风.exe",
    "版本信息.md",
    "更新说明.md",
    "首次使用.md",
    "配置指南.md",
)
VERSION_PATTERN = re.compile(
    r"^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)"
    r"(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$"
)
MANAGED_ARTIFACT_PATTERN = re.compile(
    r"^麦旋风-v"
    r"(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)"
    r"(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?"
    r"\.(?:zip|sha256\.txt)$"
)


@dataclass(frozen=True)
class ReleaseMetadata:
    version: str
    revision: str


@dataclass(frozen=True)
class PackageResult:
    version: str
    revision: str
    zip_path: Path
    hash_path: Path
    sha256: str


def read_release_metadata(path: Path) -> ReleaseMetadata:
    text = path.read_text(encoding="utf-8-sig")
    version_match = re.search(r"(?m)^-\s*版本：(?P<value>\S+)\s*$", text)
    if version_match is None:
        raise ValueError("版本信息.md does not contain a version")
    version = version_match.group("value")
    if VERSION_PATTERN.fullmatch(version) is None:
        raise ValueError("版本信息.md does not contain a valid semantic version")

    revision_match = re.search(
        r"(?m)^-\s*源代码版本：(?P<value>\S+)\s*$",
        text,
    )
    if revision_match is None:
        raise ValueError("版本信息.md does not contain a source revision")
    revision = revision_match.group("value")
    if (
        revision in {"未标记", "UNSTAMPED"}
        or revision.endswith("-dirty")
        or "仅用于测试" in text
    ):
        raise ValueError(f"refusing to package a non-release build: {revision}")
    return ReleaseMetadata(version=version, revision=revision)


def assert_nonempty_file(path: Path, description: str) -> None:
    if not path.is_file():
        raise FileNotFoundError(f"{description} was not found: {path}")
    if path.stat().st_size <= 0:
        raise ValueError(f"{description} is empty: {path}")


def expected_archive_names(package_root_name: str) -> tuple[str, ...]:
    return tuple(
        f"{package_root_name}/{file_name}"
        for file_name in REQUIRED_FILE_NAMES
    )


def validate_zip(zip_path: Path, package_root_name: str) -> None:
    assert_nonempty_file(zip_path, "release ZIP")
    expected = set(expected_archive_names(package_root_name))
    with zipfile.ZipFile(zip_path, "r") as archive:
        files = [info for info in archive.infolist() if not info.is_dir()]
        actual = {info.filename for info in files}
        if actual != expected or len(files) != len(expected):
            raise ValueError(
                "release ZIP content does not match the five-file allowlist"
            )
        for info in files:
            if info.file_size <= 0:
                raise ValueError(
                    f"release ZIP contains an empty file: {info.filename}"
                )
        bad_member = archive.testzip()
        if bad_member is not None:
            raise ValueError(f"release ZIP CRC failed: {bad_member}")


def recover_interrupted_promotion(dist: Path, backup: Path) -> None:
    if not backup.is_dir():
        return
    for source in backup.iterdir():
        if not source.is_file():
            continue
        destination = dist / source.name
        if not destination.exists():
            source.replace(destination)
    shutil.rmtree(backup)


def restore_previous_packages(
    dist: Path,
    backup: Path,
    final_zip: Path,
    final_hash: Path,
    new_final_zip_created: bool,
    new_final_hash_created: bool,
) -> None:
    if new_final_zip_created:
        final_zip.unlink(missing_ok=True)
    if new_final_hash_created:
        final_hash.unlink(missing_ok=True)
    if not backup.is_dir():
        return
    for source in backup.iterdir():
        if not source.is_file():
            continue
        destination = dist / source.name
        destination.unlink(missing_ok=True)
        source.replace(destination)
    shutil.rmtree(backup)


def package_release(build_root: Path = DEFAULT_BUILD_ROOT) -> PackageResult:
    build_root = build_root.resolve()
    publish = build_root / "publish"
    dist = build_root / "dist"
    backup = dist / ".package-previous"
    if not publish.is_dir():
        raise FileNotFoundError(
            f"publish directory was not found; run Build EXE.cmd first: {publish}"
        )
    for file_name in REQUIRED_FILE_NAMES:
        assert_nonempty_file(
            publish / file_name,
            f"required publish file {file_name!r}",
        )

    metadata = read_release_metadata(publish / "版本信息.md")
    package_root_name = f"麦旋风-v{metadata.version}"
    dist.mkdir(parents=True, exist_ok=True)
    recover_interrupted_promotion(dist, backup)

    building_zip = dist / f"{package_root_name}.building.zip"
    building_hash = dist / f"{package_root_name}.building.sha256.txt"
    final_zip = dist / f"{package_root_name}.zip"
    final_hash = dist / f"{package_root_name}.sha256.txt"
    building_zip.unlink(missing_ok=True)
    building_hash.unlink(missing_ok=True)

    promotion_started = False
    new_final_zip_created = False
    new_final_hash_created = False
    staging_root = Path(
        tempfile.mkdtemp(prefix="package-staging-", dir=build_root)
    )
    try:
        package_directory = staging_root / package_root_name
        package_directory.mkdir()
        for file_name in REQUIRED_FILE_NAMES:
            shutil.copy2(publish / file_name, package_directory / file_name)

        with zipfile.ZipFile(
            building_zip,
            "w",
            compression=zipfile.ZIP_DEFLATED,
            compresslevel=9,
        ) as archive:
            for file_name in REQUIRED_FILE_NAMES:
                archive.write(
                    package_directory / file_name,
                    arcname=f"{package_root_name}/{file_name}",
                )
        validate_zip(building_zip, package_root_name)
        sha256 = hashlib.sha256(building_zip.read_bytes()).hexdigest()
        building_hash.write_bytes(
            (
                f"{sha256}  {package_root_name}.zip\r\n"
            ).encode("utf-8")
        )
        assert_nonempty_file(building_hash, "temporary SHA256 file")

        backup.mkdir()
        promotion_started = True
        old_managed = sorted(
            (
                path
                for path in dist.iterdir()
                if path.is_file()
                and MANAGED_ARTIFACT_PATTERN.fullmatch(path.name)
            ),
            key=lambda path: path.name,
        )
        for path in old_managed:
            path.replace(backup / path.name)

        building_zip.replace(final_zip)
        new_final_zip_created = True
        building_hash.replace(final_hash)
        new_final_hash_created = True
        validate_zip(final_zip, package_root_name)
        assert_nonempty_file(final_hash, "final SHA256 file")
        shutil.rmtree(backup)
        promotion_started = False
        return PackageResult(
            version=metadata.version,
            revision=metadata.revision,
            zip_path=final_zip,
            hash_path=final_hash,
            sha256=sha256,
        )
    except Exception:
        if promotion_started:
            restore_previous_packages(
                dist,
                backup,
                final_zip,
                final_hash,
                new_final_zip_created,
                new_final_hash_created,
            )
        raise
    finally:
        building_zip.unlink(missing_ok=True)
        building_hash.unlink(missing_ok=True)
        shutil.rmtree(staging_root, ignore_errors=True)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create the validated versioned MedEx release ZIP."
    )
    parser.add_argument(
        "--build-root",
        type=Path,
        default=DEFAULT_BUILD_ROOT,
        help="External report-assistant-build directory.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        result = package_release(args.build_root)
    except Exception as error:
        print(f"PACKAGING FAILED: {error}")
        return 1
    print("================================")
    print("Release package created.")
    print(f"Version:  {result.version}")
    print(f"Revision: {result.revision}")
    print(f"ZIP:      {result.zip_path}")
    print(f"SHA256:   {result.sha256}")
    print("================================")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
