#!/bin/bash
# Investigate why pair_30 has 0 variants

echo "======================================"
echo "Investigating pair_30 Results"
echo "======================================"
echo ""

WORK_DIR="/scratch/frans/rna-seq"
OUTPUT_DIR="${WORK_DIR}/results/test_pair30"

# 1. Check the VCF header
echo "1. VCF Header (checking for warnings/errors):"
zcat ${OUTPUT_DIR}/pair_30_unfiltered.vcf.gz | grep "^##" | tail -20
echo ""

# 2. Check the stats file
echo "2. Mutect2 Stats File:"
cat ${OUTPUT_DIR}/pair_30_unfiltered.vcf.gz.stats
echo ""

# 3. Check BAM files have reads in the interval regions
echo "3. Checking BAM coverage in calling regions..."
module load samtools

TUMOR_BAM="${WORK_DIR}/bams_with_rg/24-13263-A-02-00_with_rg.bam"
NORMAL_BAM="${WORK_DIR}/bams_with_rg/24-12924-A-02-00_with_rg.bam"
INTERVALS="${WORK_DIR}/resources/wgs_calling_regions.hg38.interval_list"

echo "Tumor BAM total reads:"
samtools view -c ${TUMOR_BAM}

echo "Normal BAM total reads:"
samtools view -c ${NORMAL_BAM}

echo ""
echo "Checking first interval region (chr1:10000-207666):"
echo "Tumor reads in region:"
samtools view -c ${TUMOR_BAM} chr1:10000-207666

echo "Normal reads in region:"
samtools view -c ${NORMAL_BAM} chr1:10000-207666

echo ""
echo "Checking a gene-rich region (chr1:1000000-2000000):"
echo "Tumor reads in region:"
samtools view -c ${TUMOR_BAM} chr1:1000000-2000000

echo "Normal reads in region:"
samtools view -c ${NORMAL_BAM} chr1:1000000-2000000

echo ""

# 4. Check chromosome naming
echo "4. Checking chromosome naming in BAMs vs Reference:"
echo "First 5 chromosomes in Tumor BAM:"
samtools view -H ${TUMOR_BAM} | grep "^@SQ" | head -5 | cut -f2

echo ""
echo "First 5 chromosomes in Normal BAM:"
samtools view -H ${NORMAL_BAM} | grep "^@SQ" | head -5 | cut -f2

echo ""
echo "First 5 chromosomes in Reference:"
grep "^@SQ" ${WORK_DIR}/resources/GRCh38_GIABv3_no_alt_analysis_set_maskedGRC_decoys_MAP2K3_KMT2C_KCNJ18.dict | head -5 | cut -f2

echo ""
echo "First 5 intervals:"
grep -v "^@" ${INTERVALS} | head -5

echo ""

# 5. Check the log files
echo "5. Checking for errors in log files:"
LOG_FILE=$(ls -t ${WORK_DIR}/logs/mutect2_pair30_*.err 2>/dev/null | head -1)
if [ -f "${LOG_FILE}" ]; then
    echo "Latest error log: ${LOG_FILE}"
    echo ""
    echo "Last 50 lines:"
    tail -50 ${LOG_FILE}
else
    echo "No error log found"
fi

echo ""
echo "======================================"
echo "Investigation Complete"
echo "======================================"