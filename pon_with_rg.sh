#!/bin/bash
#SBATCH --job-name=create_pon_rnaseq
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=frans.budiman@alumni.utoronto.ca
#SBATCH --time=24:00:00
#SBATCH --mem=96G
#SBATCH --cpus-per-task=32
#SBATCH --array=1-1
#SBATCH --output=/scratch/frans/rna-seq/logs/create_pon_rnaseq_%A_%a.out
#SBATCH --error=/scratch/frans/rna-seq/logs/create_pon_rnaseq_%A_%a.err

echo "=========================================="
echo "Creating Panel of Normals for RNA-seq (Optimized)"
echo "Processing Normal Sample $SLURM_ARRAY_TASK_ID/66"
echo "=========================================="

# Unset conflicting Java options
unset JAVA_TOOL_OPTIONS

# Load modules and configuration
source /scratch/frans/rna-seq/resources/resource_paths_with_rg.sh

cd $WORK_DIR

# Create directories for PoN
mkdir -p results/pon/{vcfs,logs} temp

echo "Configuration:"
echo "  Work directory: $WORK_DIR"
echo "  Sample file: $SAMPLE_FILE"
echo "  Reference: $REFERENCE"
echo "  Intervals: $INTERVALS"
echo "  Array job: $SLURM_ARRAY_TASK_ID of 66"

# Get the normal sample for this array job
SAMPLE_LINE=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" "$SAMPLE_FILE")
NORMAL_BAM=$(echo "$SAMPLE_LINE" | cut -f2)
NORMAL_SAMPLE=$(echo "$SAMPLE_LINE" | cut -f4)
PAIR_ID=$(echo "$SAMPLE_LINE" | cut -f5)

echo -e "\nProcessing normal sample for PoN:"
echo "  BAM file: $NORMAL_BAM"
echo "  Sample name: $NORMAL_SAMPLE"
echo "  From pair: $PAIR_ID"

# Verify the normal BAM exists
if [ ! -f "$NORMAL_BAM" ]; then
    echo "ERROR: Normal BAM not found: $NORMAL_BAM"
    exit 1
fi

# Verify BAM index exists
if [ ! -f "${NORMAL_BAM}.bai" ]; then
    echo "ERROR: BAM index not found: ${NORMAL_BAM}.bai"
    echo "Creating BAM index..."
    samtools index "$NORMAL_BAM"
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to create BAM index"
        exit 1
    fi
fi

# Verify the BAM has proper read groups and reads
echo "Verifying BAM file..."
RG_COUNT=$(samtools view -H "$NORMAL_BAM" | grep -c "^@RG")
if [ $RG_COUNT -eq 0 ]; then
    echo "ERROR: No read groups found in BAM file"
    exit 1
else
    echo "Found $RG_COUNT read group(s) in BAM file"
fi

# Quick read count check
READ_COUNT=$(samtools view -c "$NORMAL_BAM" | head -1)
echo "Total reads in BAM: $READ_COUNT"

if [ $READ_COUNT -eq 0 ]; then
    echo "ERROR: BAM file appears to be empty"
    exit 1
fi

echo -e "\n$(date): Running Mutect2 for RNA-seq PoN creation..."

# Define output files
OUTPUT_VCF="results/pon/vcfs/${NORMAL_SAMPLE}_for_pon.vcf.gz"
LOG_FILE="results/pon/logs/${NORMAL_SAMPLE}_mutect2.log"

# Run Mutect2 with RNA-seq optimized parameters
# Key changes for RNA-seq:
# 1. Disable mapping quality filters (RNA-seq has low MAPQ due to multi-mapping)
# 2. Use WGS intervals (better coverage for RNA-seq than exome intervals)
# 3. Add RNA-specific parameters
# 4. Increase memory and threads for better performance

gatk Mutect2 \
    -R "$REFERENCE" \
    -I "$NORMAL_BAM" \
    -tumor "$NORMAL_SAMPLE" \
    --max-mnp-distance 0 \
    -L "$INTERVALS" \
    -O "$OUTPUT_VCF" \
    --tmp-dir temp/ \
    --native-pair-hmm-threads 16 \
    --dont-use-soft-clipped-bases \
    --max-reads-per-alignment-start 0 \
    --java-options "-Xmx24g" \
    --disable-read-filter MappingQualityReadFilter \
    --disable-read-filter MappingQualityAvailableReadFilter \
    2>&1 | tee "$LOG_FILE"

# Check if Mutect2 succeeded
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "$(date): ✅ Mutect2 completed successfully for normal sample: $NORMAL_SAMPLE"
    
    # Verify output file was created
    if [ -f "$OUTPUT_VCF" ]; then
        # Count variants
        VARIANT_COUNT=$(zgrep -v "^#" "$OUTPUT_VCF" | wc -l)
        echo "Variants called in normal sample: $VARIANT_COUNT"
        echo "Output VCF: $OUTPUT_VCF ($(du -sh "$OUTPUT_VCF" | cut -f1))"
        echo "Log file: $LOG_FILE"
        
        # Show some sample variants if any exist
        if [ $VARIANT_COUNT -gt 0 ]; then
            echo "Sample variants:"
            zgrep -v "^#" "$OUTPUT_VCF" | head -3
        else
            echo "WARNING: No variants called in this normal sample"
            echo "This may be normal for some RNA-seq samples"
        fi
        
        # Show filtering stats from log
        echo -e "\nFiltering summary:"
        grep "read(s) filtered" "$LOG_FILE" | tail -5
        
    else
        echo "ERROR: Output VCF not created: $OUTPUT_VCF"
        exit 1
    fi
else
    echo "$(date): ❌ Mutect2 failed for normal sample: $NORMAL_SAMPLE"
    echo "Check log file: $LOG_FILE"
    echo "Last 20 lines of log:"
    tail -20 "$LOG_FILE"
    exit 1
fi

echo "$(date): Array job $SLURM_ARRAY_TASK_ID completed successfully"
echo "✅ Normal sample $NORMAL_SAMPLE processed for Panel of Normals"
echo "Next step: After all 66 jobs complete, run the combine_pon script"
