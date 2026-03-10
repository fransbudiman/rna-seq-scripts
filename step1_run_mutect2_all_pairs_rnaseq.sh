#!/bin/bash
#SBATCH --job-name=mutect2_rnaseq
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=frans.budiman@alumni.utoronto.ca
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --array=1-1
#SBATCH --output=/scratch/frans/rna-seq/logs/mutect2_rnaseq_%A_%a.out
#SBATCH --error=/scratch/frans/rna-seq/logs/mutect2_rnaseq_%A_%a.err

# Load modules
module load StdEnv/2023
module load gatk
module load samtools

WORK_DIR="/scratch/frans/rna-seq"
cd ${WORK_DIR}

# Now source resource paths (which may use WORK_DIR)
source ${WORK_DIR}/resources/resource_paths_with_rg.sh

# Get the current pair based on array task ID
PAIR_LINE=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" ${SAMPLE_FILE})

# Parse the TSV line using IFS (most reliable method)
IFS=$'\t' read -r TUMOR_BAM NORMAL_BAM TUMOR_NAME NORMAL_NAME PAIR_ID <<< "${PAIR_LINE}"

# Output directories
OUTPUT_DIR="${WORK_DIR}/results/mutect2_calls"
mkdir -p ${OUTPUT_DIR}

# Panel of Normals
PON="${WORK_DIR}/results/pon/final/rnaseq_panel_of_normals.vcf.gz"

echo "======================================"
echo "Mutect2 calling - RNA-seq mode"
echo "======================================"
echo "Array task: ${SLURM_ARRAY_TASK_ID}/66"
echo "Pair: ${PAIR_ID}"
echo "Start time: $(date)"
echo ""
echo "Tumor: ${TUMOR_NAME}"
echo "  BAM: ${TUMOR_BAM}"
echo "Normal: ${NORMAL_NAME}"
echo "  BAM: ${NORMAL_BAM}"
echo ""

# Verify input files exist
echo "Checking input files..."
ALL_OK=true

for file in "${TUMOR_BAM}" "${NORMAL_BAM}" "${REFERENCE}" "${GNOMAD}" "${PON}" "${INTERVALS}"; do
    if [ ! -f "${file}" ]; then
        echo "ERROR: Missing file: ${file}"
        ALL_OK=false
    fi
done

if [ "${ALL_OK}" = false ]; then
    echo "Exiting due to missing files"
    exit 1
fi

echo "All input files present"
echo ""

# Run Mutect2 with RNA-seq specific settings
echo "Running Mutect2..."
gatk Mutect2 \
    -R ${REFERENCE} \
    -I ${TUMOR_BAM} \
    -I ${NORMAL_BAM} \
    -tumor ${TUMOR_NAME} \
    -normal ${NORMAL_NAME} \
    --germline-resource ${GNOMAD} \
    --panel-of-normals ${PON} \
    --intervals ${INTERVALS} \
    --disable-read-filter MappingQualityAvailableReadFilter \
    --disable-read-filter MappingQualityReadFilter \
    --dont-use-soft-clipped-bases true \
    --min-base-quality-score 20 \
    --native-pair-hmm-threads 4 \
    --f1r2-tar-gz ${OUTPUT_DIR}/${PAIR_ID}_f1r2.tar.gz \
    -O ${OUTPUT_DIR}/${PAIR_ID}_unfiltered.vcf.gz

EXIT_CODE=$?
echo ""
echo "Mutect2 exit code: ${EXIT_CODE}"

if [ ${EXIT_CODE} -eq 0 ]; then
    echo ""
    echo "======================================"
    echo "SUCCESS: ${PAIR_ID}"
    echo "======================================"
    echo "End time: $(date)"
    echo ""
    
    # Quick statistics
    if [ -f "${OUTPUT_DIR}/${PAIR_ID}_unfiltered.vcf.gz" ]; then
        VCF_SIZE=$(ls -lh ${OUTPUT_DIR}/${PAIR_ID}_unfiltered.vcf.gz | awk '{print $5}')
        VARIANT_COUNT=$(zgrep -v "^#" ${OUTPUT_DIR}/${PAIR_ID}_unfiltered.vcf.gz | wc -l)
        SNV_COUNT=$(zgrep -v "^#" ${OUTPUT_DIR}/${PAIR_ID}_unfiltered.vcf.gz | awk '{if(length($4)==1 && length($5)==1) print}' | wc -l)
        INDEL_COUNT=$(zgrep -v "^#" ${OUTPUT_DIR}/${PAIR_ID}_unfiltered.vcf.gz | awk '{if(length($4)!=1 || length($5)!=1) print}' | wc -l)
        
        echo "Results:"
        echo "  VCF size: ${VCF_SIZE}"
        echo "  Total variants: ${VARIANT_COUNT}"
        echo "  SNVs: ${SNV_COUNT}"
        echo "  Indels: ${INDEL_COUNT}"
    fi
    
    if [ -f "${OUTPUT_DIR}/${PAIR_ID}_f1r2.tar.gz" ]; then
        F1R2_SIZE=$(ls -lh ${OUTPUT_DIR}/${PAIR_ID}_f1r2.tar.gz | awk '{print $5}')
        echo "  F1R2 file: ${F1R2_SIZE}"
    fi
else
    echo ""
    echo "======================================"
    echo "FAILED: ${PAIR_ID}"
    echo "======================================"
    exit ${EXIT_CODE}
fi
