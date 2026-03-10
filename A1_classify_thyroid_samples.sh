#!/bin/bash
# Classify samples based on mutation profile

WORK_DIR="/scratch/rad123/FINAL_MUTECT2_ANALYSIS"
OUTPUT="${WORK_DIR}/thyroid_molecular_classification.csv"
CANCER_DIR="${WORK_DIR}/cancer_gene_mutations"

echo "Sample_ID,Category,BRAF_V600E,BRAF_other,NRAS,HRAS,KRAS,RET,TP53,PIK3CA,AKT1,PTEN,DICER1,CTNNB1,APC,TSHR,GNAS,EIF1AX,EZH1,High_Risk,Notes" > ${OUTPUT}

for i in $(seq -f "%02g" 1 66); do
    SAMPLE="pair_${i}"
    MAF="${WORK_DIR}/results/funcotator_pass_only/${SAMPLE}_pass_only.maf"
    
    # Initialize all markers
    BRAF_V600E=0
    BRAF_OTHER=0
    NRAS=0
    HRAS=0
    KRAS=0
    RET_MUT=0
    TP53_MUT=0
    PIK3CA_MUT=0
    AKT1_E17K=0
    PTEN_MUT=0
    DICER1_MUT=0
    CTNNB1_MUT=0
    APC_MUT=0
    TSHR_MUT=0
    GNAS_MUT=0
    EIF1AX_MUT=0
    EZH1_MUT=0
    
    # Check BRAF V600E (tumor fraction > 5%)
    if awk -F'\t' 'BEGIN{IGNORECASE=1} NR==1{for(i=1;i<=NF;i++)h[$i]=i; pcol=(h["HGVSp_Short"]?h["HGVSp_Short"]:h["Protein_Change"]); next} h["Hugo_Symbol"] && h["tumor_f"] && $h["Hugo_Symbol"]=="BRAF" && pcol && $pcol=="p.V600E" && $h["tumor_f"]>0.05 {exit 0} END{exit 1}' "$MAF" 2>/dev/null; then
        BRAF_V600E=1
    fi
    
    # Check BRAF non-V600E (tumor fraction > 5%)
    if awk -F'\t' 'BEGIN{IGNORECASE=1} NR==1{for(i=1;i<=NF;i++)h[$i]=i; pcol=(h["HGVSp_Short"]?h["HGVSp_Short"]:h["Protein_Change"]); next} h["Hugo_Symbol"] && h["Variant_Classification"] && h["tumor_f"] && $h["Hugo_Symbol"]=="BRAF" && (!pcol || ($pcol!="p.V600E")) && ($h["Variant_Classification"] ~ /Missense|Nonsense|Frame_Shift/) && $h["tumor_f"]>0.05 {found=1} END{exit found?0:1}' "$MAF" 2>/dev/null; then
        BRAF_OTHER=1
    fi
    
    # Check RAS genes (tumor fraction > 5%)
    if awk -F'\t' 'BEGIN{IGNORECASE=1} NR==1{for(i=1;i<=NF;i++)h[$i]=i; next} h["Hugo_Symbol"] && h["Variant_Classification"] && h["tumor_f"] && $h["Hugo_Symbol"]=="NRAS" && ($h["Variant_Classification"] ~ /Missense|Nonsense|Frame_Shift/) && $h["tumor_f"]>0.05 {exit 0} END{exit 1}' "$MAF" 2>/dev/null; then NRAS=1; fi
    if awk -F'\t' 'BEGIN{IGNORECASE=1} NR==1{for(i=1;i<=NF;i++)h[$i]=i; next} h["Hugo_Symbol"] && h["Variant_Classification"] && h["tumor_f"] && $h["Hugo_Symbol"]=="HRAS" && ($h["Variant_Classification"] ~ /Missense|Nonsense|Frame_Shift/) && $h["tumor_f"]>0.05 {exit 0} END{exit 1}' "$MAF" 2>/dev/null; then HRAS=1; fi
    if awk -F'\t' 'BEGIN{IGNORECASE=1} NR==1{for(i=1;i<=NF;i++)h[$i]=i; next} h["Hugo_Symbol"] && h["Variant_Classification"] && h["tumor_f"] && $h["Hugo_Symbol"]=="KRAS" && ($h["Variant_Classification"] ~ /Missense|Nonsense|Frame_Shift/) && $h["tumor_f"]>0.05 {exit 0} END{exit 1}' "$MAF" 2>/dev/null; then KRAS=1; fi
    
    # Check high-risk mutations (tumor fraction > 5%)
    if awk -F'\t' 'BEGIN{IGNORECASE=1} NR==1{for(i=1;i<=NF;i++)h[$i]=i; next} h["Hugo_Symbol"] && h["tumor_f"] && $h["Hugo_Symbol"]=="RET" && $h["tumor_f"]>0.05 {exit 0} END{exit 1}' "$MAF" 2>/dev/null; then RET_MUT=1; fi
    if awk -F'\t' 'BEGIN{IGNORECASE=1} NR==1{for(i=1;i<=NF;i++)h[$i]=i; next} h["Hugo_Symbol"] && h["tumor_f"] && $h["Hugo_Symbol"]=="TP53" && $h["tumor_f"]>0.05 {exit 0} END{exit 1}' "$MAF" 2>/dev/null; then TP53_MUT=1; fi
    if awk -F'\t' 'BEGIN{IGNORECASE=1} NR==1{for(i=1;i<=NF;i++)h[$i]=i; next} h["Hugo_Symbol"] && h["tumor_f"] && $h["Hugo_Symbol"]=="PIK3CA" && $h["tumor_f"]>0.05 {exit 0} END{exit 1}' "$MAF" 2>/dev/null; then PIK3CA_MUT=1; fi
    
    # Check AKT1 E17K specifically (tumor fraction > 5%)
    if awk -F'\t' 'BEGIN{IGNORECASE=1} NR==1{for(i=1;i<=NF;i++)h[$i]=i; pcol=(h["HGVSp_Short"]?h["HGVSp_Short"]:h["Protein_Change"]); next} h["Hugo_Symbol"] && pcol && h["tumor_f"] && $h["Hugo_Symbol"]=="AKT1" && $pcol=="p.E17K" && $h["tumor_f"]>0.05 {exit 0} END{exit 1}' "$MAF" 2>/dev/null; then
        AKT1_E17K=1
    fi
    
    # PTEN (tumor fraction > 5%)
    if awk -F'\t' 'BEGIN{IGNORECASE=1} NR==1{for(i=1;i<=NF;i++)h[$i]=i; next} h["Hugo_Symbol"] && h["tumor_f"] && $h["Hugo_Symbol"]=="PTEN" && $h["tumor_f"]>0.05 {exit 0} END{exit 1}' "$MAF" 2>/dev/null; then PTEN_MUT=1; fi
    
    # Check other markers (tumor fraction > 5%)
    if awk -F'\t' 'BEGIN{IGNORECASE=1} NR==1{for(i=1;i<=NF;i++)h[$i]=i; next} h["Hugo_Symbol"] && h["Variant_Classification"] && h["tumor_f"] && $h["Hugo_Symbol"]=="DICER1" && ($h["Variant_Classification"] ~ /Missense|Nonsense|Frame_Shift/) && $h["tumor_f"]>0.05 {exit 0} END{exit 1}' "$MAF" 2>/dev/null; then
        DICER1_MUT=1
    fi
    
    if awk -F'\t' 'BEGIN{IGNORECASE=1} NR==1{for(i=1;i<=NF;i++)h[$i]=i; next} h["Hugo_Symbol"] && h["tumor_f"] && $h["Hugo_Symbol"]=="CTNNB1" && $h["tumor_f"]>0.05 {exit 0} END{exit 1}' "$MAF" 2>/dev/null; then CTNNB1_MUT=1; fi
    if awk -F'\t' 'BEGIN{IGNORECASE=1} NR==1{for(i=1;i<=NF;i++)h[$i]=i; next} h["Hugo_Symbol"] && h["tumor_f"] && $h["Hugo_Symbol"]=="APC" && $h["tumor_f"]>0.05 {exit 0} END{exit 1}' "$MAF" 2>/dev/null; then APC_MUT=1; fi
    
    # Check benign markers (tumor fraction > 5%)
    for gene in TSHR GNAS EIF1AX EZH1; do
        if awk -F'\t' -v g="$gene" 'BEGIN{IGNORECASE=1} NR==1{for(i=1;i<=NF;i++)h[$i]=i; next} h["Hugo_Symbol"] && h["Variant_Classification"] && h["tumor_f"] && $h["Hugo_Symbol"]==g && ($h["Variant_Classification"] ~ /Missense|Nonsense|Frame_Shift/) && $h["tumor_f"]>0.05 {exit 0} END{exit 1}' "$MAF" 2>/dev/null; then
            case $gene in
                TSHR) TSHR_MUT=1 ;;
                GNAS) GNAS_MUT=1 ;;
                EIF1AX) EIF1AX_MUT=1 ;;
                EZH1) EZH1_MUT=1 ;;
            esac
        fi
    done
    
    # Determine category
    CATEGORY="Unclassified"
    NOTES=""
    HIGH_RISK=0
    
    if [ $BRAF_V600E -eq 1 ]; then
        CATEGORY="BRAF-V600E-like_(PTC_classic)"
    elif [ $BRAF_OTHER -eq 1 ] || [ $NRAS -eq 1 ] || [ $HRAS -eq 1 ] || [ $KRAS -eq 1 ]; then
        CATEGORY="RAS-like"
        [ $BRAF_OTHER -eq 1 ] && NOTES="${NOTES}BRAF_non-V600E;"
    fi
    
    # Check for high-risk markers
    if [ $TP53_MUT -eq 1 ] || [ $PIK3CA_MUT -eq 1 ] || [ $AKT1_E17K -eq 1 ] || [ $PTEN_MUT -eq 1 ]; then
        HIGH_RISK=1
        NOTES="${NOTES}High-risk_mutations;"
    fi
    
    # Check for benign markers
    if [ $TSHR_MUT -eq 1 ] || [ $GNAS_MUT -eq 1 ] || [ $EZH1_MUT -eq 1 ]; then
        NOTES="${NOTES}Benign_markers;"
    fi
    
    # Check for other types
    if [ $DICER1_MUT -eq 1 ] || [ $CTNNB1_MUT -eq 1 ] || [ $APC_MUT -eq 1 ]; then
        NOTES="${NOTES}Other_type_markers;"
    fi
    
    # Output
    echo "${SAMPLE},${CATEGORY},${BRAF_V600E},${BRAF_OTHER},${NRAS},${HRAS},${KRAS},${RET_MUT},${TP53_MUT},${PIK3CA_MUT},${AKT1_E17K},${PTEN_MUT},${DICER1_MUT},${CTNNB1_MUT},${APC_MUT},${TSHR_MUT},${GNAS_MUT},${EIF1AX_MUT},${EZH1_MUT},${HIGH_RISK},${NOTES}" >> ${OUTPUT}
done

echo "Classification saved to: ${OUTPUT}"
echo ""
echo "Summary:"
echo "========"

# Count by category
echo "BRAF-V600E-like: $(grep ",BRAF-V600E-like" ${OUTPUT} | wc -l) samples"
echo "RAS-like: $(grep ",RAS-like" ${OUTPUT} | wc -l) samples"
echo "Unclassified: $(grep ",Unclassified" ${OUTPUT} | wc -l) samples"
echo ""
echo "High-risk mutations: $(awk -F',' '$20==1' ${OUTPUT} | wc -l) samples"
echo ""

# Display table
cat ${OUTPUT} | column -t -s','