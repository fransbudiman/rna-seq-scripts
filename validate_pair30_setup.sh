#!/bin/bash
# Validate setup before running Mutect2 on pair_30

echo "======================================"
echo "Validation Check for pair_30"
echo "======================================"
echo ""

# Source resource paths
source /scratch/rad123/FINAL_MUTECT2_ANALYSIS/resources/resource_paths_with_rg.sh

# Pair 30 details
TUMOR_BAM="/scratch/rad123/FINAL_MUTECT2_ANALYSIS/bams_with_rg/24-13263-A-02-00_with_rg.bam"
NORMAL_BAM="/scratch/rad123/FINAL_MUTECT2_ANALYSIS/bams_with_rg/24-12924-A-02-00_with_rg.bam"
TUMOR_NAME="24-13263-A-02-00"
NORMAL_NAME="24-12924-A-02-00"
PON="${WORK_DIR}/results/pon/final/rnaseq_panel_of_normals.vcf.gz"

# Check modules
echo "1. Checking modules..."
module load StdEnv/2023
module load gatk
module load samtools

if command -v gatk &> /dev/null; then
    GATK_VERSION=$(gatk --version 2>&1 | grep "GATK" | head -1)
    echo "  ✓ GATK loaded: ${GATK_VERSION}"
else
    echo "  ✗ GATK not found"
    exit 1
fi

if command -v samtools &> /dev/null; then
    SAMTOOLS_VERSION=$(samtools --version | head -1)
    echo "  ✓ samtools loaded: ${SAMTOOLS_VERSION}"
else
    echo "  ✗ samtools not found"
    exit 1
fi
echo ""

# Check reference files
echo "2. Checking reference files..."
echo "  Reference: ${REFERENCE}"
if [ -f "${REFERENCE}" ]; then
    REF_SIZE=$(ls -lh ${REFERENCE} | awk '{print $5}')
    echo "    ✓ Exists (${REF_SIZE})"
else
    echo "    ✗ NOT FOUND"
    exit 1
fi

echo "  Reference index: ${REFERENCE}.fai"
if [ -f "${REFERENCE}.fai" ]; then
    echo "    ✓ Exists"
else
    echo "    ✗ NOT FOUND - Creating index..."
    samtools faidx ${REFERENCE}
fi

echo "  Reference dict: ${REFERENCE%.fasta}.dict"
if [ -f "${REFERENCE%.fasta}.dict" ]; then
    echo "    ✓ Exists"
else
    echo "    ✗ NOT FOUND"
    exit 1
fi
echo ""

# Check gnomAD
echo "3. Checking gnomAD resource..."
echo "  gnomAD VCF: ${GNOMAD}"
if [ -f "${GNOMAD}" ]; then
    GNOMAD_SIZE=$(ls -lh ${GNOMAD} | awk '{print $5}')
    echo "    ✓ Exists (${GNOMAD_SIZE})"
else
    echo "    ✗ NOT FOUND"
    exit 1
fi

if [ -f "${GNOMAD}.tbi" ]; then
    echo "    ✓ Index exists"
else
    echo "    ✗ Index NOT FOUND"
    exit 1
fi
echo ""

# Check PON
echo "4. Checking Panel of Normals..."
echo "  PON VCF: ${PON}"
if [ -f "${PON}" ]; then
    PON_SIZE=$(ls -lh ${PON} | awk '{print $5}')
    PON_VARIANTS=$(zgrep -v "^#" ${PON} | wc -l)
    echo "    ✓ Exists (${PON_SIZE}, ${PON_VARIANTS} sites)"
else
    echo "    ✗ NOT FOUND"
    exit 1
fi

if [ -f "${PON}.tbi" ]; then
    echo "    ✓ Index exists"
else
    echo "    ✗ Index NOT FOUND - Creating..."
    gatk IndexFeatureFile -I ${PON}
fi
echo ""

# Check intervals
echo "5. Checking intervals file..."
echo "  Intervals: ${INTERVALS}"
if [ -f "${INTERVALS}" ]; then
    INTERVAL_COUNT=$(grep -v "^@" ${INTERVALS} | wc -l)
    echo "    ✓ Exists (${INTERVAL_COUNT} intervals)"
    echo "    First 5 intervals:"
    grep -v "^@" ${INTERVALS} | head -5 | sed 's/^/      /'
else
    echo "    ✗ NOT FOUND"
    exit 1
fi
echo ""

# Check BAM files
echo "6. Checking BAM files..."
echo "  Tumor BAM: ${TUMOR_BAM}"
if [ -f "${TUMOR_BAM}" ]; then
    TUMOR_SIZE=$(ls -lh ${TUMOR_BAM} | awk '{print $5}')
    echo "    ✓ Exists (${TUMOR_SIZE})"
    
    # Check index
    if [ -f "${TUMOR_BAM}.bai" ]; then
        echo "    ✓ Index exists"
    else
        echo "    ✗ Index NOT FOUND"
        exit 1
    fi
    
    # Check read groups
    echo "    Read groups:"
    samtools view -H ${TUMOR_BAM} | grep "^@RG" | sed 's/^/      /'
    
    # Get sample name from RG
    TUMOR_RG_SM=$(samtools view -H ${TUMOR_BAM} | grep "^@RG" | sed 's/.*SM:\([^\t]*\).*/\1/' | head -1)
    echo "    Sample name in BAM: ${TUMOR_RG_SM}"
    
    if [ "${TUMOR_RG_SM}" == "${TUMOR_NAME}" ]; then
        echo "    ✓ Sample name matches"
    else
        echo "    ⚠ WARNING: Sample name mismatch!"
        echo "      Expected: ${TUMOR_NAME}"
        echo "      Found: ${TUMOR_RG_SM}"
    fi
else
    echo "    ✗ NOT FOUND"
    exit 1
fi
echo ""

echo "  Normal BAM: ${NORMAL_BAM}"
if [ -f "${NORMAL_BAM}" ]; then
    NORMAL_SIZE=$(ls -lh ${NORMAL_BAM} | awk '{print $5}')
    echo "    ✓ Exists (${NORMAL_SIZE})"
    
    # Check index
    if [ -f "${NORMAL_BAM}.bai" ]; then
        echo "    ✓ Index exists"
    else
        echo "    ✗ Index NOT FOUND"
        exit 1
    fi
    
    # Check read groups
    echo "    Read groups:"
    samtools view -H ${NORMAL_BAM} | grep "^@RG" | sed 's/^/      /'
    
    # Get sample name from RG
    NORMAL_RG_SM=$(samtools view -H ${NORMAL_BAM} | grep "^@RG" | sed 's/.*SM:\([^\t]*\).*/\1/' | head -1)
    echo "    Sample name in BAM: ${NORMAL_RG_SM}"
    
    if [ "${NORMAL_RG_SM}" == "${NORMAL_NAME}" ]; then
        echo "    ✓ Sample name matches"
    else
        echo "    ⚠ WARNING: Sample name mismatch!"
        echo "      Expected: ${NORMAL_NAME}"
        echo "      Found: ${NORMAL_RG_SM}"
    fi
else
    echo "    ✗ NOT FOUND"
    exit 1
fi
echo ""

# Check output directory
echo "7. Checking output directory..."
OUTPUT_DIR="${WORK_DIR}/results/test_pair30"
mkdir -p ${OUTPUT_DIR}
if [ -d "${OUTPUT_DIR}" ]; then
    echo "  ✓ Output directory ready: ${OUTPUT_DIR}"
else
    echo "  ✗ Cannot create output directory"
    exit 1
fi
echo ""

echo "======================================"
echo "All validation checks PASSED! ✓"
echo "======================================"
echo ""
echo "Ready to run Mutect2 on pair_30"
echo "Submit with: sbatch scripts/test_mutect2_pair30.sh"