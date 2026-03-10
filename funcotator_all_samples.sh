#!/bin/bash
#SBATCH --job-name=funcotator
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=frans.budiman@alumni.utoronto.ca
#SBATCH --time=48:00:00
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --array=1-1
#SBATCH --output=logs/funcotator_%A_%a.out
#SBATCH --error=logs/funcotator_%A_%a.err

module load StdEnv/2023
module load gatk/4.4.0.0

WORK_DIR="/scratch/rad123/FINAL_MUTECT2_ANALYSIS"
cd ${WORK_DIR}
source ${WORK_DIR}/resources/resource_paths_with_rg.sh

PAIR_LINE=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" ${SAMPLE_FILE})
IFS=$'\t' read -r TUMOR_BAM NORMAL_BAM TUMOR_NAME NORMAL_NAME PAIR_ID <<< "${PAIR_LINE}"

INPUT_VCF="${WORK_DIR}/results/filtered_calls_relaxed/${PAIR_ID}_filtered.vcf.gz"
OUTPUT_DIR="${WORK_DIR}/results/funcotator_annotated"
mkdir -p ${OUTPUT_DIR}

FUNCOTATOR_DATA="${WORK_DIR}/funcotator_datasources/funcotator_dataSources.v1.8.hg38.20230908s"

echo "Funcotator annotation - ${PAIR_ID}"
echo "Start: $(date)"

gatk Funcotator \
    --variant ${INPUT_VCF} \
    --reference ${REFERENCE} \
    --ref-version hg38 \
    --data-sources-path ${FUNCOTATOR_DATA} \
    --output ${OUTPUT_DIR}/${PAIR_ID}_all_variants.maf \
    --output-file-format MAF \
    --transcript-selection-mode BEST_EFFECT \
    --remove-filtered-variants false

echo "End: $(date)"