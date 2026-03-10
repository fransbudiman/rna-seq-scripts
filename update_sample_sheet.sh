#!/bin/bash
# Update sample sheet to point to BAM files with read groups

echo "=========================================="
echo "Updating Sample Sheet for RG BAM Files"
echo "=========================================="

WORK_DIR="/scratch/frans/rna-seq"
RG_BAM_DIR="/scratch/frans/rna-seq/bams_with_rg"

cd $WORK_DIR

echo "Creating updated sample sheet with RG BAM paths..."

# Create new sample sheet header
cat > enhanced_sample_pairs_with_rg.tsv << 'EOF'
tumor_bam	normal_bam	tumor_sample_name	normal_sample_name	pair_id
EOF

# Process each line from the original enhanced sample sheet
while IFS=$'\t' read -r tumor_bam normal_bam tumor_name normal_name pair_id; do
    if [[ $tumor_bam == "tumor_bam" ]]; then continue; fi  # Skip header
    
    # Convert original BAM paths to RG BAM paths
    TUMOR_RG_BAM="$RG_BAM_DIR/${tumor_name}_with_rg.bam"
    NORMAL_RG_BAM="$RG_BAM_DIR/${normal_name}_with_rg.bam"
    
    # Add to new sample sheet
    echo -e "$TUMOR_RG_BAM\t$NORMAL_RG_BAM\t$tumor_name\t$normal_name\t$pair_id" >> enhanced_sample_pairs_with_rg.tsv
    
done < enhanced_sample_pairs.tsv

echo "Updated sample sheet created: enhanced_sample_pairs_with_rg.tsv"
echo "Sample contents:"
head -3 enhanced_sample_pairs_with_rg.tsv

# Count pairs
PAIR_COUNT=$(($(wc -l < enhanced_sample_pairs_with_rg.tsv) - 1))
echo "Total pairs in updated sheet: $PAIR_COUNT"

# Update the resource configuration to use the new BAM directory and sample file
cat > resources/resource_paths_with_rg.sh << EOF
#!/bin/bash
# GATK Resource Paths - Using BAMs with Read Groups

# Module loading
module load StdEnv/2023
module load gatk
module load samtools

# Reference genome (using existing CVMFS file)
export REFERENCE="/cvmfs/ref.mugqic/genomes/species/Homo_sapiens.GRCh38/genome/Homo_sapiens.GRCh38.fa"

# Population variants
export GNOMAD="/scratch/frans/rna-seq/resources/af-only-gnomad.hg38.vcf.gz"

# Calling intervals
export INTERVALS="/scratch/frans/rna-seq/resources/wgs_calling_regions.hg38.interval_list"

# Working directory
export WORK_DIR="/scratch/frans/rna-seq"

# BAM files directory (UPDATED to use RG BAMs)
export BAM_DIR="/scratch/frans/rna-seq/bams_with_rg"

# Sample pairs file (UPDATED to use RG BAM paths)
export SAMPLE_FILE="/scratch/frans/rna-seq/enhanced_sample_pairs_with_rg.tsv"
EOF

echo "Updated resource configuration: resources/resource_paths_with_rg.sh"

echo -e "\n=========================================="
echo "Sample sheet update complete!"
echo "Next: Run add read groups job, then use new sample sheet"
echo "=========================================="