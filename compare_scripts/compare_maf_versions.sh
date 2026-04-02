#!/bin/bash
# Compare the three MAF versions between two runs

WORK_DIR="/scratch/frans/rna-seq"
OTHER_DIR="/project/rrg-bourqueg-ad/C3G/share/Lerner-Ellis_Sinai/RNA-seq/FINAL_MUTECT2_ANALYSIS"

OUTPUT="${WORK_DIR}/version_comparison.txt"

echo "Starting comparison..."
echo "Run 1: $WORK_DIR"
echo "Run 2: $OTHER_DIR"
echo "Output file: $OUTPUT"
echo ""

echo "===========================================================================================================" > ${OUTPUT}
echo "                                   MAF Version Comparison Report" >> ${OUTPUT}
echo "===========================================================================================================" >> ${OUTPUT}
printf "%-50s | %-40s\n" "RUN 1" "RUN 2" >> ${OUTPUT}
echo "-----------------------------------------------------------------------------------------------------------" >> ${OUTPUT}
printf "%-50s | %-40s\n" "$WORK_DIR" "$OTHER_DIR" >> ${OUTPUT}
echo "===========================================================================================================" >> ${OUTPUT}
echo "" >> ${OUTPUT}

printf "%-10s | %10s %10s %10s | %10s %10s %10s | %6s\n" \
    "Sample" "All" "Somatic" "PASS" "All" "Somatic" "PASS" "Match" >> ${OUTPUT}
echo "-----------------------------------------------------------------------------------------------------------" >> ${OUTPUT}

for pair_id in pair_{01..66}; do
    # Your run
    ALL1=$(grep -v "^#\|^Hugo_Symbol" \
          ${WORK_DIR}/results/funcotator_annotated/${pair_id}_all_variants.maf 2>/dev/null | wc -l)
    SOMATIC1=$(grep -v "^#\|^Hugo_Symbol" \
              ${WORK_DIR}/results/funcotator_somatic_only/${pair_id}_somatic_only.maf 2>/dev/null | wc -l)
    PASS1=$(grep -v "^#\|^Hugo_Symbol" \
           ${WORK_DIR}/results/funcotator_pass_only/${pair_id}_pass_only.maf 2>/dev/null | wc -l)
    
    # Coworker's run
    ALL2=$(grep -v "^#\|^Hugo_Symbol" \
          ${OTHER_DIR}/results/funcotator_annotated/${pair_id}_all_variants.maf 2>/dev/null | wc -l)
    SOMATIC2=$(grep -v "^#\|^Hugo_Symbol" \
              ${OTHER_DIR}/results/funcotator_somatic_only/${pair_id}_somatic_only.maf 2>/dev/null | wc -l)
    PASS2=$(grep -v "^#\|^Hugo_Symbol" \
           ${OTHER_DIR}/results/funcotator_pass_only/${pair_id}_pass_only.maf 2>/dev/null | wc -l)
    
    # Check if files exist
    if [ -f "${WORK_DIR}/results/funcotator_annotated/${pair_id}_all_variants.maf" ]; then
        # Check if PASS counts match
        if [ $PASS1 -eq $PASS2 ]; then
            MATCH="1"
        else
            MATCH="0"
        fi
        printf "%-10s | %10d %10d %10d | %10d %10d %10d | %6s\n" \
            ${pair_id} ${ALL1} ${SOMATIC1} ${PASS1} ${ALL2} ${SOMATIC2} ${PASS2} "${MATCH}" >> ${OUTPUT}
    else
        printf "%-10s | %10s %10s %10s | %10s %10s %10s | %6s\n" \
            ${pair_id} "N/A" "N/A" "N/A" "N/A" "N/A" "N/A" "-" >> ${OUTPUT}
    fi
done


echo "" >> ${OUTPUT}
echo "===========================================================================================================" >> ${OUTPUT}
echo "                                           SUMMARY TOTALS" >> ${OUTPUT}
echo "===========================================================================================================" >> ${OUTPUT}

# Only count samples that exist in BOTH runs
TOTAL_ALL1=0
TOTAL_SOMATIC1=0
TOTAL_PASS1=0
TOTAL_ALL2=0
TOTAL_SOMATIC2=0
TOTAL_PASS2=0

for pair_id in pair_{01..66}; do
    # Check if files exist in BOTH runs
    if [ -f "${WORK_DIR}/results/funcotator_annotated/${pair_id}_all_variants.maf" ] && \
       [ -f "${OTHER_DIR}/results/funcotator_annotated/${pair_id}_all_variants.maf" ]; then
        
        # Count RUN 1
        ALL1=$(grep -v "^#\|^Hugo_Symbol" ${WORK_DIR}/results/funcotator_annotated/${pair_id}_all_variants.maf | wc -l)
        SOMATIC1=$(grep -v "^#\|^Hugo_Symbol" ${WORK_DIR}/results/funcotator_somatic_only/${pair_id}_somatic_only.maf | wc -l)
        PASS1=$(grep -v "^#\|^Hugo_Symbol" ${WORK_DIR}/results/funcotator_pass_only/${pair_id}_pass_only.maf | wc -l)
        
        # Count RUN 2
        ALL2=$(grep -v "^#\|^Hugo_Symbol" ${OTHER_DIR}/results/funcotator_annotated/${pair_id}_all_variants.maf | wc -l)
        SOMATIC2=$(grep -v "^#\|^Hugo_Symbol" ${OTHER_DIR}/results/funcotator_somatic_only/${pair_id}_somatic_only.maf | wc -l)
        PASS2=$(grep -v "^#\|^Hugo_Symbol" ${OTHER_DIR}/results/funcotator_pass_only/${pair_id}_pass_only.maf | wc -l)
        
        # Add to totals
        TOTAL_ALL1=$((TOTAL_ALL1 + ALL1))
        TOTAL_SOMATIC1=$((TOTAL_SOMATIC1 + SOMATIC1))
        TOTAL_PASS1=$((TOTAL_PASS1 + PASS1))
        TOTAL_ALL2=$((TOTAL_ALL2 + ALL2))
        TOTAL_SOMATIC2=$((TOTAL_SOMATIC2 + SOMATIC2))
        TOTAL_PASS2=$((TOTAL_PASS2 + PASS2))
    fi
done

printf "\n%-20s | %30s | %30s\n" "Category" "Run 1" "Run 2" >> ${OUTPUT}
echo "-----------------------------------------------------------------------------------------------------------" >> ${OUTPUT}
printf "%-20s | %30d | %30d\n" "Total All Variants" ${TOTAL_ALL1} ${TOTAL_ALL2} >> ${OUTPUT}
printf "%-20s | %30d | %30d\n" "Total Somatic" ${TOTAL_SOMATIC1} ${TOTAL_SOMATIC2} >> ${OUTPUT}
printf "%-20s | %30d | %30d\n" "Total PASS" ${TOTAL_PASS1} ${TOTAL_PASS2} >> ${OUTPUT}
echo "" >> ${OUTPUT}
printf "%-20s | %30d\n" "Difference (PASS)" $((TOTAL_PASS1 - TOTAL_PASS2)) >> ${OUTPUT}

echo "===========================================================================================================" >> ${OUTPUT}

cat ${OUTPUT}