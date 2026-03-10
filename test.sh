#!/bin/bash
# Test TSV parsing to verify it works before submitting jobs

SAMPLE_FILE="/scratch/frans/rna-seq/enhanced_sample_pairs_with_rg.tsv"

echo "Testing TSV parsing for first 5 pairs..."
echo ""

for ARRAY_ID in {1..5}; do
    echo "=== Array task ${ARRAY_ID} ==="
    
    # Get the line
    PAIR_LINE=$(sed -n "$((ARRAY_ID + 1))p" ${SAMPLE_FILE})
    
    echo "Raw line:"
    echo "${PAIR_LINE}"
    echo ""
    
    # Method 1: Using awk with tab delimiter
    echo "Method 1 (awk -F'\t'):"
    TUMOR_BAM=$(echo "${PAIR_LINE}" | awk -F'\t' '{print $1}')
    NORMAL_BAM=$(echo "${PAIR_LINE}" | awk -F'\t' '{print $2}')
    TUMOR_NAME=$(echo "${PAIR_LINE}" | awk -F'\t' '{print $3}')
    NORMAL_NAME=$(echo "${PAIR_LINE}" | awk -F'\t' '{print $4}')
    PAIR_ID=$(echo "${PAIR_LINE}" | awk -F'\t' '{print $5}')
    
    echo "  TUMOR_BAM: ${TUMOR_BAM}"
    echo "  NORMAL_BAM: ${NORMAL_BAM}"
    echo "  TUMOR_NAME: ${TUMOR_NAME}"
    echo "  NORMAL_NAME: ${NORMAL_NAME}"
    echo "  PAIR_ID: ${PAIR_ID}"
    
    # Verify files exist
    if [ -f "${TUMOR_BAM}" ]; then
        echo "  ✓ Tumor BAM exists"
    else
        echo "  ✗ Tumor BAM NOT FOUND"
    fi
    
    if [ -f "${NORMAL_BAM}" ]; then
        echo "  ✓ Normal BAM exists"
    else
        echo "  ✗ Normal BAM NOT FOUND"
    fi
    
    echo ""
done

echo "If all BAMs show as existing, the parsing is correct."