SOP: Mutect2 Somatic Variant Calling Pipeline for RNA-seq Data

Table of Contents -
1. Overview & Rationale
2. Prerequisites & Data Requirements
3. Pipeline Steps (Detailed)
4. RNA-seq Specific Modifications
5. Troubleshooting Guide
6. Output Files & Interpretation
7. Quality Control Metrics


1. Overview & Rationale
Purpose -
This pipeline identifies somatic mutations in tumor samples compared to matched normal samples using RNA-seq data with GATK Mutect2.

Why Mutect2 for RNA-seq?
- Designed for somatic variants: Distinguishes tumor-specific mutations from germline variants
- Handles tumor-normal pairs: Uses matched normal to filter germline variants and technical artifacts
- Statistical modeling: Bayesian framework for variant calling with contamination estimation
- Widely validated: Standard tool in cancer genomics

Key Challenge: RNA-seq vs DNA-seq

RNA-seq data presents unique challenges:
- No mapping quality scores: STAR aligner assigns MAPQ=255 (unavailable)
- Strand bias: Directional library prep creates expected bias
- Splicing artifacts: Reads span exon junctions creating soft clips
- RNA editing: A-to-I editing creates false "mutations"
- Expression-dependent coverage: Highly expressed genes have more reads
Solution: Disable or relax quality filters designed for DNA-seq throughout the pipeline.

2. Prerequisites & Data Requirements
Input Data Required:
BAM files (66 tumor + 66 matched normal = 132 files)
- Aligned to reference genome (GRCh38)
- Must have read groups (@RG tags with SM field)
- Indexed (.bai files)

Sample pairing file (TSV format):
   tumor_bam	        normal_bam	                tumor_sample_name	normal_sample_name	   pair_id
   /path/to/tumor.bam	/path/to/normal.bam	        T001	            N001	               pair_01

Reference Resources:
- Reference genome FASTA + index + dictionary
- gnomAD population variant database (for germline calling)
- Calling intervals (WGS or exome regions)

Software Requirements:
- module load StdEnv/2023
- module load gatk
- module load samtools

Directory Structure:
FINAL_MUTECT2_ANALYSIS/
├── bams_with_rg/               # Input BAM files
├── resources/                  # Reference files
├── scripts/                    # Pipeline scripts
├── logs/                       # SLURM logs
└── results/
    ├── pon/                    # Panel of Normals
    ├── mutect2_calls/          # Raw variant calls
    ├── pileup_summaries/       # Contamination data
    ├── contamination/          # Contamination estimates
    ├── filtered_calls_relaxed/ # Filtered variants
    └── funcotator_annotated/   # Annotated variants

3. Pipeline Steps (Detailed)

Step 0: Panel of Normals (PON) Creation
Purpose: Create a database of recurrent artifacts seen in normal samples to filter false positives
Why needed: Normal samples contain technical artifacts, germline variants, and RNA editing sites that appear as "variants" but aren't true somatic mutations

Process:
1. Run Mutect2 on each normal sample in tumor-only mode
2. Combine all normal VCFs into a single PON using CreateSomaticPanelOfNormals
3. Sites present in multiple normals are flagged as likely artifacts

Command (per normal sample):
gatk Mutect2 \
    -R reference.fasta \
    -I normal.bam \
    --max-mnp-distance 0 \
    --disable-read-filter MappingQualityAvailableReadFilter \
    --disable-read-filter MappingQualityReadFilter \
    -O normal_for_pon.vcf.gz

Critical RNA-seq modifications:
--disable-read-filter MappingQualityAvailableReadFilter: Allows reads with MAPQ=255
--disable-read-filter MappingQualityReadFilter: Disables MAPQ threshold checks

Output: rnaseq_panel_of_normals.vcf.gz (~10.7M sites for 66 normals)

Step 1: Mutect2 Somatic Variant Calling
Purpose: Call variants present in tumor but not in matched normal
Theory: Mutect2 uses a Bayesian model to calculate the probability that a variant is:
- Somatic (tumor-specific)
- Germline (inherited, in both samples)
- Artifact (technical error)

Command:
gatk Mutect2 \
    -R reference.fasta \
    -I tumor.bam \
    -I normal.bam \
    -tumor TUMOR_NAME \
    -normal NORMAL_NAME \
    --germline-resource gnomad.vcf.gz \
    --panel-of-normals pon.vcf.gz \
    --intervals calling_regions.interval_list \
    --disable-read-filter MappingQualityAvailableReadFilter \
    --disable-read-filter MappingQualityReadFilter \
    --dont-use-soft-clipped-bases true \
    --min-base-quality-score 20 \
    --native-pair-hmm-threads 4 \
    --f1r2-tar-gz output_f1r2.tar.gz \
    -O unfiltered.vcf.gz

RNA-seq specific parameters:
--dont-use-soft-clipped-bases true: Ignore soft clips from splicing
--min-base-quality-score 20: Higher base quality threshold (compensates for lack of MAPQ)
--f1r2-tar-gz: Collect data for orientation bias modeling

Why these filters matter:
- MAPQ filters: Would reject 100% of reads if not disabled
- Soft clips: RNA splicing creates legitimate soft clips that shouldn't disqualify reads
- Base quality: We rely more on base quality since MAPQ is unavailable

Output per pair:
- pair_XX_unfiltered.vcf.gz: Raw variant calls (~175k variants/pair)
- pair_XX_f1r2.tar.gz: Orientation bias data

Step 2: Learn Read Orientation Model
Purpose: Model sequencing artifacts related to read orientation (particularly oxidative damage during library prep)
Theory: Some artifacts occur preferentially on F1R2 vs F2R1 reads. This step builds a statistical model of expected vs observed orientation patterns

Command:
gatk LearnReadOrientationModel \
    -I f1r2.tar.gz \
    -O read_orientation_model.tar.gz

What it does:
- Analyzes trinucleotide context and strand bias
- Uses expectation-maximization algorithm
- Some contexts may not converge (expected, not an error)

Output: pair_XX_read_orientation_model.tar.gz

Step 3: Get Pileup Summaries
Purpose: Calculate allele frequencies at common population variant sites for contamination estimation
Theory: If tumor sample is contaminated with normal DNA (or vice versa), allele frequencies at heterozygous germline sites will deviate from expected 0.5
Why needed: Cross-sample contamination can create false positives or mask true mutations

Command:
#Tumor
gatk GetPileupSummaries \
    -I tumor.bam \
    -V gnomad.vcf.gz \
    -L intervals.interval_list \
    --disable-read-filter MappingQualityAvailableReadFilter \
    --disable-read-filter MappingQualityReadFilter \
    --disable-read-filter MappingQualityNotZeroReadFilter \
    -O tumor_pileups.table
#Normal (same parameters)

Critical discovery: 
- GetPileupSummaries also applies MAPQ filters by default, these must be explicitly disabled for RNA-seq
- Without filter disabling: Processed 0 loci, 100% reads filtered
- With filter disabling: Processed ~30M loci successfully

Output: Allele counts at ~1.7M common variant sites

Step 4: Calculate Contamination
Purpose: Estimate the fraction of reads from contaminating DNA and identify copy number segments
Theory:
- Compares observed vs expected allele frequencies at germline heterozygous sites
- Uses matched normal to distinguish germline from somatic variants
- Models contamination as a uniform shift in allele frequencies

Command:
gatk CalculateContamination \
    -I tumor_pileups.table \
    -matched normal_pileups.table \
    -O contamination.table \
    --tumor-segmentation segments.table

Output:
- Contamination estimates (~0.6-0.9% for this dataset)
- Segmentation table (copy number regions)

Step 5: Filter Mutect Calls
Purpose: Apply statistical filters to remove false positives while retaining true somatic variants
Theory: Multiple independent filters flag likely artifacts:
- base_qual: Median base quality too low
- strand_bias: Variant reads predominantly on one strand
- weak_evidence: Low supporting read count or quality
- normal_artifact: Variant present in matched normal
- panel_of_normals: Variant in PON (recurrent artifact)
- contamination: Variant consistent with contamination
- clustered_events: Multiple variants in close proximity
- germline: Likely germline based on allele frequency

Initial filtering (standard parameters):
gatk FilterMutectCalls \
    -R reference.fasta \
    -V unfiltered.vcf.gz \
    --contamination-table contamination.table \
    --tumor-segmentation segments.table \
    --ob-priors orientation_model.tar.gz \
    -O filtered.vcf.gz

Result: 0 PASS variants (100% filtered by base_qual)
Problem: Default --min-median-base-quality and --min-median-mapping-quality are too stringent for RNA-seq where MBQ values are low and MAPQ is unavailable

Solution - Relaxed filtering for RNA-seq:
gatk FilterMutectCalls \
    -R reference.fasta \
    -V unfiltered.vcf.gz \
    --contamination-table contamination.table \
    --tumor-segmentation segments.table \
    --ob-priors orientation_model.tar.gz \
    --min-median-base-quality 0 \
    --min-median-mapping-quality 0 \
    -O filtered.vcf.gz
    
Result: ~33k PASS variants per pair (19% pass rate)

Remaining filters (after relaxing base quality):
- strand_bias: Most common (expected for stranded RNA-seq)
- weak_evidence: Low read support
- panel_of_normals: In PON
- normal_artifact: Present in matched normal

Output:
Total: 11.5M variants (66 pairs)
PASS: 2.2M variants (19% pass rate)

Step 6: Functional Annotation with Funcotator
Purpose: Annotate variants with gene names, functional effects, population frequencies, and clinical significance
Why needed: Converts genomic coordinates to biological meaning (which gene, what effect on protein, is it known in databases)

Command:
gatk Funcotator \
    --variant filtered.vcf.gz \
    --reference reference.fasta \
    --ref-version hg38 \
    --data-sources-path funcotator_datasources/ \
    --output annotated.maf \
    --output-file-format MAF \
    --transcript-selection-mode BEST_EFFECT \
    --remove-filtered-variants false

Parameters explained:
--output-file-format MAF: Mutation Annotation Format (standard in cancer genomics)
--transcript-selection-mode BEST_EFFECT: Choose transcript with most severe consequence
--remove-filtered-variants false: Include all variants, not just PASS

Data sources included:
GENCODE: Gene annotations
dbSNP: Known variants
gnomAD: Population frequencies
COSMIC: Cancer mutation database
ClinVar: Clinical significance
UniProt: Protein annotations

Output columns include:
Hugo_Symbol: Gene name
Variant_Classification: Effect (Missense, Nonsense, Silent, etc.)
t_alt_count, t_ref_count: Tumor allele counts
n_alt_count, n_ref_count: Normal allele counts
COSMIC, ClinVar annotations

Step 7: Create Three Filtered Versions
Purpose: Provide datasets at different stringency levels for different analyses

Version 1: All Variants (~181k per pair)
- All variants from Mutect2, regardless of filter status
- Includes germline, artifacts, and somatic
- Use for: Comprehensive analysis, identifying all potential variants

Version 2: Somatic-Only (~134k per pair)
- Filter: n_alt_count == 0 (no alternate allele in normal)
- Removes germline variants and shared artifacts
- Use for: True tumor-specific mutations

Filtering logic:
awk -F'\t' '{if($83==0) print}' all_variants.maf > somatic_only.maf
Where column 83 is n_alt_count

Version 3: PASS-Only (~30k per pair)
- Only variants with FILTER=PASS
- Highest confidence, most stringent
- Use for: High-confidence mutation lists, clinical reporting

Why three versions?
- All: Maximizes sensitivity, good for discovery
- Somatic-only: Balanced, removes obvious germline
- PASS-only: Maximizes specificity, minimizes false positives

4. RNA-seq Specific Modifications Summary
| Tool              | Parameter                     | DNA Default  | RNA Setting  | Reason                       |
|-------------------|-------------------------------|--------------|--------------|----------------------------- |
| Mutect2           | MAPQ filters                  | Enabled      | Disabled     | STAR assigns MAPQ = 255      |
| Mutect2           | Soft clips                    | Use          | Ignore       | Splicing creates soft clips  |
| Mutect2           | Base quality                  | 10           | 20           | Compensate for no MAPQ       |
| GetPileupSummaries| MAPQ filters                  | Enabled      | Disabled     | Same as Mutect2              |
| FilterMutectCalls | min-median-base-quality       | 20           | 0            | RNA has lower base qualities |
| FilterMutectCalls | min-median-mapping-quality    | 20           | 0            | MAPQ unavailable             |

What Happens If You Don't Modify These?
Without modifications:
- Mutect2: 496M reads processed → 496M reads filtered (100%) → 0 variants called
- GetPileupSummaries: 0 loci processed → Contamination calculation fails
- FilterMutectCalls: 11.5M variants → 0 PASS (100% filtered by base_qual)

With modifications:
- Mutect2: 344M reads pass filters (69%) → 11.5M variants called
- GetPileupSummaries: 30M loci processed → Contamination estimates succeed
- FilterMutectCalls: 11.5M variants → 2.2M PASS (19%)

5. Troubleshooting Guide
Problem: All reads filtered in Mutect2
Symptoms: X total reads filtered out of X reads processed
0 variants called
Solution: Add to Mutect2:
--disable-read-filter MappingQualityAvailableReadFilter \
--disable-read-filter MappingQualityReadFilter

Problem: 0 loci processed in GetPileupSummaries
Symptoms: Processed 0 total loci
Solution: Add to GetPileupSummaries:
--disable-read-filter MappingQualityAvailableReadFilter \
--disable-read-filter MappingQualityReadFilter \
--disable-read-filter MappingQualityNotZeroReadFilter

Problem: 0 PASS variants after filtering
Symptoms: base_qual filter applied to 100% of variants
Solution: Add to FilterMutectCalls:
--min-median-base-quality 0 \
--min-median-mapping-quality 0

6. Output Files & Interpretation
VCF Fields (Filtered VCF)

Key INFO fields:
- DP: Total depth
- TLOD: Tumor LOD score (higher = more confident)
- NLOD: Normal LOD score
- POPAF: Population allele frequency
- PON: Present in panel of normals

FILTER field values:
- PASS: High confidence variant
- strand_bias: Reads predominantly one strand
- weak_evidence: Low read support
- panel_of_normals: In PON
- normal_artifact: Present in normal
- Multiple filters separated by semicolons

MAF Fields (Funcotator output)
Essential columns:
- Hugo_Symbol: Gene name
- Variant_Classification: Functional effect
- t_alt_count: Tumor alternate reads
- t_ref_count: Tumor reference reads
- n_alt_count: Normal alternate reads (0 = somatic)
- n_ref_count: Normal reference reads

Quality Metrics to Check
Per-sample:
1. Variant count: 150k-250k unfiltered (normal range)
2. Pass rate: 13-21% (expected for RNA-seq with relaxed filters)
3. Contamination: <5% (this dataset: 0.6-0.9%)
4. Somatic fraction: 70-75% (n_alt_count=0)

Flags for concern:
- <50k variants: Possible low coverage or failed library
    500k variants: Possible contamination or technical issue
- <50% somatic: Possible sample swap or germline calls
    10% contamination: Sample handling issue

7. Key Takeaways
What Makes This Pipeline Work for RNA-seq
1. Disabled MAPQ filters: Critical at every step
2. Relaxed base quality: Accounts for RNA-specific noise
3. Panel of Normals: Removes RNA editing and recurrent artifacts
4. Contamination modeling: Accounts for cross-sample leakage
5. Multi-tier filtering: Three versions serve different needs

Biological Considerations
RNA-seq variants include:
- True somatic mutations
- Germline variants (expressed genes)
- RNA editing sites (A-to-I most common)
- Technical artifacts (splicing, library prep)

To distinguish:
- Use matched normal (removes germline)
- Use PON (removes recurrent artifacts)
- Check n_alt_count (removes shared variants)
- Filter by PASS status (highest confidence)

Computational Resources
Total runtime per pair: ~15-20 hours
Mutect2: 8 hours
Orientation: 5 minutes
Pileup: 6 hours
Contamination: 30 minutes
Filtering: 3 hours
Funcotator: 1 hour

Memory requirements:
Mutect2: 32GB
Other steps: 8-16GB

Storage (66 pairs):
BAMs: ~1.3TB (input)
Unfiltered VCFs: ~700GB
Filtered VCFs: ~200GB
MAF files: ~50GB

9. Citation & References
GATK Best Practices:
https://gatk.broadinstitute.org/hc/en-us/articles/360035894731
https://gatk.broadinstitute.org/hc/en-us/articles/360037224432

This Pipeline: Adapted GATK somatic short variant discovery pipeline for RNA-seq data with necessary filter modifications.