#!/bin/bash
#SBATCH --job-name=orientation
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=frans.budiman@alumni.utoronto.ca
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --array=1-1
#SBATCH --output=/scratch/frans/rna-seq/logs/orientation_%A_%a.out
#SBATCH --error=/scratch/frans/rna-seq/logs/orientation_%A_%a.err

module load StdEnv/2023
module load gatk

WORK_DIR="/scratch/frans/rna-seq"
cd ${WORK_DIR}
source ${WORK_DIR}/resources/resource_paths_with_rg.sh

PAIR_LINE=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" ${SAMPLE_FILE})
IFS=$'\t' read -r TUMOR_BAM NORMAL_BAM TUMOR_NAME NORMAL_NAME PAIR_ID <<< "${PAIR_LINE}"

INPUT_DIR="${WORK_DIR}/results/mutect2_calls"
F1R2_FILE="${INPUT_DIR}/${PAIR_ID}_f1r2.tar.gz"

echo "Step 2: Learn Read Orientation - ${PAIR_ID}"
echo "Start: $(date)"

gatk LearnReadOrientationModel \
    -I ${F1R2_FILE} \
    -O ${INPUT_DIR}/${PAIR_ID}_read_orientation_model.tar.gz

echo "End: $(date)"
