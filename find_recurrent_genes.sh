#!/bin/bash
# Find genes mutated in multiple samples

WORK_DIR="/scratch/frans/rna-seq"
OUTPUT="${WORK_DIR}/recurrent_mutations.txt"

echo "Analyzing recurrent mutations across 66 samples..."
echo ""

# Extract all PASS coding mutations
cat ${WORK_DIR}/results/funcotator_pass_only/*_pass_only.maf | \
  grep -v "^#\|^Hugo_Symbol\|^Unknown" | \
  grep "Missense_Mutation\|Nonsense_Mutation\|Frame_Shift\|Splice_Site" | \
  cut -f1 | sort | uniq -c | sort -rn > ${OUTPUT}

echo "Top 30 Recurrently Mutated Genes:" | tee -a ${OUTPUT}
echo "===================================" | tee -a ${OUTPUT}
head -30 ${OUTPUT}

echo ""
echo "Full results saved to: ${OUTPUT}"