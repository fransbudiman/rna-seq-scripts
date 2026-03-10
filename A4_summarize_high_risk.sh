#!/bin/bash
# Summarize high-risk mutations

WORK_DIR="/scratch/frans/rna-seq"
OUTPUT="${WORK_DIR}/high_risk_mutation_summary.txt"

echo "High-Risk Thyroid Cancer Mutations" > ${OUTPUT}
echo "===================================" >> ${OUTPUT}
echo "" >> ${OUTPUT}

# TP53
echo "TP53 Mutations:" >> ${OUTPUT}
for maf in ${WORK_DIR}/results/funcotator_pass_only/*_pass_only.maf; do
    SAMPLE=$(basename ${maf} _pass_only.maf)
    TP53=$(grep "^TP53" ${maf} | grep "Missense\|Nonsense\|Frame_Shift" | wc -l)
    [ ${TP53} -gt 0 ] && echo "  ${SAMPLE}: ${TP53} TP53 mutations" >> ${OUTPUT}
done
echo "" >> ${OUTPUT}

# PIK3CA
echo "PIK3CA Mutations:" >> ${OUTPUT}
for maf in ${WORK_DIR}/results/funcotator_pass_only/*_pass_only.maf; do
    SAMPLE=$(basename ${maf} _pass_only.maf)
    PIK3CA=$(grep "^PIK3CA" ${maf} | grep "Missense\|Nonsense\|Frame_Shift" | wc -l)
    [ ${PIK3CA} -gt 0 ] && echo "  ${SAMPLE}: ${PIK3CA} PIK3CA mutations" >> ${OUTPUT}
done
echo "" >> ${OUTPUT}

# AKT1 E17K
echo "AKT1 E17K Mutations:" >> ${OUTPUT}
for maf in ${WORK_DIR}/results/funcotator_pass_only/*_pass_only.maf; do
    SAMPLE=$(basename ${maf} _pass_only.maf)
    if grep "^AKT1" ${maf} | grep -q "p.E17K"; then
        echo "  ${SAMPLE}: AKT1 E17K present" >> ${OUTPUT}
    fi
done
echo "" >> ${OUTPUT}

# PTEN
echo "PTEN Mutations:" >> ${OUTPUT}
for maf in ${WORK_DIR}/results/funcotator_pass_only/*_pass_only.maf; do
    SAMPLE=$(basename ${maf} _pass_only.maf)
    PTEN=$(grep "^PTEN" ${maf} | grep "Missense\|Nonsense\|Frame_Shift" | wc -l)
    [ ${PTEN} -gt 0 ] && echo "  ${SAMPLE}: ${PTEN} PTEN mutations" >> ${OUTPUT}
done

cat ${OUTPUT}