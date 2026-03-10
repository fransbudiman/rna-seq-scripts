#!/bin/bash
# Extract mutations in cancer-related genes (FIXED)

WORK_DIR="/scratch/rad123/FINAL_MUTECT2_ANALYSIS"
OUTPUT_DIR="${WORK_DIR}/cancer_gene_mutations"
mkdir -p ${OUTPUT_DIR}

# Common cancer genes list
CANCER_GENES="TP53 KRAS EGFR BRAF PIK3CA PTEN APC BRCA1 BRCA2 ATM NRAS \
              ERBB2 MET ALK ROS1 RET FGFR1 FGFR2 FGFR3 IDH1 IDH2 \
              CDKN2A SMAD4 STK11 CTNNB1 HRAS NF1 RB1 VHL"

echo "Extracting mutations in cancer-related genes..."

for gene in ${CANCER_GENES}; do
    echo "Processing ${gene}..."
    
    # Extract from all samples (with proper header)
    echo -e "Sample\tGene\tChromosome\tPosition\tVariant_Classification\tProtein_Change" > \
        ${OUTPUT_DIR}/${gene}_mutations.txt
    
    grep "^${gene}" ${WORK_DIR}/results/funcotator_pass_only/*.maf | \
        awk -F'\t' '{print FILENAME"\t"$1"\t"$5"\t"$6"\t"$9"\t"$42}' | \
        sed 's|.*/||; s|_pass_only.maf:|\t|' >> \
        ${OUTPUT_DIR}/${gene}_mutations.txt
    
    if [ $(wc -l < ${OUTPUT_DIR}/${gene}_mutations.txt) -gt 1 ]; then
        COUNT=$(($(wc -l < ${OUTPUT_DIR}/${gene}_mutations.txt) - 1))
        SAMPLES=$(tail -n +2 ${OUTPUT_DIR}/${gene}_mutations.txt | cut -f1 | sort -u | wc -l)
        echo "  Found ${COUNT} ${gene} mutations in ${SAMPLES} samples"
    else
        rm ${OUTPUT_DIR}/${gene}_mutations.txt
    fi
done

echo ""
echo "Cancer gene mutations saved to: ${OUTPUT_DIR}/"

# Detailed summary
echo ""
echo "Cancer Gene Mutation Summary:"
echo "=============================="
printf "%-10s %10s %10s %10s\n" "Gene" "Mutations" "Samples" "Mut/Sample"
printf "%-10s %10s %10s %10s\n" "----" "---------" "-------" "----------"

for gene in ${CANCER_GENES}; do
    if [ -f ${OUTPUT_DIR}/${gene}_mutations.txt ]; then
        COUNT=$(($(wc -l < ${OUTPUT_DIR}/${gene}_mutations.txt) - 1))
        SAMPLES=$(tail -n +2 ${OUTPUT_DIR}/${gene}_mutations.txt | cut -f1 | sort -u | wc -l)
        AVG=$(awk "BEGIN {printf \"%.1f\", ${COUNT}/${SAMPLES}}")
        printf "%-10s %10d %10d %10s\n" ${gene} ${COUNT} ${SAMPLES} ${AVG}
    fi
done

echo ""
echo "To view mutations in a specific gene:"
echo "  head ${OUTPUT_DIR}/TP53_mutations.txt"