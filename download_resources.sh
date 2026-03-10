#!/bin/bash

echo "=========================================="
echo "Downloading GATK Resources"
echo "=========================================="

# Load modules
module load StdEnv/2023
module load gatk
module load samtools

RESOURCE_DIR="/scratch/rad123/FINAL_MUTECT2_ANALYSIS/resources"
mkdir -p $RESOURCE_DIR

echo "Resource directory: $RESOURCE_DIR"

# Download gnomAD variants (essential for Mutect2)
echo -e "\n1. Downloading gnomAD variants..."
wget -v -P $RESOURCE_DIR https://storage.googleapis.com/gcp-public-data--broad-references/hg38/v0/somatic-hg38/af-only-gnomad.hg38.vcf.gz
if [ $? -eq 0 ]; then
    echo "✓ gnomAD VCF downloaded successfully"
    # Download the index
    wget -v -P $RESOURCE_DIR https://storage.googleapis.com/gcp-public-data--broad-references/hg38/v0/somatic-hg38/af-only-gnomad.hg38.vcf.gz.tbi
    if [ $? -eq 0 ]; then
        echo "✓ gnomAD index downloaded successfully"
    else
        echo "❌ Failed to download gnomAD index"
    fi
else
    echo "❌ Failed to download gnomAD VCF"
    exit 1
fi

# Download calling intervals (optional but recommended)
echo -e "\n2. Downloading calling intervals..."
wget -v -P $RESOURCE_DIR https://42basepairs.com/download/s3/gatk-test-data/intervals/wgs_calling_regions.hg38.interval_list 
if [ $? -eq 0 ]; then
    echo "✓ Calling intervals downloaded successfully"
else
    echo "⚠️  Failed to download calling intervals - will proceed without them"
fi

# Also download the reference genome files we need (fai and dict)
echo -e "\n3. Downloading reference genome indices..."
REF_DIR="/cvmfs/ref.mugqic/genomes/species/Homo_sapiens.GRCh38/genome"
REF_BASE="Homo_sapiens.GRCh38.fa"

# Check if we need to download reference indices
if [ ! -f "$REF_DIR/$REF_BASE.fai" ]; then
    echo "Downloading reference index (.fai)..."
    wget -v -P $RESOURCE_DIR https://storage.googleapis.com/gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta.fai
    if [ $? -eq 0 ]; then
        # Rename to match our reference
        mv $RESOURCE_DIR/Homo_sapiens_assembly38.fasta.fai $RESOURCE_DIR/Homo_sapiens.GRCh38.fa.fai
        echo "✓ Reference index downloaded and renamed"
    fi
else
    echo "✓ Reference index already exists"
fi

if [ ! -f "$REF_DIR/$REF_BASE.dict" ]; then
    echo "Downloading reference dictionary (.dict)..."
    wget -v -P $RESOURCE_DIR https://storage.googleapis.com/gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.dict
    if [ $? -eq 0 ]; then
        # Rename to match our reference
        mv $RESOURCE_DIR/Homo_sapiens_assembly38.dict $RESOURCE_DIR/Homo_sapiens.GRCh38.fa.dict
        echo "✓ Reference dictionary downloaded and renamed"
    fi
else
    echo "✓ Reference dictionary already exists"
fi

echo -e "\n4. Updating resource configuration..."
cat > $RESOURCE_DIR/resource_paths.sh << 'EOF'
#!/bin/bash
# GATK Resource Paths - Final Configuration

# Module loading
module load StdEnv/2023
module load gatk
module load samtools

# Reference genome (using existing CVMFS file)
export REFERENCE="/cvmfs/ref.mugqic/genomes/species/Homo_sapiens.GRCh38/genome/Homo_sapiens.GRCh38.fa"

# Population variants (downloaded)
export GNOMAD="/scratch/rad123/FINAL_MUTECT2_ANALYSIS/resources/af-only-gnomad.hg38.vcf.gz"

# Calling intervals (downloaded, or will create our own if download failed)
if [ -f "/scratch/rad123/FINAL_MUTECT2_ANALYSIS/resources/wgs_calling_regions.hg38.interval_list" ]; then
    export INTERVALS="/scratch/rad123/FINAL_MUTECT2_ANALYSIS/resources/wgs_calling_regions.hg38.interval_list"
else
    export INTERVALS=""  # Will create intervals on the fly
fi

# Working directory
export WORK_DIR="/scratch/rad123/FINAL_MUTECT2_ANALYSIS"

# BAM files directory
export BAM_DIR="/scratch/rad123/my_RNA-seq/complete_RNA/results/STAR"

# Sample pairs file
export SAMPLE_FILE="/scratch/rad123/FINAL_MUTECT2_ANALYSIS/tumor-normal_samples.tsv"
EOF

echo "✓ Updated resource_paths.sh"

echo -e "\n5. Verifying downloaded files..."
ls -lh $RESOURCE_DIR/

echo -e "\n6. Testing file integrity..."
if [ -f "$RESOURCE_DIR/af-only-gnomad.hg38.vcf.gz" ]; then
    echo "gnomAD file size: $(du -h $RESOURCE_DIR/af-only-gnomad.hg38.vcf.gz)"
    # Quick test that the file is not corrupted
    zcat $RESOURCE_DIR/af-only-gnomad.hg38.vcf.gz | head -100 > /dev/null
    if [ $? -eq 0 ]; then
        echo "✓ gnomAD file appears to be valid"
    else
        echo "❌ gnomAD file may be corrupted"
    fi
fi

echo -e "\n🎉 Resource download completed!"
echo "Key files:"
echo "  - gnomAD: $RESOURCE_DIR/af-only-gnomad.hg38.vcf.gz"
echo "  - Reference: /cvmfs/ref.mugqic/genomes/species/Homo_sapiens.GRCh38/genome/Homo_sapiens.GRCh38.fa"
echo "  - Config: $RESOURCE_DIR/resource_paths.sh"

echo -e "\n=========================================="
echo "Ready to proceed with BAM verification!"
echo "=========================================="