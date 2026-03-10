#!/bin/bash
# Update resource configuration with actual files found

cd /scratch/rad123/FINAL_MUTECT2_ANALYSIS/resources

cat > resource_paths.sh << 'EOF'
#!/bin/bash
# GATK Resource Paths - Final Configuration

# Module loading
module load StdEnv/2023
module load gatk
module load samtools

# Reference genome (using existing CVMFS file)
export REFERENCE="/cvmfs/ref.mugqic/genomes/species/Homo_sapiens.GRCh38/genome/Homo_sapiens.GRCh38.fa"

# Population variants (already downloaded)
export GNOMAD="/scratch/rad123/FINAL_MUTECT2_ANALYSIS/resources/af-only-gnomad.hg38.vcf.gz"

# Calling intervals (already downloaded)
export INTERVALS="/scratch/rad123/FINAL_MUTECT2_ANALYSIS/resources/wgs_calling_regions.hg38.interval_list"

# Working directory
export WORK_DIR="/scratch/rad123/FINAL_MUTECT2_ANALYSIS"

# BAM files directory
export BAM_DIR="/scratch/rad123/my_RNA-seq/complete_RNA/results/STAR"

# Sample pairs file
export SAMPLE_FILE="/scratch/rad123/FINAL_MUTECT2_ANALYSIS/tumor-normal_samples.tsv"
EOF

echo "✅ Resource configuration updated!"
echo "All required resources are available:"
echo "  - Reference: /cvmfs/ref.mugqic/genomes/species/Homo_sapiens.GRCh38/genome/Homo_sapiens.GRCh38.fa"
echo "  - gnomAD: /scratch/rad123/FINAL_MUTECT2_ANALYSIS/resources/af-only-gnomad.hg38.vcf.gz"
echo "  - Intervals: /scratch/rad123/FINAL_MUTECT2_ANALYSIS/resources/wgs_calling_regions.hg38.interval_list"