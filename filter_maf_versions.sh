#!/bin/bash
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=radhika.mahajan@sinaihealth.ca
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --array=1-1
#SBATCH --output=logs/filter_mafs_%A_%a.out
#SBATCH --error=logs/filter_mafs_%A_%a.err

WORK_DIR="/scratch/rad123/FINAL_MUTECT2_ANALYSIS"
cd ${WORK_DIR}
source ${WORK_DIR}/resources/resource_paths_with_rg.sh

PAIR_LINE=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" ${SAMPLE_FILE})
IFS=$'\t' read -r TUMOR_BAM NORMAL_BAM TUMOR_NAME NORMAL_NAME PAIR_ID <<< "${PAIR_LINE}"

INPUT_MAF="${WORK_DIR}/results/funcotator_annotated/${PAIR_ID}_all_variants.maf"
OUTPUT_DIR_SOMATIC="${WORK_DIR}/results/funcotator_somatic_only"
OUTPUT_DIR_PASS="${WORK_DIR}/results/funcotator_pass_only"

mkdir -p ${OUTPUT_DIR_SOMATIC}
mkdir -p ${OUTPUT_DIR_PASS}

echo "Filtering MAFs for ${PAIR_ID}"
echo "Start: $(date)"

if [ ! -f "${INPUT_MAF}" ]; then
    echo "ERROR: Input MAF not found: ${INPUT_MAF}"
    exit 1
fi

# Version 2: Tumor-only (n_alt_count = 0)
echo "Creating tumor-only MAF..."
grep "^Hugo_Symbol" ${INPUT_MAF} > ${OUTPUT_DIR_SOMATIC}/${PAIR_ID}_somatic_only.maf
grep -v "^#" ${INPUT_MAF} | grep -v "^Hugo_Symbol" | awk -F'\t' '{if($83==0) print}' >> ${OUTPUT_DIR_SOMATIC}/${PAIR_ID}_somatic_only.maf

SOMATIC_COUNT=$(grep -v "^Hugo_Symbol" ${OUTPUT_DIR_SOMATIC}/${PAIR_ID}_somatic_only.maf | wc -l)
echo "  Somatic-only variants: ${SOMATIC_COUNT}"

# Version 3: PASS-only (from PASS VCF)
echo "Creating PASS-only MAF..."
# Extract PASS variants from original VCF
VCF="${WORK_DIR}/results/filtered_calls_relaxed/${PAIR_ID}_filtered.vcf.gz"
PASS_VCF="${WORK_DIR}/temp/${PAIR_ID}_pass_only.vcf"
mkdir -p ${WORK_DIR}/temp

zgrep "^#" ${VCF} > ${PASS_VCF}
zgrep -v "^#" ${VCF} | grep -w "PASS" >> ${PASS_VCF}

# Match MAF entries to PASS variants
grep "^Hugo_Symbol" ${INPUT_MAF} > ${OUTPUT_DIR_PASS}/${PAIR_ID}_pass_only.maf

# Extract chr:pos from PASS VCF
grep -v "^#" ${PASS_VCF} | awk '{print $1":"$2}' > ${WORK_DIR}/temp/${PAIR_ID}_pass_positions.txt

# Filter MAF to only include PASS positions
grep -v "^#" ${INPUT_MAF} | grep -v "^Hugo_Symbol" | while IFS=$'\t' read -r line; do
    CHR=$(echo "$line" | cut -f5)
    POS=$(echo "$line" | cut -f6)
    KEY="${CHR}:${POS}"
    if grep -q "^${KEY}$" ${WORK_DIR}/temp/${PAIR_ID}_pass_positions.txt; then
        echo "$line"
    fi
done >> ${OUTPUT_DIR_PASS}/${PAIR_ID}_pass_only.maf

PASS_COUNT=$(grep -v "^Hugo_Symbol" ${OUTPUT_DIR_PASS}/${PAIR_ID}_pass_only.maf | wc -l)
echo "  PASS-only variants: ${PASS_COUNT}"

# Clean up temp files
rm -f ${PASS_VCF} ${WORK_DIR}/temp/${PAIR_ID}_pass_positions.txt

echo "End: $(date)"
echo ""
echo "Summary for ${PAIR_ID}:"
ALL_COUNT=$(grep -v "^#" ${INPUT_MAF} | grep -v "^Hugo_Symbol" | wc -l)
echo "  All variants: ${ALL_COUNT}"
echo "  Somatic-only: ${SOMATIC_COUNT}"
echo "  PASS-only: ${PASS_COUNT}"