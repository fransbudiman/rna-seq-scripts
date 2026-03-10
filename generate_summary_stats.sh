#!/bin/bash
# Generate comprehensive summary statistics

WORK_DIR="/scratch/frans/rna-seq"
OUTPUT_FILE="${WORK_DIR}/pipeline_summary_report.txt"

echo "========================================" > ${OUTPUT_FILE}
echo "Mutect2 RNA-seq Pipeline Summary Report" >> ${OUTPUT_FILE}
echo "========================================" >> ${OUTPUT_FILE}
echo "Generated: $(date)" >> ${OUTPUT_FILE}
echo "" >> ${OUTPUT_FILE}

# Step 1: Mutect2 Calling
echo "Step 1: Mutect2 Calling" >> ${OUTPUT_FILE}
echo "----------------------" >> ${OUTPUT_FILE}
MUTECT_FILES=$(ls ${WORK_DIR}/results/mutect2_calls/*_unfiltered.vcf.gz 2>/dev/null | wc -l)
echo "Completed pairs: ${MUTECT_FILES}/66" >> ${OUTPUT_FILE}

TOTAL_UNFILTERED=0
for vcf in ${WORK_DIR}/results/mutect2_calls/*_unfiltered.vcf.gz; do
    COUNT=$(zgrep -v "^#" ${vcf} | wc -l)
    TOTAL_UNFILTERED=$((TOTAL_UNFILTERED + COUNT))
done
echo "Total unfiltered variants: ${TOTAL_UNFILTERED}" >> ${OUTPUT_FILE}
echo "Average per pair: $((TOTAL_UNFILTERED / 66))" >> ${OUTPUT_FILE}
echo "" >> ${OUTPUT_FILE}

# Step 2: Orientation Models
echo "Step 2: Read Orientation Models" >> ${OUTPUT_FILE}
echo "-------------------------------" >> ${OUTPUT_FILE}
ORIENT_FILES=$(ls ${WORK_DIR}/results/mutect2_calls/*_read_orientation_model.tar.gz 2>/dev/null | wc -l)
echo "Completed: ${ORIENT_FILES}/66" >> ${OUTPUT_FILE}
echo "" >> ${OUTPUT_FILE}

# Step 3: Pileup Summaries
echo "Step 3: Pileup Summaries" >> ${OUTPUT_FILE}
echo "------------------------" >> ${OUTPUT_FILE}
TUMOR_PILEUP=$(ls ${WORK_DIR}/results/pileup_summaries/*_tumor_pileups.table 2>/dev/null | wc -l)
NORMAL_PILEUP=$(ls ${WORK_DIR}/results/pileup_summaries/*_normal_pileups.table 2>/dev/null | wc -l)
echo "Tumor pileups: ${TUMOR_PILEUP}/66" >> ${OUTPUT_FILE}
echo "Normal pileups: ${NORMAL_PILEUP}/66" >> ${OUTPUT_FILE}
echo "" >> ${OUTPUT_FILE}

# Step 4: Contamination
echo "Step 4: Contamination Estimates" >> ${OUTPUT_FILE}
echo "-------------------------------" >> ${OUTPUT_FILE}
CONTAM_FILES=$(ls ${WORK_DIR}/results/contamination/*_contamination.table 2>/dev/null | wc -l)
echo "Completed: ${CONTAM_FILES}/66" >> ${OUTPUT_FILE}

# Contamination statistics
echo "" >> ${OUTPUT_FILE}
echo "Contamination range:" >> ${OUTPUT_FILE}
for file in ${WORK_DIR}/results/contamination/*_contamination.table; do
    grep -v "^sample" ${file} | awk '{print $2}'
done | sort -n | awk 'NR==1 {min=$1} {max=$1} END {print "  Min: " min "\n  Max: " max}' >> ${OUTPUT_FILE}
echo "" >> ${OUTPUT_FILE}

# Step 5: Filtered Variants
echo "Step 5: Filtered Variants (Relaxed)" >> ${OUTPUT_FILE}
echo "------------------------------------" >> ${OUTPUT_FILE}
FILTER_FILES=$(ls ${WORK_DIR}/results/filtered_calls_relaxed/*_filtered.vcf.gz 2>/dev/null | wc -l)
echo "Completed: ${FILTER_FILES}/66" >> ${OUTPUT_FILE}

TOTAL_FILTERED=0
TOTAL_PASS=0
for vcf in ${WORK_DIR}/results/filtered_calls_relaxed/*_filtered.vcf.gz; do
    TOTAL=$(zgrep -v "^#" ${vcf} | wc -l)
    PASSED=$(zgrep -v "^#" ${vcf} | grep -w "PASS" | wc -l)
    TOTAL_FILTERED=$((TOTAL_FILTERED + TOTAL))
    TOTAL_PASS=$((TOTAL_PASS + PASSED))
done

echo "Total variants: ${TOTAL_FILTERED}" >> ${OUTPUT_FILE}
echo "PASS variants: ${TOTAL_PASS}" >> ${OUTPUT_FILE}
echo "Average PASS per pair: $((TOTAL_PASS / 66))" >> ${OUTPUT_FILE}
PASS_RATE=$(awk "BEGIN {printf \"%.1f\", ${TOTAL_PASS}/${TOTAL_FILTERED}*100}")
echo "Overall PASS rate: ${PASS_RATE}%" >> ${OUTPUT_FILE}
echo "" >> ${OUTPUT_FILE}

# Per-pair statistics
echo "Per-Pair PASS Variant Counts:" >> ${OUTPUT_FILE}
echo "-----------------------------" >> ${OUTPUT_FILE}
printf "%-12s %10s %10s %8s\n" "Pair" "Total" "PASS" "Rate(%)" >> ${OUTPUT_FILE}
for vcf in ${WORK_DIR}/results/filtered_calls_relaxed/*_filtered.vcf.gz; do
    PAIR=$(basename ${vcf} _filtered.vcf.gz)
    TOTAL=$(zgrep -v "^#" ${vcf} | wc -l)
    PASSED=$(zgrep -v "^#" ${vcf} | grep -w "PASS" | wc -l)
    PERCENT=$(awk "BEGIN {if(${TOTAL}>0) printf \"%.1f\", ${PASSED}/${TOTAL}*100; else print 0}")
    printf "%-12s %10s %10s %8s\n" ${PAIR} ${TOTAL} ${PASSED} ${PERCENT} >> ${OUTPUT_FILE}
done | sort -k2 -rn >> ${OUTPUT_FILE}

echo "" >> ${OUTPUT_FILE}

# Filter reasons summary
echo "Top Filter Reasons (pair_01 example):" >> ${OUTPUT_FILE}
echo "--------------------------------------" >> ${OUTPUT_FILE}
zgrep -v "^#" ${WORK_DIR}/results/filtered_calls_relaxed/pair_01_filtered.vcf.gz | \
    cut -f7 | sort | uniq -c | sort -rn | head -15 >> ${OUTPUT_FILE}

echo "" >> ${OUTPUT_FILE}
echo "========================================" >> ${OUTPUT_FILE}
echo "Report saved to: ${OUTPUT_FILE}" >> ${OUTPUT_FILE}
echo "========================================" >> ${OUTPUT_FILE}

# Display to screen
cat ${OUTPUT_FILE}