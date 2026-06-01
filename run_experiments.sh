#!/bin/bash

# Create output directories if they don't exist
mkdir -p outputs/txt
mkdir -p outputs/proofs

echo "Starting Tamarin experiments..."
echo "------------------------------------"

# Find all .spthy files inside src/experiments/
find src/experiments -name "*.spthy" | while read -r file; do
    # Generate a unique name based on the file path to avoid overwriting
    rel_path=${file#src/}
    clean_name=$(echo "$rel_path" | sed 's/\//_/g' | sed 's/\.spthy//g')
    
    echo "Processing: $file"
    
    # Execute Tamarin
    # --prove: prove all lemmas
    # --output: save the spthy file with the proofs
    # > : redirect console log to txt file
    tamarin-prover "$file" --prove --output="outputs/proofs/${clean_name}_proof.spthy" > "outputs/txt/${clean_name}.txt" 2>&1
    
    if [ $? -eq 0 ]; then
        echo "[SUCCESS] Finished: $clean_name"
    else
        echo "[ERROR] Failed: $clean_name (check the log in outputs/txt/${clean_name}.txt)"
    fi
done

echo "------------------------------------"
echo "All experiments have been processed."
echo "Results at: outputs/txt/"
echo "Proofs at: outputs/proofs/"
