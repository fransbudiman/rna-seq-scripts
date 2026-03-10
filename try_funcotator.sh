#!/bin/bash
#SBATCH --job-name=pass_funcotator
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=frans.budiman@alumni.utoronto.ca
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --array=1-1
#SBATCH --output=logs/pass_funcotator_%A_%a.log

# Extract PASS variants + Annotate with Funcotator
# Much faster than annotating all variants!

module load StdEnv/2023
module load gatk

WORK_DIR="/scratch/rad123/FINAL_MUTECT2_ANALYSIS"
cd ${WORK_DIR}
source ${WORK_DIR}/resources/resource_paths_with_rg.sh

# Read pair info from sample file
PAIR_LINE=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" ${SAMPLE_FILE})
IFS=$'\t' read -r TUMOR_BAM NORMAL_BAM TUMOR_NAME NORMAL_NAME PAIR_ID <<< "${PAIR_LINE}"

FILTERED_VCF="${WORK_DIR}/results/filtered_calls_relaxed/${PAIR_ID}_filtered.vcf.gz"
PASS_DIR="${WORK_DIR}/results/pass_only_relaxed"
OUTPUT_DIR="${WORK_DIR}/results/funcotator_pass_only"

mkdir -p ${PASS_DIR}
mkdir -p ${OUTPUT_DIR}

PASS_VCF="${PASS_DIR}/${PAIR_ID}_pass.vcf.gz"
OUTPUT_MAF="${OUTPUT_DIR}/${PAIR_ID}_pass_variants.maf"

FUNCOTATOR_DATA="${WORK_DIR}/funcotator_datasources/funcotator_dataSources.v1.8.hg38.20230908s"

echo "=========================================="
echo "PASS-only Funcotator annotation - ${PAIR_ID}"
echo "Tumor:  ${TUMOR_NAME}"
echo "Normal: ${NORMAL_NAME}"
echo "Start:  $(date)"
echo "=========================================="
echo ""

# Check if already completed
if [ -f "${OUTPUT_MAF}" ]; then
    echo "${PAIR_ID} already annotated - skipping"
    exit 0
fi

# Check if input exists
if [ ! -f "${FILTERED_VCF}" ]; then
    echo "✗ Input VCF not found: ${FILTERED_VCF}"
    exit 1
fi

# ============================================================================
# STEP 1: Extract PASS variants only
# ============================================================================

echo "STEP 1: Extracting PASS variants..."
echo ""

# Count total variants
TOTAL_VARIANTS=$(zcat ${FILTERED_VCF} | grep -v "^#" | wc -l)
echo "Total variants in filtered VCF: ${TOTAL_VARIANTS}"

# Extract PASS variants using GATK SelectVariants
gatk SelectVariants \
    -V ${FILTERED_VCF} \
    -O ${PASS_VCF} \
    --exclude-filtered true

if [ $? -ne 0 ]; then
    echo "✗ PASS extraction failed"
    exit 1
fi

# Count PASS variants
PASS_VARIANTS=$(zcat ${PASS_VCF} | grep -v "^#" | wc -l)
PERCENTAGE=$(awk "BEGIN {printf \"%.2f\", ($PASS_VARIANTS/$TOTAL_VARIANTS)*100}")

echo ""
echo "✓ PASS extraction completed"
echo "  Total variants:   ${TOTAL_VARIANTS}"
echo "  PASS variants:    ${PASS_VARIANTS}"
echo "  Percentage:       ${PERCENTAGE}%"
echo ""

# If no PASS variants, skip annotation
if [ ${PASS_VARIANTS} -eq 0 ]; then
    echo "⚠ No PASS variants found - creating empty MAF file"
    echo "# No PASS variants found for ${PAIR_ID}" > ${OUTPUT_MAF}
    exit 0
fi

# ============================================================================
# STEP 2: Annotate PASS variants with Funcotator
# ============================================================================

echo "STEP 2: Annotating PASS variants (MAF format)..."
echo ""

gatk Funcotator \
    --variant ${PASS_VCF} \
    --reference ${REFERENCE} \
    --ref-version hg38 \
    --data-sources-path ${FUNCOTATOR_DATA} \
    --output ${OUTPUT_MAF} \
    --output-file-format MAF \
    --transcript-selection-mode BEST_EFFECT \
    --annotation-default normal_barcode:${NORMAL_NAME} \
    --annotation-default tumor_barcode:${TUMOR_NAME}

if [ $? -ne 0 ]; then
    echo ""
    echo "✗ Funcotator MAF annotation failed"
    exit 1
fi

MAF_ANNOTATED=$(tail -n +2 ${OUTPUT_MAF} | wc -l)
echo ""
echo "✓ MAF annotation completed"
echo "  Annotated variants: ${MAF_ANNOTATED}"
echo ""

# ============================================================================
# SUMMARY
# ============================================================================

echo "=========================================="
echo "${PAIR_ID} COMPLETED"
echo "=========================================="
echo ""
echo "Summary:"
echo "  Total variants:     ${TOTAL_VARIANTS}"
echo "  PASS variants:      ${PASS_VARIANTS} (${PERCENTAGE}%)"
echo "  MAF annotated:      ${MAF_ANNOTATED}"
echo ""
echo "Output files:"
echo "  PASS VCF: ${PASS_VCF}"
echo "  MAF:      ${OUTPUT_MAF}"
echo ""
echo "End: $(date)"
echo "=========================================="