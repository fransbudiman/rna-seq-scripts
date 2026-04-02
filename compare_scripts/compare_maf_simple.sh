#!/bin/bash
# compare_maf_simple.sh - Compare MAF files without pandas

PAIR="pair_01"
DIR1="/home/frans/scratch/rna-seq/results/funcotator_pass_only"
DIR2="/project/rrg-bourqueg-ad/C3G/share/Lerner-Ellis_Sinai/RNA-seq/FINAL_MUTECT2_ANALYSIS/results/funcotator_pass_only"

echo "=== Comparing ${PAIR}_pass_only.maf ==="
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

# Show examples of unique variants
echo ""
echo "=== Variants unique to RUN 1 ==="
comm -23 /tmp/maf1_pos.txt /tmp/maf2_pos.txt

echo ""
echo "=== Variants unique to RUN 2 ==="
comm -13 /tmp/maf1_pos.txt /tmp/maf2_pos.txt
# Cleanup
rm -f /tmp/maf1_pos.txt /tmp/maf2_pos.txt

echo ""
echo "DONE"
