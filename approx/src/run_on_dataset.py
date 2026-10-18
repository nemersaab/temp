from pathlib import Path
import subprocess
import csv
import os
import re

TIMEOUT_SECONDS = 3600

# Graphs to skip for this run
exclude_graphs = file_list = [ ]


include_graphs=[]


data_dir = Path("../../../new-dataset/")
Path("./outputs").mkdir(exist_ok=True)
output_dir = Path("./full")
# Create the output directory if it doesn't exist
output_dir.mkdir(exist_ok=True)

# Default timeout (5 minutes)
# found = False
for graph_file in sorted(data_dir.iterdir()):
    if not graph_file.is_file():
        continue
    # if graph_file.name == "cop_hat1500-1.txt":
    #     found = True
    if graph_file.name  in exclude_graphs:# or not found:
        print(f"Skipping {graph_file.name}")
        continue

    print(f"Running on {graph_file.name}...")

    output_file = output_dir / f"{graph_file.stem}.out"

    try:
        result = subprocess.run(
             [   #"java", "-cp", "bin", "Main",
                "./output",
                "-v",
                "hybrid",
                "-f",
                str(graph_file)
            ],
            capture_output=True,
            text=True,
            timeout=TIMEOUT_SECONDS
        )

        with open(output_file, "w") as f:
            f.write(result.stdout)

            if result.stderr:
                f.write("\n\n=== STDERR ===\n")
                f.write(result.stderr)

        print(f"Saved output to {output_file}")

    except subprocess.TimeoutExpired as e:
        with open(output_file, "w") as f:
            f.write(f"Execution timed out after {TIMEOUT_SECONDS} seconds.\n")
        print(f"{graph_file.name} timed out after {TIMEOUT_SECONDS} seconds.")
