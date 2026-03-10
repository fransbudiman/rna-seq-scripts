#!/bin/bash
#SBATCH --job-name=filter
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=frans.budiman@alumni.utoronto.ca
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --array=1-1
#SBATCH --output=/scratch/frans/rna-seq/logs/filter_%A_%a.out
#SBATCH --error=/scratch/frans/rna-seq/logs/filter_%A_%a.err

module load StdEnv/2023
module load gatk

WORK_DIR="/scratch/frans/rna-seq"
cd ${WORK_DIR}
source ${WORK_DIR}/resources/resource_paths_with_rg.sh

PAIR_LINE=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" ${SAMPLE_FILE})
IFS=$'\t' read -r TUMOR_BAM NORMAL_BAM TUMOR_NAME NORMAL_NAME PAIR_ID <<< "${PAIR_LINE}"

MUTECT_DIR="${WORK_DIR}/results/mutect2_calls"
CONTAM_DIR="${WORK_DIR}/results/contamination"
OUTPUT_DIR="${WORK_DIR}/results/filtered_calls_relaxed"
mkdir -p ${OUTPUT_DIR}

echo "Step 5: Filter (RNA-seq relaxed) - ${PAIR_ID}"
echo "Start: $(date)"

# Use relaxed filtering for RNA-seq
gatk FilterMutectCalls \
    -R ${REFERENCE} \
    -V ${MUTECT_DIR}/${PAIR_ID}_unfiltered.vcf.gz \
    --contamination-table ${CONTAM_DIR}/${PAIR_ID}_contamination.table \
    --tumor-segmentation ${CONTAM_DIR}/${PAIR_ID}_segments.table \
    --ob-priors ${MUTECT_DIR}/${PAIR_ID}_read_orientation_model.tar.gz \
    --min-median-base-quality 0 \
    --min-median-mapping-quality 0 \
    -O ${OUTPUT_DIR}/${PAIR_ID}_filtered.vcf.gz

TOTAL=$(zgrep -v "^#" ${OUTPUT_DIR}/${PAIR_ID}_filtered.vcf.gz | wc -l)
PASSED=$(zgrep -v "^#" ${OUTPUT_DIR}/${PAIR_ID}_filtered.vcf.gz | grep -w "PASS" | wc -l)
echo "Total: ${TOTAL}, PASS: ${PASSED}"
echo "End: $(date)"
