#!/bin/bash
set -euo pipefail

# Usage: ./submit.sh [START_GRAPH] [NUMBER_OF_GRAPHS]
#   START_GRAPH is 1-based. Runs all variants on each selected graph.
source "$(cd "$(dirname "$0")" && pwd)/config.sh"

START="${1:-1}"
COUNT="${2:-1}"

if ! [[ "$START" =~ ^[0-9]+$ && "$COUNT" =~ ^[0-9]+$ ]]; then
    echo "ERROR: START and COUNT must be positive integers." >&2
    exit 1
fi

cd "$ROOT"
mkdir -p logs results/status results/manifests

if [[ ! -d "$DATASET" ]]; then
    echo "ERROR: Dataset directory not found: $DATASET" >&2
    exit 1
fi

# Snapshot the graph list for THIS submission so later runs of check.sh /
# submit.sh can never shift the indices of jobs that are queued or running.
MANIFEST="$ROOT/results/manifests/graphs_$(date +%Y%m%d_%H%M%S).txt"
make_manifest "$MANIFEST"
cp "$MANIFEST" "$ROOT/graphs.txt"

TOTAL="$(wc -l < "$MANIFEST")"

if (( START < 1 || COUNT < 1 || START + COUNT - 1 > TOTAL )); then
    echo "ERROR: Invalid graph range. Dataset contains $TOTAL graph files." >&2
    exit 1
fi

for VARIANT in "${VARIANTS[@]}"; do
    BIN="$ROOT/$VARIANT/src/output"
    if [[ ! -f "$BIN" ]]; then
        echo "ERROR: Executable not found: $BIN" >&2
        exit 1
    fi
    chmod u+x "$BIN"
done

START_INDEX=$((START - 1))
NTASKS=$((COUNT * NV))

# Slurm rejects array indices >= MaxArraySize (default 1001), so split the
# work into chunks of whole graphs that each fit in one array.
MAXARR="$(scontrol show config 2>/dev/null | awk '/^MaxArraySize/ {print $3}')"
[[ "$MAXARR" =~ ^[0-9]+$ ]] || MAXARR=1001
GRAPHS_PER_CHUNK=$(( MAXARR / NV ))
if (( GRAPHS_PER_CHUNK < 1 )); then
    echo "ERROR: MaxArraySize ($MAXARR) is smaller than the variant count ($NV)." >&2
    exit 1
fi
NCHUNKS=$(( (COUNT + GRAPHS_PER_CHUNK - 1) / GRAPHS_PER_CHUNK ))

echo "Project:            $ROOT"
echo "Dataset:            $DATASET"
echo "Manifest:           $MANIFEST"
echo "Total graphs found: $TOTAL"
echo "Graphs selected:    $START through $((START + COUNT - 1))"
echo "Variants ($NV):     ${VARIANTS[*]}"
echo "Command:            ./output -v $VERSION -f <graph>"
echo "Tasks to submit:    $NTASKS"
echo "MaxArraySize:       $MAXARR -> $GRAPHS_PER_CHUNK graphs per array, $NCHUNKS array(s)"
echo "Max simultaneous:   $MAX_CONCURRENT"

PREV=""
REMAINING=$COUNT
CHUNK_START_INDEX=$START_INDEX
while (( REMAINING > 0 )); do
    N=$(( REMAINING < GRAPHS_PER_CHUNK ? REMAINING : GRAPHS_PER_CHUNK ))
    LAST_TASK=$(( N * NV - 1 ))

    DEP=()
    # Run chunks one after another so only $MAX_CONCURRENT tasks run in total.
    [[ -n "$PREV" ]] && DEP=(--dependency="afterany:${PREV}")

        JOBID="$(sbatch --parsable ${DEP[@]+"${DEP[@]}"} \
        --partition=cudadev \
        --gres=gpu:v100d32q:1 \
        --array="0-${LAST_TASK}%${MAX_CONCURRENT}" \
        --export="ALL,START_GRAPH_INDEX=${CHUNK_START_INDEX},MANIFEST=${MANIFEST}" \
        run_array.sbatch)"


    echo "Submitted job $JOBID: graphs $((CHUNK_START_INDEX + 1))-$((CHUNK_START_INDEX + N)) ($((N * NV)) tasks)"
    PREV="$JOBID"
    CHUNK_START_INDEX=$(( CHUNK_START_INDEX + N ))
    REMAINING=$(( REMAINING - N ))
done
