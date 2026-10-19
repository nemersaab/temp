#!/bin/bash

module load cuda
module load gcc/9
for dir in *; do
    # Check if it is a directory
    if [ -d "$dir" ]; then

        # Check if src exists
        if [ -d "$dir/src" ]; then
            echo "================================"
            echo "Processing $dir"
            echo "================================"

            (
                cd "$dir/src" || exit 1

                # Modify Makefile if it exists
                if [ -f "Makefile" ]; then
                    sed -i 's/compute_70,code=sm_70/compute_80,code=sm_80/g' Makefile
                    echo "Updated NVCC_FLAGS in $dir/src/Makefile"
                else
                    echo "Makefile not found in $dir/src"
                    exit 1
                fi

                # Clean and build
                make clean && make
            )

            if [ $? -ne 0 ]; then
                echo "Build failed for $dir"
            else
                echo "Build successful for $dir"
            fi

        else
            echo "Skipping $dir: src not found"
        fi
    fi
done

echo "================================"
echo "All directories processed!"
