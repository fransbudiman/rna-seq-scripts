#!/bin/bash
# Extract thyroid cancer-specific mutations

WORK_DIR="/scratch/frans/rna-seq"
OUTPUT="${WORK_DIR}/thyroid_specific_mutations.txt"

# Key thyroid cancer genes
THYROID_GENES="BRAF NRAS HRAS KRAS RET TERT TP53 PTEN PIK3CA AKT1 GNAS TSHR"

echo "Sample,Gene,Chromosome,Position,Variant_Classification,Protein_Change,Variant_Type" > ${OUTPUT}

for gene in ${THYROID_GENES}; do
    if [ -f "${WORK_DIR}/cancer_gene_mutations/${gene}_mutations.txt" ]; then
        tail -n +2 "${WORK_DIR}/cancer_gene_mutations/${gene}_mutations.txt" >> ${OUTPUT}
    fi
done

# Focus on BRAF V600E specifically
echo ""
echo "BRAF V600E mutations (key thyroid cancer marker):"
grep "BRAF" ${OUTPUT} | grep "p.V600E"

# RAS mutations at hotspots (Q61, G12, G13)
echo ""
echo "RAS hotspot mutations:"
grep "NRAS\|HRAS\|KRAS" ${OUTPUT} | grep -E "p.Q61|p.G12|p.G13"