#!/bin/bash
# compare_maf_simple.sh - Compare MAF files without pandas

PAIR="pair_01"
DIR1="/home/frans/scratch/rna-seq/results/funcotator_pass_only"
DIR2="/project/rrg-bourqueg-ad/C3G/share/Lerner-Ellis_Sinai/RNA-seq/FINAL_MUTECT2_ANALYSIS/results/funcotator_pass_only"

# Get column indices from header
get_column_index() {
    local file=$1
    local colname=$2
    grep "^Hugo_Symbol" "$file" | head -1 | awk -v col="$colname" 'BEGIN{FS="\t"} {
        for(i=1; i<=NF; i++) {
            if($i == col) {print i; exit}
        }
    }'
}

# Get indices for RUN 1
GENE_COL=$(get_column_index "$DIR1/${PAIR}_pass_only.maf" "Hugo_Symbol")
CHR_COL=$(get_column_index "$DIR1/${PAIR}_pass_only.maf" "Chromosome")
POS_COL=$(get_column_index "$DIR1/${PAIR}_pass_only.maf" "Start_Position")
ALT_COL=$(get_column_index "$DIR1/${PAIR}_pass_only.maf" "t_alt_count")
REF_COL=$(get_column_index "$DIR1/${PAIR}_pass_only.maf" "t_ref_count")
NALT_COL=$(get_column_index "$DIR1/${PAIR}_pass_only.maf" "n_alt_count")

echo "=== Comparing ${PAIR}_pass_only.maf ==="
echo "Column indices: Gene=$GENE_COL, Chr=$CHR_COL, Pos=$POS_COL, t_alt=$ALT_COL, t_ref=$REF_COL, n_alt=$NALT_COL"
echo ""

# Count total variants
COUNT1=$(grep -v "^#\|^Hugo_Symbol" $DIR1/${PAIR}_pass_only.maf | wc -l)
COUNT2=$(grep -v "^#\|^Hugo_Symbol" $DIR2/${PAIR}_pass_only.maf | wc -l)

echo "RUN 1: $COUNT1 variants"
echo "RUN 2: $COUNT2 variants"
echo "Difference: $((COUNT1 - COUNT2)) variants"
echo ""

# Extract variant positions (Chromosome:Start_Position)
grep -v "^#\|^Hugo_Symbol" $DIR1/${PAIR}_pass_only.maf | cut -f5,6 | awk '{print $1":"$2}' | sort > /tmp/maf1_pos.txt
grep -v "^#\|^Hugo_Symbol" $DIR2/${PAIR}_pass_only.maf | cut -f5,6 | awk '{print $1":"$2}' | sort > /tmp/maf2_pos.txt

# Find unique
UNIQUE1=$(comm -23 /tmp/maf1_pos.txt /tmp/maf2_pos.txt | wc -l)
UNIQUE2=$(comm -13 /tmp/maf1_pos.txt /tmp/maf2_pos.txt | wc -l)
SHARED=$(comm -12 /tmp/maf1_pos.txt /tmp/maf2_pos.txt | wc -l)

echo "Shared variants: $SHARED"
echo "Unique to RUN 1: $UNIQUE1"
echo "Unique to RUN 2: $UNIQUE2"

# Calculate concordance
if [ $COUNT1 -gt 0 ]; then
    CONCORDANCE=$(echo "scale=2; $SHARED*100/$COUNT1" | bc)
    echo "Concordance: ${CONCORDANCE}%"
fi

echo ""
echo "=== Checking Major Cancer Genes ==="
for gene in TP53 KRAS BRAF EGFR PIK3CA PTEN; do
    count1=$(grep "^$gene" $DIR1/${PAIR}_pass_only.maf 2>/dev/null | wc -l)
    count2=$(grep "^$gene" $DIR2/${PAIR}_pass_only.maf 2>/dev/null | wc -l)
    if [ $count1 -gt 0 ] || [ $count2 -gt 0 ]; then
        echo "$gene: RUN 1=$count1, RUN 2=$count2"
    fi
done

# Show examples of unique variants WITH quality metrics
echo ""
echo "=== Variants unique to RUN 1 (with quality metrics) ==="
echo "Gene | Chr:Pos | t_depth | t_ref | t_alt | VAF% | n_alt"
echo "--------------------------------------------------------"
comm -23 /tmp/maf1_pos.txt /tmp/maf2_pos.txt | while read pos; do
    chr=$(echo $pos | cut -d: -f1)
    start=$(echo $pos | cut -d: -f2)
    grep -v "^#\|^Hugo_Symbol" $DIR1/${PAIR}_pass_only.maf | \
        awk -v chr="$chr" -v pos="$start" \
            -v gene_col="$GENE_COL" -v chr_col="$CHR_COL" -v pos_col="$POS_COL" \
            -v alt_col="$ALT_COL" -v ref_col="$REF_COL" -v nalt_col="$NALT_COL" \
            'BEGIN{FS="\t"; OFS="\t"} 
        $chr_col==chr && $pos_col==pos {
            alt = ($alt_col != "" && $alt_col != "-") ? $alt_col : 0
            ref = ($ref_col != "" && $ref_col != "-") ? $ref_col : 0
            depth = alt + ref
            n_alt = ($nalt_col != "" && $nalt_col != "-") ? $nalt_col : 0
            vaf = (alt > 0 && depth > 0) ? sprintf("%.1f", (alt/depth)*100) : "0.0"
            printf "%s | %s:%s | %s | %s | %s | %s | %s\n", 
                $gene_col, $chr_col, $pos_col, depth, ref, alt, vaf, n_alt
        }'
done

echo ""
echo "=== Variants unique to RUN 2 (with quality metrics) ==="
echo "Gene | Chr:Pos | t_depth | t_ref | t_alt | VAF% | n_alt"
echo "--------------------------------------------------------"
comm -13 /tmp/maf1_pos.txt /tmp/maf2_pos.txt | while read pos; do
    chr=$(echo $pos | cut -d: -f1)
    start=$(echo $pos | cut -d: -f2)
    grep -v "^#\|^Hugo_Symbol" $DIR2/${PAIR}_pass_only.maf | \
        awk -v chr="$chr" -v pos="$start" \
            -v gene_col="$GENE_COL" -v chr_col="$CHR_COL" -v pos_col="$POS_COL" \
            -v alt_col="$ALT_COL" -v ref_col="$REF_COL" -v nalt_col="$NALT_COL" \
            'BEGIN{FS="\t"; OFS="\t"} 
        $chr_col==chr && $pos_col==pos {
            alt = ($alt_col != "" && $alt_col != "-") ? $alt_col : 0
            ref = ($ref_col != "" && $ref_col != "-") ? $ref_col : 0
            depth = alt + ref
            n_alt = ($nalt_col != "" && $nalt_col != "-") ? $nalt_col : 0
            vaf = (alt > 0 && depth > 0) ? sprintf("%.1f", (alt/depth)*100) : "0.0"
            printf "%s | %s:%s | %s | %s | %s | %s | %s\n", 
                $gene_col, $chr_col, $pos_col, depth, ref, alt, vaf, n_alt
        }'
done

echo ""
echo "=========================================================================="
echo "=== POTENTIAL PROBLEMATIC VARIANTS (High VAF >25% AND High Depth >50) ==="
echo "=========================================================================="
echo ""
echo "=== In RUN 1 only ==="
echo "Gene | Chr:Pos | t_depth | t_ref | t_alt | VAF% | n_alt"
echo "--------------------------------------------------------"
comm -23 /tmp/maf1_pos.txt /tmp/maf2_pos.txt | while read pos; do
    chr=$(echo $pos | cut -d: -f1)
    start=$(echo $pos | cut -d: -f2)
    grep -v "^#\|^Hugo_Symbol" $DIR1/${PAIR}_pass_only.maf | \
        awk -v chr="$chr" -v pos="$start" \
            -v gene_col="$GENE_COL" -v chr_col="$CHR_COL" -v pos_col="$POS_COL" \
            -v alt_col="$ALT_COL" -v ref_col="$REF_COL" -v nalt_col="$NALT_COL" \
            'BEGIN{FS="\t"; OFS="\t"} 
        $chr_col==chr && $pos_col==pos {
            alt = ($alt_col != "" && $alt_col != "-") ? $alt_col : 0
            ref = ($ref_col != "" && $ref_col != "-") ? $ref_col : 0
            depth = alt + ref
            n_alt = ($nalt_col != "" && $nalt_col != "-") ? $nalt_col : 0
            vaf = (alt > 0 && depth > 0) ? (alt/depth)*100 : 0
            if (vaf > 25 && depth > 50) {
                vaf_str = sprintf("%.1f", vaf)
                printf "%s | %s:%s | %s | %s | %s | %s | %s\n", 
                    $gene_col, $chr_col, $pos_col, depth, ref, alt, vaf_str, n_alt
            }
        }'
done

echo ""
echo "=== In RUN 2 only ==="
echo "Gene | Chr:Pos | t_depth | t_ref | t_alt | VAF% | n_alt"
echo "--------------------------------------------------------"
comm -13 /tmp/maf1_pos.txt /tmp/maf2_pos.txt | while read pos; do
    chr=$(echo $pos | cut -d: -f1)
    start=$(echo $pos | cut -d: -f2)
    grep -v "^#\|^Hugo_Symbol" $DIR2/${PAIR}_pass_only.maf | \
        awk -v chr="$chr" -v pos="$start" \
            -v gene_col="$GENE_COL" -v chr_col="$CHR_COL" -v pos_col="$POS_COL" \
            -v alt_col="$ALT_COL" -v ref_col="$REF_COL" -v nalt_col="$NALT_COL" \
            'BEGIN{FS="\t"; OFS="\t"} 
        $chr_col==chr && $pos_col==pos {
            alt = ($alt_col != "" && $alt_col != "-") ? $alt_col : 0
            ref = ($ref_col != "" && $ref_col != "-") ? $ref_col : 0
            depth = alt + ref
            n_alt = ($nalt_col != "" && $nalt_col != "-") ? $nalt_col : 0
            vaf = (alt > 0 && depth > 0) ? (alt/depth)*100 : 0
            if (vaf > 25 && depth > 50) {
                vaf_str = sprintf("%.1f", vaf)
                printf "%s | %s:%s | %s | %s | %s | %s | %s\n", 
                    $gene_col, $chr_col, $pos_col, depth, ref, alt, vaf_str, n_alt
            }
        }'
done

echo ""
echo "(No output = No problematic variants found - good news!)"
echo ""

# Cleanup
rm -f /tmp/maf1_pos.txt /tmp/maf2_pos.txt

echo ""
echo "DONE"
