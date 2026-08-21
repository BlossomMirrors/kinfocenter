#!/usr/bin/bash
set -eou pipefail

FEDORA_VERSION="${1:-44}"
PINNED_VERSION="6.7.3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
CACHE_DIR="${SCRIPT_DIR}/cache"

rm -rf build cache

patch_file_list() {
    # Sort by basename (the zero-padded number prefix) so patches apply in order.
    find "${SCRIPT_DIR}/patches" -name '*.patch' -printf '%f\t%p\n' | sort | cut -f2-
}

fetch_srpm() {
    local tags
    if [[ "${FEDORA_VERSION}" == "rawhide" ]]; then
        tags=("rawhide")
    else
        tags=("f${FEDORA_VERSION}-updates" "f${FEDORA_VERSION}")
    fi

    # Pin to a known-good release instead of tracking whatever koji currently
    # considers latest, so patches don't silently rot against a newer upstream.
    local nvr tag
    for tag in "${tags[@]}"; do
        nvr="$(koji list-tagged "${tag}" kinfocenter 2>/dev/null \
            | awk '{print $1}' \
            | grep -E "^kinfocenter-${PINNED_VERSION//./\\.}-[0-9]+\." \
            | sort -t- -k3 -n | tail -1)"
        [[ -n "${nvr}" ]] && break
    done

    if [[ -z "${nvr}" ]]; then
        echo "==> No kinfocenter-${PINNED_VERSION} build found in ${tags[*]}" >&2
        exit 1
    fi

    local cached="${CACHE_DIR}/${nvr}.src.rpm"
    if [[ -f "${cached}" ]]; then
        echo "==> Using cached SRPM: ${nvr}.src.rpm" >&2
    else
        echo "==> Fetching ${nvr}.src.rpm..." >&2
        mkdir -p "${CACHE_DIR}"
        (cd "${CACHE_DIR}" && koji download-build --arch=src "${nvr}") >&2
    fi
    cp "${cached}" "${BUILD_DIR}/${nvr}.src.rpm"
    echo "${nvr}.src.rpm"
}

apply_patches_to_spec() {
    local spec="$1"
    local patch_files=()
    while IFS= read -r f; do
        patch_files+=("$f")
    done < <(patch_file_list)

    if [[ "${#patch_files[@]}" -eq 0 ]]; then
        echo "==> No patches found, skipping"
        return
    fi

    local names=()
    for patch in "${patch_files[@]}"; do
        local name
        name="$(basename "${patch}")"
        # Strip mbox transport headers (everything up to the first blank line).
        # What remains is the email body: commit message + --- + diff, which
        # both /usr/bin/patch and git apply handle correctly.
        python3 -c "
import sys
content = open(sys.argv[1]).read()
idx = content.find('\n\n')
sys.stdout.write(content[idx + 2:] if idx >= 0 else content)
" "${patch}" > "${BUILD_DIR}/rpmbuild/SOURCES/${name}"
        names+=("${name}")
    done

    # Only inject Patch9000: declarations — the spec's own patching loop
    # (%autosetup -p1 / %autopatch) picks them up and applies them in order.
    python3 - "${spec}" "${names[@]}" <<'PYEOF'
import sys, re

spec_path = sys.argv[1]
patch_names = sys.argv[2:]

with open(spec_path) as f:
    lines = f.readlines()

patch_decls = [f'Patch{9000 + j}: {name}\n' for j, name in enumerate(patch_names)]

# Find the last Patch\d+: line in the spec header (before any % section)
last_patch_idx = -1
for i, line in enumerate(lines):
    if line.startswith('%'):
        break
    if re.match(r'^Patch\d+:', line):
        last_patch_idx = i

if last_patch_idx >= 0:
    lines = lines[:last_patch_idx + 1] + patch_decls + lines[last_patch_idx + 1:]
else:
    for i, line in enumerate(lines):
        if line.startswith('%description'):
            lines = lines[:i] + patch_decls + lines[i:]
            break

with open(spec_path, 'w') as f:
    f.writelines(lines)

print(f"Added {len(patch_names)} Patch declaration(s) to spec header")
PYEOF
}

main() {
    rm -rf "${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}/rpmbuild/"{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

    cd "${BUILD_DIR}"
    local srpm
    srpm="$(fetch_srpm)"
    echo "==> Installing SRPM: ${srpm}"
    rpm -ivh "${srpm}" --define "_topdir ${BUILD_DIR}/rpmbuild"

    local spec="${BUILD_DIR}/rpmbuild/SPECS/kinfocenter.spec"
    apply_patches_to_spec "${spec}"

    echo "==> Installing build dependencies..."
    sudo dnf builddep -y --no-best "${spec}"

    echo "==> Building kinfocenter RPMs..."
    rpmbuild -ba "${spec}" \
        --define "_topdir ${BUILD_DIR}/rpmbuild" \
        2>&1 | tee "${BUILD_DIR}/build.log"

    echo "==> Done. RPMs are in ${BUILD_DIR}/rpmbuild/RPMS/"
}

main
