#!/bin/bash
#SBATCH --job-name=vep_annotate
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=frans.budiman@alumni.utoronto.ca
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --array=1-1
#SBATCH --output=logs/vep_%A_%a.out
#SBATCH --error=logs/vep_%A_%a.err

module load apptainer

WORK_DIR="/scratch/rad123/FINAL_MUTECT2_ANALYSIS"
VEP_DATA="/scratch/rad123/vep_data"
VEP_SIF="${VEP_DATA}/vep.sif"
VEP_CACHE="${VEP_DATA}/homo_sapiens"

cd ${WORK_DIR}
source ${WORK_DIR}/resources/resource_paths_with_rg.sh

# Get pair info
PAIR_LINE=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" ${SAMPLE_FILE})
IFS=$'\t' read -r TUMOR_BAM NORMAL_BAM TUMOR_NAME NORMAL_NAME PAIR_ID <<< "${PAIR_LINE}"

INPUT_VCF="${WORK_DIR}/results/filtered_calls_relaxed/${PAIR_ID}_filtered.vcf.gz"
OUTPUT_DIR="${WORK_DIR}/results/vep_annotated"
mkdir -p ${OUTPUT_DIR}

echo "VEP annotation - ${PAIR_ID}"
echo "Start: $(date)"

# Run VEP using Singularity container
apptainer exec \
    --bind ${WORK_DIR}:${WORK_DIR} \
    --bind ${VEP_CACHE}:${VEP_CACHE} \
    ${VEP_SIF} \
    vep \
    --input_file ${INPUT_VCF} \
    --output_file ${OUTPUT_DIR}/${PAIR_ID}_vep.vcf.gz \
    --vcf \
    --compress_output bgzip \
    --species homo_sapiens \
    --assembly GRCh38 \
    --cache \
    --dir_cache ${VEP_CACHE} \
    --cache_version 115 \
    --offline \
    --fork 4 \
    --everything \
    --force_overwrite \
    --buffer_size 5000

EXIT_CODE=$?

if [ ${EXIT_CODE} -eq 0 ]; then
    echo "Success!"
    
    # Count annotated variants
    if [ -f "${OUTPUT_DIR}/${PAIR_ID}_vep.vcf.gz" ]; then
        VARIANTS=$(zgrep -v "^#" ${OUTPUT_DIR}/${PAIR_ID}_vep.vcf.gz | wc -l)
        echo "Annotated variants: ${VARIANTS}"
    fi
else
    echo "Failed with exit code: ${EXIT_CODE}"
fi

echo "End: $(date)"