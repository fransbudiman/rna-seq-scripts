#!/bin/bash
# Filter pair_37 MAF for high-quality variants

WORK_DIR="/scratch/rad123/FINAL_MUTECT2_ANALYSIS"
SAMPLE="pair_53"

# Input MAF (somatic-only, PASS variants)
INPUT_MAF="${WORK_DIR}/results/funcotator_pass_only/${SAMPLE}_pass_only.maf"
OUTPUT_MAF="${WORK_DIR}/${SAMPLE}_filtered_high_quality.maf"

echo "Filtering ${SAMPLE} for high-quality variants..."
echo "Criteria:"
echo "  - PASS variants only"
echo "  - Somatic (n_alt_count = 0)"
echo "  - Tumor VAF >= 0.05 (5%)"
echo "  - Tumor depth >= 20 reads"
echo "  - Coding variants (Missense, Nonsense, Splice, Frameshift)"
echo ""

# Extract header
grep "^Hugo_Symbol" ${INPUT_MAF} > ${OUTPUT_MAF}

# Filter variants
# Columns: 81=t_alt_count, 82=t_ref_count, 83=n_alt_count, 84=n_ref_count, 9=Variant_Classification
grep -v "^#\|^Hugo_Symbol" ${INPUT_MAF} | awk -F'\t' '
BEGIN {OFS="\t"}
{
    # Calculate tumor VAF and depth
    t_alt = $81
    t_ref = $82
    n_alt = $83
    t_depth = t_alt + t_ref
    
    if (t_depth > 0) {
        tumor_vaf = t_alt / t_depth
    } else {
        tumor_vaf = 0
    }
    
    # Filter criteria
    if (n_alt == 0 &&                              # Somatic (not in normal)
        tumor_vaf >= 0.05 &&                       # Tumor VAF >= 5%
        t_depth >= 20 &&                           # Tumor depth >= 20
        ($9 == "Missense_Mutation" ||             # Coding variants only
         $9 == "Nonsense_Mutation" ||
         $9 == "Frame_Shift_Ins" ||
         $9 == "Frame_Shift_Del" ||
         $9 == "Splice_Site" ||
         $9 == "In_Frame_Ins" ||
         $9 == "In_Frame_Del")) {
        print $0
    }
}' >> ${OUTPUT_MAF}

# Summary
ORIGINAL=$(grep -v "^#\|^Hugo_Symbol" ${INPUT_MAF} | wc -l)
FILTERED=$(grep -v "^Hugo_Symbol" ${OUTPUT_MAF} | wc -l)

echo "Results:"
echo "  Original variants: ${ORIGINAL}"
echo "  After filtering: ${FILTERED}"
echo "  Reduction: $((ORIGINAL - FILTERED)) variants removed"
echo ""
echo "Filtered MAF saved to: ${OUTPUT_MAF}"
echo ""

# Show top mutated genes
echo "Top 20 mutated genes after filtering:"
grep -v "^Hugo_Symbol" ${OUTPUT_MAF} | cut -f1 | sort | uniq -c | sort -rn | head -20

# Show variant types
echo ""
echo "Variant type breakdown:"
grep -v "^Hugo_Symbol" ${OUTPUT_MAF} | cut -f9 | sort | uniq -c | sort -rn

# Extract key thyroid genes
echo ""
echo "Key thyroid cancer gene mutations:"
for gene in BRAF NRAS HRAS KRAS RET TP53 PTEN PIK3CA; do
    COUNT=$(grep "^${gene}" ${OUTPUT_MAF} | wc -l)
    if [ ${COUNT} -gt 0 ]; then
        echo "  ${gene}: ${COUNT} mutations"
        grep "^${gene}" ${OUTPUT_MAF} | cut -f1,9,42 | sed 's/^/    /'
    fi
done