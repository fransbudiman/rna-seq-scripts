#!/bin/bash
#SBATCH --job-name=combine_pon_rnaseq
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=frans.budiman@alumni.utoronto.ca
#SBATCH --time=48:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=8
#SBATCH --output=/scratch/frans/rna-seq/logs/combine_pon_rnaseq_%j.out
#SBATCH --error=/scratch/frans/rna-seq/logs/combine_pon_rnaseq_%j.err

echo "=========================================="
echo "Combining Individual PoN VCFs into Final Panel of Normals"
echo "=========================================="

# Unset conflicting Java options
unset JAVA_TOOL_OPTIONS

# Load modules and configuration
source /scratch/frans/rna-seq/resources/resource_paths_with_rg.sh

cd $WORK_DIR

echo "Configuration:"
echo "  Work directory: $WORK_DIR"
echo "  Reference: $REFERENCE"

# Create output directory
mkdir -p results/pon/final

echo -e "\n$(date): Checking for individual PoN VCFs..."

# Find all individual PoN VCFs
PON_VCFS=(results/pon/vcfs/*_for_pon.vcf.gz)
VCF_COUNT=${#PON_VCFS[@]}

echo "Found $VCF_COUNT individual PoN VCFs"

if [ $VCF_COUNT -eq 0 ]; then
    echo "ERROR: No individual PoN VCFs found in results/pon/vcfs/"
    echo "Make sure the create_pon jobs completed successfully"
    exit 1
fi

# Verify all VCFs exist and are readable
echo "Verifying individual VCF files..."
MISSING_COUNT=0
EMPTY_COUNT=0
VALID_VCFS=()

for vcf in "${PON_VCFS[@]}"; do
    if [ ! -f "$vcf" ]; then
        echo "WARNING: Missing VCF: $vcf"
        ((MISSING_COUNT++))
    else
        # Check if VCF has variants (more than just header)
        VARIANT_COUNT=$(zgrep -v "^#" "$vcf" 2>/dev/null | wc -l)
        if [ $VARIANT_COUNT -eq 0 ]; then
            echo "WARNING: Empty VCF (no variants): $vcf"
            ((EMPTY_COUNT++))
        else
            echo "✅ Valid VCF: $vcf ($VARIANT_COUNT variants)"
            VALID_VCFS+=("$vcf")
        fi
    fi
done

VALID_COUNT=${#VALID_VCFS[@]}
echo -e "\nSummary:"
echo "  Total VCFs found: $VCF_COUNT"
echo "  Missing VCFs: $MISSING_COUNT"
echo "  Empty VCFs: $EMPTY_COUNT"
echo "  Valid VCFs: $VALID_COUNT"

if [ $VALID_COUNT -lt 10 ]; then
    echo "ERROR: Too few valid VCFs ($VALID_COUNT). Need at least 10 for a meaningful PoN."
    echo "Check the individual PoN creation jobs."
    exit 1
fi

# Define output files
FINAL_PON_VCF="results/pon/final/rnaseq_panel_of_normals.vcf.gz"
LOG_FILE="results/pon/final/combine_pon.log"
GENOMICSDB_WORKSPACE="results/pon/final/pon_db"

echo -e "\n$(date): Step 1 - Creating GenomicsDB workspace from $VALID_COUNT individual VCFs..."

# Build the GenomicsDBImport command with -V flags for each VCF
V_ARGS=()
for vcf in "${VALID_VCFS[@]}"; do
    V_ARGS+=("-V" "$vcf")
done

# Remove existing workspace if it exists
if [ -d "$GENOMICSDB_WORKSPACE" ]; then
    echo "Removing existing GenomicsDB workspace..."
    rm -rf "$GENOMICSDB_WORKSPACE"
fi

# Create GenomicsDB workspace from individual VCFs
gatk GenomicsDBImport \
    -R "$REFERENCE" \
    "${V_ARGS[@]}" \
    --genomicsdb-workspace-path "$GENOMICSDB_WORKSPACE" \
    -L "$INTERVALS" \
    --tmp-dir temp/ \
    --batch-size 50 \
    --java-options "-Xmx48g" \
    2>&1 | tee "$LOG_FILE"

# Check if GenomicsDBImport succeeded
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "$(date): ❌ GenomicsDBImport failed"
    echo "Check log file: $LOG_FILE"
    echo "Last 20 lines of log:"
    tail -20 "$LOG_FILE"
    exit 1
fi

echo "$(date): ✅ GenomicsDB workspace created successfully"

echo -e "\n$(date): Step 2 - Creating Panel of Normals from GenomicsDB..."

# Unset Java tool options again before second step
unset JAVA_TOOL_OPTIONS

# Create PoN from GenomicsDB workspace
gatk CreateSomaticPanelOfNormals \
    -R "$REFERENCE" \
    -V gendb://"$GENOMICSDB_WORKSPACE" \
    -O "$FINAL_PON_VCF" \
    --java-options "-Xmx48g" \
    2>&1 | tee -a "$LOG_FILE"

# Check if CreateSomaticPanelOfNormals succeeded
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "$(date): ✅ Panel of Normals creation completed successfully"
    
    # Verify output file was created
    if [ -f "$FINAL_PON_VCF" ]; then
        # Count variants in final PoN
        PON_VARIANT_COUNT=$(zgrep -v "^#" "$FINAL_PON_VCF" | wc -l)
        echo "Panel of Normals created successfully:"
        echo "  Output: $FINAL_PON_VCF"
        echo "  Size: $(du -sh "$FINAL_PON_VCF" | cut -f1)"
        echo "  Variants in PoN: $PON_VARIANT_COUNT"
        echo "  Individual VCFs used: $VALID_COUNT"
        echo "  Log file: $LOG_FILE"
        
        # Show some sample PoN entries
        if [ $PON_VARIANT_COUNT -gt 0 ]; then
            echo -e "\nSample PoN entries:"
            zgrep -v "^#" "$FINAL_PON_VCF" | head -3
        fi
        
        # Create a summary file
        SUMMARY_FILE="results/pon/final/pon_creation_summary.txt"
        cat > "$SUMMARY_FILE" << EOF
Panel of Normals Creation Summary
=================================
Date: $(date)
Input VCFs processed: $VALID_COUNT out of $VCF_COUNT found
Final PoN file: $FINAL_PON_VCF
Variants in PoN: $PON_VARIANT_COUNT
PoN file size: $(du -sh "$FINAL_PON_VCF" | cut -f1)

Valid input VCFs:
EOF
        for vcf in "${VALID_VCFS[@]}"; do
            VARIANT_COUNT=$(zgrep -v "^#" "$vcf" 2>/dev/null | wc -l)
            echo "  $vcf ($VARIANT_COUNT variants)" >> "$SUMMARY_FILE"
        done
        
        echo "Summary written to: $SUMMARY_FILE"
        
    else
        echo "ERROR: Panel of Normals VCF not created: $FINAL_PON_VCF"
        exit 1
    fi
else
    echo "$(date): ❌ Panel of Normals creation failed"
    echo "Check log file: $LOG_FILE"
    echo "Last 20 lines of log:"
    tail -20 "$LOG_FILE"
    exit 1
fi

echo "$(date): Panel of Normals creation completed successfully!"
echo "Your RNA-seq Panel of Normals is ready: $FINAL_PON_VCF"
echo ""
echo "Next steps:"
echo "1. Use this PoN in your tumor-normal Mutect2 calls with: -pon $FINAL_PON_VCF"
echo "2. The PoN will help filter out recurrent false positives in RNA-seq variant calling"