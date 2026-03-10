#!/bin/bash
# Extract all thyroid-relevant mutations

WORK_DIR="/scratch/frans/rna-seq"
OUTPUT_DIR="${WORK_DIR}/thyroid_marker_analysis"
mkdir -p ${OUTPUT_DIR}

# All genes from your classification
GENES="BRAF NRAS HRAS KRAS RET TP53 PIK3CA AKT1 PTEN DICER1 CTNNB1 APC TSHR EZH1 GNAS EIF1AX ALK NTRK1 NTRK2 NTRK3 MET FGFR1 FGFR2 FGFR3 ROS1 THADA IGF2BP3 PAX8 PPARG"

echo "Extracting all thyroid-relevant mutations..."

for gene in ${GENES}; do
    OUTPUT="${OUTPUT_DIR}/${gene}_all_mutations.txt"
    
    echo -e "Sample\tGene\tChromosome\tPosition\tVariant_Classification\tProtein_Change\tFilter" > ${OUTPUT}
    
    for maf in ${WORK_DIR}/results/funcotator_pass_only/*_pass_only.maf; do
        SAMPLE=$(basename ${maf} _pass_only.maf)
        
        grep "^${gene}[[:space:]]" ${maf} | \
            awk -F'\t' -v sample="${SAMPLE}" '{print sample"\t"$1"\t"$5"\t"$6"\t"$9"\t"$42"\tPASS"}' >> ${OUTPUT}
    done
    
    # Count
    COUNT=$(($(wc -l < ${OUTPUT}) - 1))
    if [ ${COUNT} -gt 0 ]; then
        SAMPLES=$(tail -n +2 ${OUTPUT} | cut -f1 | sort -u | wc -l)
        echo "${gene}: ${COUNT} mutations in ${SAMPLES} samples"
    else
        rm ${OUTPUT}
    fi
done

echo ""
echo "Results saved to: ${OUTPUT_DIR}/"