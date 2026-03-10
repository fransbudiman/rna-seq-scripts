#!/bin/bash
#SBATCH --job-name=mutect2_pair30
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=frans.budiman@alumni.utoronto.ca
#SBATCH --time=24:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=8
#SBATCH --output=/scratch/rad123/FINAL_MUTECT2_ANALYSIS/logs/mutect2_pair30_%j.out
#SBATCH --error=/scratch/rad123/FINAL_MUTECT2_ANALYSIS/logs/mutect2_pair30_%j.err

# Load modules
module load StdEnv/2023
module load gatk
module load samtools

# Source resource paths
source /scratch/rad123/FINAL_MUTECT2_ANALYSIS/resources/resource_paths_with_rg.sh

# Pair 30 details
TUMOR_BAM="/scratch/rad123/FINAL_MUTECT2_ANALYSIS/bams_with_rg/24-13263-A-02-00_with_rg.bam"
NORMAL_BAM="/scratch/rad123/FINAL_MUTECT2_ANALYSIS/bams_with_rg/24-12924-A-02-00_with_rg.bam"
TUMOR_NAME="24-13263-A-02-00"
NORMAL_NAME="24-12924-A-02-00"
PAIR_ID="pair_30"

# Output directory
OUTPUT_DIR="${WORK_DIR}/results/test_pair30"
mkdir -p ${OUTPUT_DIR}

# Panel of Normals
PON="${WORK_DIR}/results/pon/final/rnaseq_panel_of_normals.vcf.gz"

echo "======================================"
echo "Starting Mutect2 calling for ${PAIR_ID}"
echo "RNA-seq mode (mapping quality filters disabled)"
echo "======================================"
echo "Start time: $(date)"
echo ""
echo "Tumor: ${TUMOR_NAME}"
echo "Normal: ${NORMAL_NAME}"
echo ""

# Run Mutect2 with RNA-seq specific settings
# Key changes:
# 1. --disable-read-filter MappingQualityAvailableReadFilter
# 2. --disable-read-filter MappingQualityReadFilter  
# 3. --dont-use-soft-clipped-bases (RNA splicing creates soft clips)
# 4. --min-base-quality-score 20 (stricter base quality for RNA)

echo "Running Mutect2 with RNA-seq settings..."
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
    echo "Mutect2 calling COMPLETED successfully"
    echo "======================================"
    echo "End time: $(date)"
    echo ""
    
    # Check outputs
    echo "Checking output files..."
    if [ -f "${OUTPUT_DIR}/${PAIR_ID}_unfiltered.vcf.gz" ]; then
        VCF_SIZE=$(ls -lh ${OUTPUT_DIR}/${PAIR_ID}_unfiltered.vcf.gz | awk '{print $5}')
        VARIANT_COUNT=$(zgrep -v "^#" ${OUTPUT_DIR}/${PAIR_ID}_unfiltered.vcf.gz | wc -l)
        echo "  ✓ Unfiltered VCF: ${VCF_SIZE}, ${VARIANT_COUNT} variants"
        
        # Variant type breakdown
        SNV_COUNT=$(zgrep -v "^#" ${OUTPUT_DIR}/${PAIR_ID}_unfiltered.vcf.gz | awk '{if(length($4)==1 && length($5)==1) print}' | wc -l)
        INDEL_COUNT=$(zgrep -v "^#" ${OUTPUT_DIR}/${PAIR_ID}_unfiltered.vcf.gz | awk '{if(length($4)!=1 || length($5)!=1) print}' | wc -l)
        echo "    SNVs: ${SNV_COUNT}"
        echo "    Indels: ${INDEL_COUNT}"
    else
        echo "  ✗ Unfiltered VCF not found"
    fi
    
    if [ -f "${OUTPUT_DIR}/${PAIR_ID}_f1r2.tar.gz" ]; then
        F1R2_SIZE=$(ls -lh ${OUTPUT_DIR}/${PAIR_ID}_f1r2.tar.gz | awk '{print $5}')
        echo "  ✓ F1R2 file: ${F1R2_SIZE}"
    else
        echo "  ✗ F1R2 file not found"
    fi
    
    echo ""
    echo "First 10 variants:"
    zgrep -v "^#" ${OUTPUT_DIR}/${PAIR_ID}_unfiltered.vcf.gz | head -10 | cut -f1-8
    
    echo ""
    echo "Chromosome distribution:"
    zgrep -v "^#" ${OUTPUT_DIR}/${PAIR_ID}_unfiltered.vcf.gz | cut -f1 | sort | uniq -c | head -20
    
else
    echo ""
    echo "======================================"
    echo "Mutect2 calling FAILED"
    echo "======================================"
    echo "Check the error log for details"
    exit ${EXIT_CODE}
fi