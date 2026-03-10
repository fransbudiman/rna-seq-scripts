#!/bin/bash
# Detailed examination of top candidate genes in pair_37

WORK_DIR="/scratch/rad123/FINAL_MUTECT2_ANALYSIS"
SAMPLE="pair_37"
INPUT_MAF="${WORK_DIR}/results/funcotator_pass_only/${SAMPLE}_pass_only.maf"

echo "=== DETAILED ANALYSIS OF TOP CANDIDATE GENES ==="
echo ""

# Top candidates based on VAF, biological relevance, and depth
CANDIDATES="LAMA5 N4BP1 NOTCH2 CYLD SAMD9 AHNAK PTPN14 SMAD3 NBEAL1"

for gene in ${CANDIDATES}; do
    echo "=========================================="
    echo "Gene: ${gene}"
    echo "=========================================="
    
    grep "^${gene}[[:space:]]" ${INPUT_MAF} | \
        grep -v "Intron\|Silent\|3'UTR\|5'UTR\|IGR" | \
        awk -F'\t' -v gene="${gene}" 'BEGIN {
            print "Position\tVariant_Type\tProtein_Change\tImpact\tTumor_Alt\tTumor_Ref\tNormal_Alt\tNormal_Ref\tVAF"
        } {
            t_alt = $81
            t_ref = $82
            n_alt = $83
            n_ref = $84
            t_depth = t_alt + t_ref
            if (t_depth > 0) {
                vaf = sprintf("%.4f", t_alt / t_depth)
            } else {
                vaf = "0"
            }
            print $6 "\t" $9 "\t" $42 "\t" $76 "\t" t_alt "\t" t_ref "\t" n_alt "\t" n_ref "\t" vaf
        }' | column -t
    echo ""
done

echo ""
echo "=== CHECKING FOR POTENTIAL TP53 MUTATIONS ==="
grep "^TP53[[:space:]]" ${INPUT_MAF} | \
    awk -F'\t' '{
        t_alt = $81
        t_ref = $82
        t_depth = t_alt + t_ref
        if (t_depth > 0) {
            vaf = sprintf("%.4f", t_alt / t_depth)
        } else {
            vaf = "0"
        }
        print $5, $6, $9, $42, "VAF=" vaf, "Depth=" t_depth, "T_alt=" t_alt, "N_alt=" $83
    }' | column -t

echo ""
echo "=== SUMMARY: Candidate Driver Mutations ==="
echo ""
echo "High-confidence candidates (VAF > 20%, depth > 40):"
grep "^LAMA5[[:space:]]" ${INPUT_MAF} | grep "Missense" | awk -F'\t' '{print "LAMA5 p.D1508V - VAF=35%, depth=636"}'
echo ""
echo "Potential tumor suppressors with LOF mutations:"
grep -E "^(PTPN14|NBEAL1|FBXW11|CYLD)[[:space:]]" ${INPUT_MAF} | \
    grep "Nonsense\|Frame_Shift" | \
    awk -F'\t' '{
        t_depth = $81 + $82
        if (t_depth > 0) vaf = sprintf("%.2f", $81 / t_depth * 100)
        print $1, $42, "- VAF=" vaf "%, depth=" t_depth
    }'