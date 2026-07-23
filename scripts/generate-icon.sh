#!/bin/bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
source_svg="${repo_root}/assets/icon/source/medex-icon.svg"
generated_dir="${repo_root}/assets/icon/generated"
ico_path="${generated_dir}/medex-icon.ico"
temporary_ico="${generated_dir}/medex-icon.building.ico"
sizes=(16 20 24 32 40 48 64 128 256)

require_command() {
    local command_name="$1"
    local package_name="$2"

    if ! command -v "${command_name}" >/dev/null 2>&1; then
        printf 'ERROR: Required command "%s" was not found.\n' "${command_name}" >&2
        printf 'Install it with: brew install %s\n' "${package_name}" >&2
        exit 1
    fi
}

require_command "rsvg-convert" "librsvg"
require_command "magick" "imagemagick"

if [[ ! -f "${source_svg}" ]]; then
    printf 'ERROR: Icon source SVG was not found: %s\n' "${source_svg}" >&2
    exit 1
fi

mkdir -p "${generated_dir}"
rm -f "${temporary_ico}"

png_paths=()
for size in "${sizes[@]}"; do
    png_path="${generated_dir}/medex-icon-${size}.png"
    rsvg-convert \
        --format=png \
        --width="${size}" \
        --height="${size}" \
        --output="${png_path}" \
        "${source_svg}"
    png_paths+=("${png_path}")
done

trap 'rm -f "${temporary_ico}"' EXIT
magick "${png_paths[@]}" "${temporary_ico}"

if [[ ! -s "${temporary_ico}" ]]; then
    printf 'ERROR: ImageMagick did not create a valid ICO file.\n' >&2
    exit 1
fi

mv -f "${temporary_ico}" "${ico_path}"
trap - EXIT

printf 'Generated icon assets:\n'
for png_path in "${png_paths[@]}"; do
    printf '  %s\n' "${png_path#"${repo_root}/"}"
done
printf '  %s\n' "${ico_path#"${repo_root}/"}"
