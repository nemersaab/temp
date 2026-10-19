#!/bin/bash
# Shared configuration, sourced by every other script. Edit ONLY here.
# (Do not run directly.)

# ROOT is taken from the environment if set (the sbatch job sets it to
# $SLURM_SUBMIT_DIR, because Slurm runs a copy of the script from a spool dir).
ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
DATASET="$(cd "$ROOT/.." && pwd)/vc-exact"

# Flag value passed as:  ./output -v $VERSION -f <graph>
VERSION="hybrid"

# Per-run time limit (GNU timeout syntax). The sbatch --time must exceed this.
TIME_LIMIT="30m"

# Max simultaneously running array tasks.
MAX_CONCURRENT=1

# Single source of truth for variants. Add/remove entries here and every
# script (check, submit, sbatch, test) adapts automatically.
VARIANTS=(
    approx
    IC
    dom
    unconf
    mirror
    clb
    cylb
    lpreduc
    lplb
    component-aware-vertex-cover-gpu
)

# Tolerate the unconf/uconf naming ambiguity: use whichever directory exists.
for i in "${!VARIANTS[@]}"; do
    v="${VARIANTS[$i]}"
    if [[ ! -d "$ROOT/$v" ]]; then
        alt=""
        case "$v" in
            unconf) alt="uconf" ;;
            uconf)  alt="unconf" ;;
        esac
        if [[ -n "$alt" && -d "$ROOT/$alt" ]]; then
            VARIANTS[$i]="$alt"
        fi
    fi
done

NV=${#VARIANTS[@]}

# make_manifest OUTFILE : sorted list of top-level *.txt graphs in $DATASET
make_manifest() {
    find "$DATASET" -maxdepth 1 -type f -name '*.txt' | LC_ALL=C sort > "$1"
}

# load_modules : make the `module` command available in non-login shells,
# then load the toolchain. Safe under `set -u`.
load_modules() {
    if ! command -v module >/dev/null 2>&1; then
        local f
        for f in /etc/profile.d/modules.sh /etc/profile.d/lmod.sh \
                 /usr/share/lmod/lmod/init/bash /etc/profile.d/z00_lmod.sh; do
            if [[ -f "$f" ]]; then
                set +u
                # shellcheck disable=SC1090
                source "$f"
                set -u
                break
            fi
        done
    fi
    if ! command -v module >/dev/null 2>&1; then
        echo "WARNING: 'module' command not found; relying on current environment." >&2
        return 0
    fi
    module load cuda
    module load gcc/9
}
