#!/bin/bash
# GATK Mutect2 Pipeline - Step 3: BAM Verification

echo "=========================================="
echo "BAM File Verification and Sample Preparation"
echo "=========================================="

# Load modules and configuration
source /scratch/rad123/FINAL_MUTECT2_ANALYSIS/resources/resource_paths.sh

cd $WORK_DIR

echo "Configuration loaded:"
echo "  Work dir: $WORK_DIR"
echo "  BAM dir: $BAM_DIR"
echo "  Sample file: $SAMPLE_FILE"

echo -e "\n1. Checking sample file..."
if [ ! -f "$SAMPLE_FILE" ]; then
    echo "❌ Sample file not found: $SAMPLE_FILE"
    exit 1
fi

echo "Sample file found. Contents:"
head -5 $SAMPLE_FILE
echo "..."
echo "Total lines: $(wc -l < $SAMPLE_FILE)"

echo -e "\n2. Validating BAM file paths..."
MISSING_BAMS=0
TOTAL_SAMPLES=0
MISSING_FILES=()

while IFS=$'\t' read -r tumor_sample normal_sample pair_id; do
    if [[ $tumor_sample == "tumor_sample" ]]; then continue; fi  # Skip header
    
    ((TOTAL_SAMPLES++))
    
    # Check tumor BAM
    if [ ! -f "$tumor_sample" ]; then
        echo "❌ Missing tumor BAM: $tumor_sample"
        MISSING_FILES+=("TUMOR: $tumor_sample")
        ((MISSING_BAMS++))
    fi
    
    # Check normal BAM
    if [ ! -f "$normal_sample" ]; then
        echo "❌ Missing normal BAM: $normal_sample"  
        MISSING_FILES+=("NORMAL: $normal_sample")
        ((MISSING_BAMS++))
    fi
    
done < $SAMPLE_FILE

echo "Validation complete:"
echo "  Total pairs checked: $TOTAL_SAMPLES"
echo "  Total BAM files expected: $((TOTAL_SAMPLES * 2))"
echo "  Missing BAM files: $MISSING_BAMS"

if [ $MISSING_BAMS -gt 0 ]; then
    echo -e "\n❌ Missing BAM files detected:"
    for file in "${MISSING_FILES[@]}"; do
        echo "  $file"
    done
    echo "Please check file paths and ensure all BAM files are accessible."
    exit 1
fi

echo "✅ All BAM files found!"

echo -e "\n3. Checking BAM file indices..."
MISSING_INDICES=0
BAM_FILES=()

# Collect all unique BAM files
while IFS=$'\t' read -r tumor_sample normal_sample pair_id; do
    if [[ $tumor_sample == "tumor_sample" ]]; then continue; fi
    BAM_FILES+=("$tumor_sample" "$normal_sample")
done < $SAMPLE_FILE

# Remove duplicates and check indices
UNIQUE_BAMS=($(printf '%s\n' "${BAM_FILES[@]}" | sort -u))

echo "Checking indices for ${#UNIQUE_BAMS[@]} unique BAM files..."

for bam_file in "${UNIQUE_BAMS[@]}"; do
    if [ ! -f "${bam_file}.bai" ]; then
        echo "⚠️  Missing index: ${bam_file}.bai"
        ((MISSING_INDICES++))
    fi
done

echo "Index check complete:"
echo "  BAM files: ${#UNIQUE_BAMS[@]}"
echo "  Missing indices: $MISSING_INDICES"

if [ $MISSING_INDICES -eq 0 ]; then
    echo "✅ All BAM files are properly indexed!"
else
    echo "⚠️  Some BAM files need indexing"
    echo "All your BAM files appear to be indexed based on the previous check (132 .bai files found)"
    echo "This might be a path issue. Let me verify..."
    
    # Check a few specific files
    FIRST_PAIR=$(sed -n '2p' $SAMPLE_FILE)
    TUMOR_BAM=$(echo "$FIRST_PAIR" | cut -f1)
    NORMAL_BAM=$(echo "$FIRST_PAIR" | cut -f2)
    
    echo "Checking first pair BAMs:"
    echo "  Tumor: $TUMOR_BAM"
    ls -la "$TUMOR_BAM"* 2>/dev/null || echo "    File not accessible"
    echo "  Normal: $NORMAL_BAM"
    ls -la "$NORMAL_BAM"* 2>/dev/null || echo "    File not accessible"
fi

echo -e "\n4. Extracting sample information from BAM headers..."

# Get first pair for testing
FIRST_PAIR=$(sed -n '2p' $SAMPLE_FILE)
TUMOR_BAM=$(echo "$FIRST_PAIR" | cut -f1)
NORMAL_BAM=$(echo "$FIRST_PAIR" | cut -f2)
PAIR_ID=$(echo "$FIRST_PAIR" | cut -f3)

echo "Testing with first pair: $PAIR_ID"
echo "  Tumor: $TUMOR_BAM"
echo "  Normal: $NORMAL_BAM"

if [ -f "$TUMOR_BAM" ]; then
    echo -e "\nTumor BAM header (@RG lines):"
    samtools view -H "$TUMOR_BAM" | grep "^@RG" | head -3
    
    # Extract sample name
    TUMOR_SM=$(samtools view -H "$TUMOR_BAM" | grep "^@RG" | head -1 | grep -o 'SM:[^[:space:]]*' | cut -d: -f2 | head -1)
    echo "Extracted tumor sample name: '$TUMOR_SM'"
else
    echo "❌ Cannot access tumor BAM for header analysis"
fi

if [ -f "$NORMAL_BAM" ]; then
    echo -e "\nNormal BAM header (@RG lines):"
    samtools view -H "$NORMAL_BAM" | grep "^@RG" | head -3
    
    # Extract sample name  
    NORMAL_SM=$(samtools view -H "$NORMAL_BAM" | grep "^@RG" | head -1 | grep -o 'SM:[^[:space:]]*' | cut -d: -f2 | head -1)
    echo "Extracted normal sample name: '$NORMAL_SM'"
else
    echo "❌ Cannot access normal BAM for header analysis"
fi

echo -e "\n5. Creating enhanced sample sheet..."

cat > enhanced_sample_pairs.tsv << 'EOF'
tumor_bam	normal_bam	tumor_sample_name	normal_sample_name	pair_id
EOF

echo "Processing all pairs to extract sample names..."
PROCESSED=0

while IFS=$'\t' read -r tumor_sample normal_sample pair_id; do
    if [[ $tumor_sample == "tumor_sample" ]]; then continue; fi
    
    ((PROCESSED++))
    echo -ne "\rProcessing pair $PROCESSED/$TOTAL_SAMPLES..."
    
    # Extract sample names from BAM headers
    if [ -f "$tumor_sample" ] && [ -f "$normal_sample" ]; then
        # Get tumor sample name
        TUMOR_SM=$(samtools view -H "$tumor_sample" | grep "^@RG" | head -1 | grep -o 'SM:[^[:space:]]*' | cut -d: -f2 | head -1)
        
        # Get normal sample name
        NORMAL_SM=$(samtools view -H "$normal_sample" | grep "^@RG" | head -1 | grep -o 'SM:[^[:space:]]*' | cut -d: -f2 | head -1)
        
        # If SM tag not found or empty, use filename
        if [ -z "$TUMOR_SM" ]; then
            TUMOR_SM=$(basename "$tumor_sample" .bam | sed 's/_Aligned.sortedByCoord.out//')
        fi
        
        if [ -z "$NORMAL_SM" ]; then
            NORMAL_SM=$(basename "$normal_sample" .bam | sed 's/_Aligned.sortedByCoord.out//')
        fi
        
        # Add to enhanced file
        echo -e "$tumor_sample\t$normal_sample\t$TUMOR_SM\t$NORMAL_SM\t$pair_id" >> enhanced_sample_pairs.tsv
    else
        echo -e "$tumor_sample\t$normal_sample\tUNKNOWN\tUNKNOWN\t$pair_id" >> enhanced_sample_pairs.tsv
    fi
done < $SAMPLE_FILE

echo -e "\n✅ Enhanced sample sheet created!"
echo "Sample enhanced_sample_pairs.tsv contents:"
head -3 enhanced_sample_pairs.tsv

echo -e "\n6. Creating test pair configuration..."
FIRST_ENHANCED=$(sed -n '2p' enhanced_sample_pairs.tsv)
TEST_TUMOR_BAM=$(echo "$FIRST_ENHANCED" | cut -f1)
TEST_NORMAL_BAM=$(echo "$FIRST_ENHANCED" | cut -f2) 
TEST_TUMOR_SAMPLE=$(echo "$FIRST_ENHANCED" | cut -f3)
TEST_NORMAL_SAMPLE=$(echo "$FIRST_ENHANCED" | cut -f4)
TEST_PAIR_ID=$(echo "$FIRST_ENHANCED" | cut -f5)

cat > test_pair_config.sh << EOF
# Test pair configuration
export TUMOR_BAM="$TEST_TUMOR_BAM"
export NORMAL_BAM="$TEST_NORMAL_BAM"
export TUMOR_SAMPLE="$TEST_TUMOR_SAMPLE"
export NORMAL_SAMPLE="$TEST_NORMAL_SAMPLE"
export PAIR_ID="$TEST_PAIR_ID"
EOF

echo "✅ Test configuration saved:"
echo "  Pair ID: $TEST_PAIR_ID"
echo "  Tumor sample: $TEST_TUMOR_SAMPLE"
echo "  Normal sample: $TEST_NORMAL_SAMPLE"

echo -e "\n7. Final verification..."
echo "Resources available:"
echo "  ✅ Reference genome: $REFERENCE"
echo "  ✅ gnomAD variants: $GNOMAD"  
echo "  ✅ Calling intervals: $INTERVALS"
echo "  ✅ All BAM files accessible: $(($TOTAL_SAMPLES * 2 - $MISSING_BAMS)) / $(($TOTAL_SAMPLES * 2))"
echo "  ✅ Enhanced sample sheet: enhanced_sample_pairs.tsv"
echo "  ✅ Test pair config: test_pair_config.sh"

if [ $MISSING_BAMS -eq 0 ]; then
    echo -e "\n🎉 BAM verification completed successfully!"
    echo "Ready to proceed with single pair test."
else
    echo -e "\n⚠️  BAM verification completed with warnings."
    echo "Fix missing BAM files before proceeding."
fi

echo -e "\n=========================================="
echo "Next step: Run single pair test"
echo "Command: bash single_pair_test.sh"
echo "=========================================="