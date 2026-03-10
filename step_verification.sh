#!/bin/bash
# GATK Mutect2 Pipeline - Step 1: Environment Setup and Verification
# For Narval HPC Cluster

echo "=========================================="
echo "GATK Mutect2 Pipeline Setup and Verification"
echo "=========================================="

# Step 1.1: Check available modules
echo "1. Checking available GATK modules..."
module avail gatk

echo -e "\n2. Checking available SAMtools modules..."
module avail samtools

echo -e "\n3. Checking available Picard modules..."
module avail picard

echo -e "\n4. Loading modules to test..."
module load StdEnv/2020 gatk/4.4.0.0
module load samtools/1.18

echo -e "\n5. Testing GATK installation..."
gatk --version

echo -e "\n6. Testing SAMtools installation..."
samtools --version

echo -e "\n7. Checking GATK resource bundle locations..."
echo "Looking for GATK resources in standard locations..."

# Common locations for GATK resources on Compute Canada clusters
RESOURCE_LOCATIONS=(
    "/cvmfs/soft.computecanada.ca/easybuild/software/2020/Core/gatk"
    "/cvmfs/soft.computecanada.ca/easybuild/software/2020/avx2/Core/gatk"
    "/cvmfs/soft.computecanada.ca/easybuild/software/2023/x86-64-v3/Core/gatk"
    "$EBROOTGATK"
)

for location in "${RESOURCE_LOCATIONS[@]}"; do
    if [ -d "$location" ]; then
        echo "Found GATK installation at: $location"
        find "$location" -name "*.fasta" -o -name "*.vcf.gz" -o -name "*interval*" | head -10
    fi
done

echo -e "\n8. Checking your BAM files structure..."
BAM_DIR="/scratch/rad123/my_RNA-seq/complete_RNA/results/STAR"
if [ -d "$BAM_DIR" ]; then
    echo "BAM directory found: $BAM_DIR"
    echo "Number of BAM files: $(find $BAM_DIR -name "*.bam" | wc -l)"
    echo "Sample BAM files:"
    ls -la $BAM_DIR/*.bam | head -5
    
    # Check if BAM files are indexed
    echo -e "\nChecking BAM index files (.bai)..."
    BAI_COUNT=$(find $BAM_DIR -name "*.bai" | wc -l)
    BAM_COUNT=$(find $BAM_DIR -name "*.bam" | wc -l)
    echo "BAM files: $BAM_COUNT, Index files: $BAI_COUNT"
    
    if [ $BAI_COUNT -lt $BAM_COUNT ]; then
        echo "WARNING: Not all BAM files are indexed!"
    fi
else
    echo "ERROR: BAM directory not found!"
fi

echo -e "\n9. Setting up working directory..."
WORK_DIR="/scratch/rad123/FINAL_MUTECT2_ANALYSIS"
mkdir -p $WORK_DIR/{logs,temp,scripts,resources,results/{mutect2,filtering,metrics,pon}}
echo "Working directory created: $WORK_DIR"

echo -e "\n10. Directory structure:"
tree $WORK_DIR 2>/dev/null || find $WORK_DIR -type d

echo -e "\n=========================================="
echo "Setup verification complete!"
echo "Next: Run this script to check your environment"
echo "=========================================="