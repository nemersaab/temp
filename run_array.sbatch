#!/bin/bash
#SBATCH --job-name=vertex cover
#SBATCH --account=nas83
#SBATCH --partition=gpu
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32000
#SBATCH --gres=gpu:v100d32q:1
#SBATCH --time=01:10:00
#SBATCH --output=logs/%A_%a.out
#SBATCH --error=logs/%A_%a.err

# No -e on purpose: this script must always reach the status-file step.
set -uo pipefail

# Slurm runs a copy of this script from a spool dir, so use the submit dir.
ROOT="$SLURM_SUBMIT_DIR"
source "$ROOT/config.sh"

START_GRAPH_INDEX="${START_GRAPH_INDEX:-0}"
MANIFEST="${MANIFEST:-$ROOT/graphs.txt}"

# Tasks are grouped by graph: all $NV variants run on each graph in turn.
TASK="${SLURM_ARRAY_TASK_ID}"
VARIANT_INDEX=$((TASK % NV))
GRAPH_INDEX=$((START_GRAPH_INDEX + TASK / NV))

VARIANT="${VARIANTS[$VARIANT_INDEX]}"
GRAPH="$(sed -n "$((GRAPH_INDEX + 1))p" "$MANIFEST")"
WORKDIR="$ROOT/$VARIANT/src"

mkdir -p "$ROOT/results/status"
STATUS="$ROOT/results/status/${SLURM_ARRAY_JOB_ID}_${TASK}.txt"

write_status() {  # $1=exit code  $2=elapsed seconds
    local tmp="${STATUS}.tmp"
    {
        echo "variant=$VARIANT"
        echo "graph=$GRAPH"
        echo "exit_code=$1"
        echo "elapsed_sec=$2"
        echo "finished=$(date)"
    } > "$tmp"
    mv "$tmp" "$STATUS"
}

if [[ -z "$GRAPH" || ! -f "$GRAPH" ]]; then
    echo "ERROR: Graph not found for index $GRAPH_INDEX (manifest: $MANIFEST)"
    write_status 97 0
    exit 0
fi

if [[ ! -x "$WORKDIR/output" ]]; then
    echo "ERROR: Executable missing or not executable: $WORKDIR/output"
    write_status 98 0
    exit 0
fi

load_modules

echo "Started:  $(date)"
echo "Variant:  $VARIANT"
echo "Graph:    $GRAPH"
echo "Task ID:  $TASK"
echo "Command:  ./output -v $VERSION -f $GRAPH"

cd "$WORKDIR" || { write_status 99 0; exit 0; }

SECONDS=0
timeout --signal=TERM --kill-after=30s "$TIME_LIMIT" \
    ./output -v "$VERSION" -f "$GRAPH"
RC=$?
ELAPSED=$SECONDS

write_status "$RC" "$ELAPSED"

echo "Exit code: $RC  (124 = timed out)"
echo "Elapsed:   ${ELAPSED}s"
echo "Finished:  $(date)"

exit 0
#
