#!/bin/bash
# Pre-flight check before submitting all 66 pairs

echo "======================================"
echo "Pre-flight Check for All 66 Pairs"
echo "======================================"
echo ""

# Source paths
source /scratch/frans/rna-seq/resources/resource_paths_with_rg.sh
# Check critical files
echo "1. Checking critical resource files..."
ERRORS=0

if [ -f "${REFERENCE}" ]; then
    echo "  ✓ Reference genome"
else
    echo "  ✗ Reference genome NOT FOUND"
    ((ERRORS++))
fi

if [ -f "${GNOMAD}" ] && [ -f "${GNOMAD}.tbi" ]; then
    echo "  ✓ gnomAD resource"
else
    echo "  ✗ gnomAD resource or index NOT FOUND"
    ((ERRORS++))
fi

PON="${WORK_DIR}/results/pon/final/rnaseq_panel_of_normals.vcf.gz"
if [ -f "${PON}" ] && [ -f "${PON}.tbi" ]; then
    PON_SITES=$(zgrep -v "^#" ${PON} | wc -l)
    echo "  ✓ Panel of Normals (${PON_SITES} sites)"
else
    echo "  ✗ Panel of Normals or index NOT FOUND"
    ((ERRORS++))
fi

if [ -f "${INTERVALS}" ]; then
    echo "  ✓ Intervals file"
else
    echo "  ✗ Intervals file NOT FOUND"
    ((ERRORS++))
fi

echo ""

# Check sample file
echo "2. Checking sample pairs file..."
if [ -f "${SAMPLE_FILE}" ]; then
    PAIR_COUNT=$(tail -n +2 ${SAMPLE_FILE} | wc -l)
    echo "  ✓ Sample file: ${PAIR_COUNT} pairs"
    
    if [ ${PAIR_COUNT} -ne 66 ]; then
        echo "  ⚠ WARNING: Expected 66 pairs, found ${PAIR_COUNT}"
    fi
else
    echo "  ✗ Sample file NOT FOUND: ${SAMPLE_FILE}"
    ((ERRORS++))
fi

echo ""

# Check BAM files
echo "3. Checking BAM files (sampling first 5 pairs)..."
BAM_ERRORS=0

for i in {1..5}; do
    PAIR_LINE=$(sed -n "$((i + 1))p" ${SAMPLE_FILE})
    TUMOR_BAM=$(echo "${PAIR_LINE}" | awk '{print $1}')
    NORMAL_BAM=$(echo "${PAIR_LINE}" | awk '{print $2}')
    PAIR_ID=$(echo "${PAIR_LINE}" | awk '{print $5}')
    
    TUMOR_OK=true
    NORMAL_OK=true
    
    if [ ! -f "${TUMOR_BAM}" ]; then
        echo "  ✗ ${PAIR_ID} tumor BAM missing"
        TUMOR_OK=false
        ((BAM_ERRORS++))
    fi
    
    if [ ! -f "${TUMOR_BAM}.bai" ]; then
        echo "  ✗ ${PAIR_ID} tumor BAM index missing"
        TUMOR_OK=false
        ((BAM_ERRORS++))
    fi
    
    if [ ! -f "${NORMAL_BAM}" ]; then
        echo "  ✗ ${PAIR_ID} normal BAM missing"
        NORMAL_OK=false
        ((BAM_ERRORS++))
    fi
    
    if [ ! -f "${NORMAL_BAM}.bai" ]; then
        echo "  ✗ ${PAIR_ID} normal BAM index missing"
        NORMAL_OK=false
        ((BAM_ERRORS++))
    fi
    
    if ${TUMOR_OK} && ${NORMAL_OK}; then
        echo "  ✓ ${PAIR_ID} - both BAMs present"
    fi
done

if [ ${BAM_ERRORS} -eq 0 ]; then
    echo "  ✓ Sample BAMs check passed"
else
    echo "  ⚠ Found ${BAM_ERRORS} BAM issues in sample"
fi

echo ""

# Check modules
echo "4. Checking required modules..."
module load StdEnv/2023
module load gatk
module load samtools

if command -v gatk &> /dev/null; then
    echo "  ✓ GATK available"
else
    echo "  ✗ GATK not available"
    ((ERRORS++))
fi

if command -v samtools &> /dev/null; then
    echo "  ✓ samtools available"
else
    echo "  ✗ samtools not available"
    ((ERRORS++))
fi

echo ""

# Check output directory
echo "5. Checking output directory..."
OUTPUT_DIR="${WORK_DIR}/results/mutect2_calls"
mkdir -p ${OUTPUT_DIR}

if [ -d "${OUTPUT_DIR}" ] && [ -w "${OUTPUT_DIR}" ]; then
    echo "  ✓ Output directory ready: ${OUTPUT_DIR}"
else
    echo "  ✗ Cannot create/write to output directory"
    ((ERRORS++))
fi

# Check for existing results
EXISTING=$(ls ${OUTPUT_DIR}/*_unfiltered.vcf.gz 2>/dev/null | wc -l)
if [ ${EXISTING} -gt 0 ]; then
    echo "  ⚠ WARNING: ${EXISTING} VCF files already exist in output directory"
    echo "    Existing files will be overwritten!"
fi

echo ""

# Check logs directory
echo "6. Checking logs directory..."
LOG_DIR="${WORK_DIR}/logs"
mkdir -p ${LOG_DIR}

if [ -d "${LOG_DIR}" ] && [ -w "${LOG_DIR}" ]; then
    echo "  ✓ Logs directory ready: ${LOG_DIR}"
else
    echo "  ✗ Cannot create/write to logs directory"
    ((ERRORS++))
fi

echo ""

# Disk space check
echo "7. Checking disk space..."
AVAILABLE=$(df -h ${WORK_DIR} | tail -1 | awk '{print $4}')
echo "  Available space in ${WORK_DIR}: ${AVAILABLE}"

# Estimate space needed (rough estimate: ~100MB per pair)
ESTIMATED="~7GB for 66 VCFs + indices"
echo "  Estimated space needed: ${ESTIMATED}"

echo ""
echo "======================================"
echo "Pre-flight Check Summary"
echo "======================================"

if [ ${ERRORS} -eq 0 ]; then
    echo "✓ All checks PASSED"
    echo ""
    echo "Ready to submit!"
    echo "Run: sbatch scripts/run_mutect2_all_pairs_rnaseq.sh"
    echo ""
    echo "Monitor with:"
    echo "  squeue -u $USER"
    echo "  bash scripts/monitor_mutect2_progress.sh"
else
    echo "✗ Found ${ERRORS} critical errors"
    echo ""
    echo "Please fix the errors above before submitting"
    exit 1
fi

echo ""
