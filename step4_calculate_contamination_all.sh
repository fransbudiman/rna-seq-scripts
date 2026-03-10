#!/bin/bash
#SBATCH --job-name=contamination
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=frans.budiman@alumni.utoronto.ca
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --array=1-66
#SBATCH --output=/scratch/frans/rna-seq/logs/contamination_%A_%a.out
#SBATCH --error=/scratch/frans/rna-seq/logs/contamination_%A_%a.err

module load StdEnv/2023
module load gatk

WORK_DIR="/scratch/frans/rna-seq"
cd ${WORK_DIR}
source ${WORK_DIR}/resources/resource_paths_with_rg.sh

PAIR_LINE=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" ${SAMPLE_FILE})
IFS=$'\t' read -r TUMOR_BAM NORMAL_BAM TUMOR_NAME NORMAL_NAME PAIR_ID <<< "${PAIR_LINE}"

INPUT_DIR="${WORK_DIR}/results/pileup_summaries"
OUTPUT_DIR="${WORK_DIR}/results/contamination"
mkdir -p ${OUTPUT_DIR}

echo "Step 4: Calculate Contamination - ${PAIR_ID}"
echo "Start: $(date)"

gatk CalculateContamination \
    -I ${INPUT_DIR}/${PAIR_ID}_tumor_pileups.table \
    -matched ${INPUT_DIR}/${PAIR_ID}_normal_pileups.table \
    -O ${OUTPUT_DIR}/${PAIR_ID}_contamination.table \
    --tumor-segmentation ${OUTPUT_DIR}/${PAIR_ID}_segments.table

echo "End: $(date)"
