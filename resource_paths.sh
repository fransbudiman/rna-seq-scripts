#!/bin/bash
# GATK Resource Paths - Final Configuration

# Module loading
module load StdEnv/2023
module load gatk
module load samtools

# Reference genome (using existing CVMFS file)
export REFERENCE="/cvmfs/ref.mugqic/genomes/species/Homo_sapiens.GRCh38/genome/Homo_sapiens.GRCh38.fa"

# Population variants (downloaded)
export GNOMAD="/scratch/frans/rna-seq/resources/af-only-gnomad.hg38.vcf.gz"

# Calling intervals (downloaded, or will create our own if download failed)
if [ -f "/scratch/frans/rna-seq/resources/wgs_calling_regions.hg38.interval_list" ]; then
    export INTERVALS="/scratch/frans/rna-seq/resources/wgs_calling_regions.hg38.interval_list"
else
    export INTERVALS=""  # Will create intervals on the fly
fi

# Working directory
export WORK_DIR="/scratch/frans/rna-seq"

# BAM files directory
export BAM_DIR="/scratch/frans/rna-seq/bams_with_rg"

# Sample pairs file
export SAMPLE_FILE="/scratch/frans/rna-seq/enhanced_sample_pairs_with_rg.tsv"
