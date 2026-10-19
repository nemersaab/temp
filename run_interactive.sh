#!/bin/bash
set -euo pipefail

# Usage: ./submit.sh [START_GRAPH] [NUMBER_OF_GRAPHS]
# Run directly on the currently allocated interactive node.

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

MANIFEST="$ROOT/results/manifests/graphs_$(date +%Y%m%d_%H%M%S)_$$.txt"
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

NTASKS=$((COUNT * NV))

echo "Project:            $ROOT"
echo "Dataset:            $DATASET"
echo "Manifest:           $MANIFEST"
echo "Total graphs found: $TOTAL"
echo "Graphs selected:    $START through $((START + COUNT - 1))"
echo "Variants ($NV):     ${VARIANTS[*]}"
echo "Command:            ./output -v $VERSION -f <graph>"
echo "Tasks to execute:   $NTASKS"
echo "Per-run timeout:    $TIME_LIMIT"
echo "Execution mode:     Interactive (sequential)"
echo

COMPLETED=0
FAILED=0
TIMED_OUT=0

for (( G=START; G<START+COUNT; G++ )); do

    GRAPH="$(sed -n "${G}p" "$MANIFEST")"
    GRAPH_NAME="$(basename "$GRAPH" .txt)"

    for VARIANT in "${VARIANTS[@]}"; do

        WORKDIR="$ROOT/$VARIANT/src"

        LOGDIR="$ROOT/logs/$VARIANT"
        STATUSDIR="$ROOT/results/status/$VARIANT"

        mkdir -p "$LOGDIR" "$STATUSDIR"

        LOGFILE="$LOGDIR/${GRAPH_NAME}_g${G}.log"
        STATUSFILE="$STATUSDIR/${GRAPH_NAME}_g${G}.status"

        echo "======================================"
        echo "Graph:   $G / $TOTAL"
        echo "File:    $GRAPH_NAME"
        echo "Variant: $VARIANT"
        echo "Started: $(date)"
        echo "======================================"

        SECONDS=0

        # Disable errexit temporarily so timeout/failures
        # do not stop the remaining executions.
        set +e

        (
            cd "$WORKDIR" || exit 99

            timeout --signal=TERM --kill-after=30s "$TIME_LIMIT" \
                ./output -v "$VERSION" -f "$GRAPH"
        ) > "$LOGFILE" 2>&1

        RC=$?

        set -e

        ELAPSED=$SECONDS

        {
            echo "exit_code=$RC"
            echo "elapsed_seconds=$ELAPSED"
            echo "graph=$GRAPH"
            echo "variant=$VARIANT"
        } > "$STATUSFILE"

        if (( RC == 124 )); then
            echo "Status:  TIMEOUT"
            TIMED_OUT=$((TIMED_OUT + 1))
        elif (( RC == 0 )); then
            echo "Status:  SUCCESS"
            COMPLETED=$((COMPLETED + 1))
        else
            echo "Status:  FAILED (exit code $RC)"
            FAILED=$((FAILED + 1))
        fi

        echo "Elapsed: ${ELAPSED}s"
        echo "Log:     $LOGFILE"
        echo "Finished: $(date)"
        echo
    done
done

echo "======================================"
echo "ALL EXECUTIONS FINISHED"
echo "======================================"
echo "Successful: $COMPLETED"
echo "Timed out:  $TIMED_OUT"
echo "Failed:     $FAILED"
echo "Total:      $NTASKS"

