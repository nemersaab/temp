et -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/config.sh"

mkdir -p "$ROOT/logs"

if [[ ! -d "$DATASET" ]]; then
    echo "ERROR: Dataset directory not found: $DATASET" >&2
    exit 1
fi

make_manifest "$ROOT/graphs.txt"
COUNT=$(wc -l < "$ROOT/graphs.txt")

MISSING=0
for d in "${VARIANTS[@]}"; do
    if [[ ! -x "$ROOT/$d/src/output" ]]; then
        echo "ERROR: missing or not executable: $ROOT/$d/src/output" >&2
        MISSING=1
    fi
done
(( MISSING == 0 )) || exit 1

echo "Project directory: $ROOT"
echo "Dataset directory: $DATASET"
echo "Graph count:       $COUNT"
echo "Variants ($NV):    ${VARIANTS[*]}"
echo "Command:           ./output -v $VERSION -f <graph>"
echo "Total tasks:       $((COUNT * NV))"
echo "All $NV executables exist."
