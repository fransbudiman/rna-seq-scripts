#!/bin/bash
# Check mapping quality distribution in BAM files

module load samtools/1.18

TUMOR_BAM="/scratch/frans/rna-seq/bams_with_rg/24-13263-A-02-00_with_rg.bam"
NORMAL_BAM="/scratch/frans/rna-seq/bams_with_rg/24-12924-A-02-00_with_rg.bam"

echo "Checking mapping quality (MAPQ) values in BAMs"
echo "=============================================="
echo ""

echo "Tumor BAM: ${TUMOR_BAM}"
echo "Sampling first 100,000 reads from chr1:1000000-2000000:"
samtools view ${TUMOR_BAM} chr1:1000000-2000000 | head -100000 | awk '{print $5}' | sort -n | uniq -c | head -20
echo ""

echo "Normal BAM: ${NORMAL_BAM}"
echo "Sampling first 100,000 reads from chr1:1000000-2000000:"
samtools view ${NORMAL_BAM} chr1:1000000-2000000 | head -100000 | awk '{print $5}' | sort -n | uniq -c | head -20
echo ""

echo "Note: MAPQ = 255 means 'not available' or 'not applicable'"
echo "      MAPQ = 0 means read maps to multiple locations"
echo "      MAPQ > 0 means confidently mapped (higher = better)"