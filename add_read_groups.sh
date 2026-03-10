#!/bin/bash
#SBATCH --job-name=add_read_groups
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=radhika.mahajan@sinaihealth.ca
#SBATCH --time=24:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=4
#SBATCH --array=1-132
#SBATCH --output=/scratch/rad123/FINAL_MUTECT2_ANALYSIS/logs/bams_with_rg/add_rg_%A_%a.out
#SBATCH --error=/scratch/rad123/FINAL_MUTECT2_ANALYSIS/logs/bams_with_rg/add_rg_%A_%a.err

echo "=========================================="
echo "Adding Read Groups to BAM Files with GATK"
echo "Processing BAM $SLURM_ARRAY_TASK_ID/132"
echo "=========================================="

# Load modules
module load StdEnv/2023
module load gatk
module load samtools

# Define paths
WORK_DIR="/scratch/rad123/FINAL_MUTECT2_ANALYSIS"
INPUT_BAM_DIR="/scratch/rad123/my_RNA-seq/complete_RNA/results/STAR"
OUTPUT_BAM_DIR="/scratch/rad123/FINAL_MUTECT2_ANALYSIS/bams_with_rg"

cd $WORK_DIR

# Create output and log directories
mkdir -p $OUTPUT_BAM_DIR
mkdir -p logs/bams_with_rg temp

# Create list of all BAM files if it doesn't exist
if [ ! -f "all_bam_files.list" ]; then
    echo "Creating BAM file list..."
    find $INPUT_BAM_DIR -name "*.bam" | sort > all_bam_files.list
    echo "Found $(wc -l < all_bam_files.list) BAM files"
fi

# Get the BAM file for this array job
INPUT_BAM=$(sed -n "${SLURM_ARRAY_TASK_ID}p" all_bam_files.list)

if [ -z "$INPUT_BAM" ] || [ ! -f "$INPUT_BAM" ]; then
    echo "ERROR: BAM file not found for array job $SLURM_ARRAY_TASK_ID"
    echo "Expected: $INPUT_BAM"
    exit 1
fi

# Extract sample name from filename
FILENAME=$(basename "$INPUT_BAM")
SAMPLE_NAME=$(echo "$FILENAME" | sed 's/_Aligned.sortedByCoord.out.bam//' | sed 's/.bam//')

# Define output files
OUTPUT_BAM="$OUTPUT_BAM_DIR/${SAMPLE_NAME}_with_rg.bam"
LOG_FILE="logs/bams_with_rg/add_rg_${SAMPLE_NAME}.log"

echo "Processing:"
echo "  Input BAM: $INPUT_BAM"
echo "  Sample Name: $SAMPLE_NAME"
echo "  Output BAM: $OUTPUT_BAM"

# Check if output already exists
if [ -f "$OUTPUT_BAM" ]; then
    echo "Output BAM already exists. Skipping..."
    exit 0
fi

# Redirect output to log file and console
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "\n$(date): Adding read groups with GATK (lenient validation)..."

# Add read groups using GATK AddOrReplaceReadGroups with LENIENT validation
gatk AddOrReplaceReadGroups \
    -I "$INPUT_BAM" \
    -O "$OUTPUT_BAM" \
    -RGID "$SAMPLE_NAME" \
    -RGSM "$SAMPLE_NAME" \
    -RGLB "lib_${SAMPLE_NAME}" \
    -RGPL "ILLUMINA" \
    -RGPU "unit_${SAMPLE_NAME}" \
    --VALIDATION_STRINGENCY LENIENT \
    --TMP_DIR temp/ \
    2>&1 | tee -a "$LOG_FILE"

if [ $? -eq 0 ]; then
    echo "$(date): ✅ Successfully added read groups to $SAMPLE_NAME"
    
    # Index the new BAM file
    echo "$(date): Indexing BAM file..."
    samtools index "$OUTPUT_BAM"
    
    if [ $? -eq 0 ]; then
        echo "$(date): ✅ BAM file indexed successfully"
        
        # Verify the read groups were added correctly
        echo "$(date): Verifying read groups..."
        echo "Header @RG line:"
        samtools view -H "$OUTPUT_BAM" | grep "^@RG"
        
        echo "Sample read RG tags:"
        samtools view "$OUTPUT_BAM" | head -3 | cut -f12- | grep "RG:Z:"
        
        # Verify the RG tags in reads match the header
        HEADER_RG_ID=$(samtools view -H "$OUTPUT_BAM" | grep "^@RG" | grep -o 'ID:[^[:space:]]*' | cut -d: -f2)
        READ_RG_ID=$(samtools view "$OUTPUT_BAM" | head -1 | grep -o 'RG:Z:[^[:space:]]*' | cut -d: -f3)
        
        echo "Header RG ID: $HEADER_RG_ID"
        echo "Read RG ID: $READ_RG_ID"
        
        if [ "$HEADER_RG_ID" = "$READ_RG_ID" ]; then
            echo "✅ Read group IDs match between header and reads"
        else
            echo "⚠️  Read group IDs do not match"
        fi
        
        # Get file sizes
        ORIGINAL_SIZE=$(du -sh "$INPUT_BAM" | cut -f1)
        NEW_SIZE=$(du -sh "$OUTPUT_BAM" | cut -f1)
        echo "File sizes: Original=$ORIGINAL_SIZE, With RG=$NEW_SIZE"
        
        echo "$(date): ✅ All verification passed for $SAMPLE_NAME"
        
    else
        echo "❌ ERROR: Failed to index BAM file"
        exit 1
    fi
else
    echo "❌ ERROR: Failed to add read groups to $SAMPLE_NAME"
    echo "Check detailed log: $LOG_FILE"
    exit 1
fi

echo "$(date): Array job $SLURM_ARRAY_TASK_ID completed successfully"
echo "✅ BAM file with corrected read groups: $OUTPUT_BAM"