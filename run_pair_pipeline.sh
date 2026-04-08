#!/bin/bash
# Driver script to run complete Mutect2 pipeline for a single pair using SLURM dependencies
# Usage: bash run_pair_pipeline.sh <pair_number>
# Example: bash run_pair_pipeline.sh 1

PAIR_NUM=${1:-1}
PAIR_ID=$(printf "pair_%02d" $PAIR_NUM)

echo "=========================================="
echo "Submitting Mutect2 Pipeline for $PAIR_ID"
echo "=========================================="
echo ""

# Step 1: Mutect2 Calling
echo "Submitting Step 1: Mutect2 Variant Calling..."
STEP1=$(sbatch --parsable --array=${PAIR_NUM} scripts/step1_run_mutect2_all_pairs_rnaseq.sh)
echo "  Job ID: $STEP1"

# Step 2: Learn Read Orientation Model (depends on Step 1)
echo "Submitting Step 2: Learn Read Orientation Model..."
STEP2=$(sbatch --parsable --dependency=afterok:$STEP1 --array=${PAIR_NUM} scripts/step2_learn_orientation_all.sh)
echo "  Job ID: $STEP2 (depends on $STEP1)"

# Step 3: Pileup Summaries (depends on Step 1)
echo "Submitting Step 3: Calculate Pileup Summaries..."
STEP3=$(sbatch --parsable --dependency=afterok:$STEP1 --array=${PAIR_NUM} scripts/step3_pileup_summaries_all.sh)
echo "  Job ID: $STEP3 (depends on $STEP1)"

# Step 4: Calculate Contamination (depends on Step 3)
echo "Submitting Step 4: Calculate Contamination..."
STEP4=$(sbatch --parsable --dependency=afterok:$STEP3 --array=${PAIR_NUM} scripts/step4_calculate_contamination_all.sh)
echo "  Job ID: $STEP4 (depends on $STEP3)"

# Step 5: Filter Variants (depends on Steps 2 and 4)
echo "Submitting Step 5: Filter Mutect Calls..."
STEP5=$(sbatch --parsable --dependency=afterok:$STEP2:$STEP4 --array=${PAIR_NUM} scripts/step5_filter_mutect_all.sh)
echo "  Job ID: $STEP5 (depends on $STEP2 and $STEP4)"

# Step 6: Funcotator Annotation (depends on Step 5)
echo "Submitting Step 6: Funcotator Annotation..."
STEP6=$(sbatch --parsable --dependency=afterok:$STEP5 --array=${PAIR_NUM} scripts/funcotator_all_samples.sh)
echo "  Job ID: $STEP6 (depends on $STEP5)"

# Step 7: Create MAF Subsets (depends on Step 6)
echo "Submitting Step 7: Create MAF Subsets..."
STEP7=$(sbatch --parsable --dependency=afterok:$STEP6 --array=${PAIR_NUM} scripts/filter_maf_versions.sh)
echo "  Job ID: $STEP7 (depends on $STEP6)"

echo ""
echo "=========================================="
echo "All jobs submitted successfully!"
echo "=========================================="
echo ""
echo "Pipeline Job IDs:"
echo "  Step 1 (Mutect2):          $STEP1"
echo "  Step 2 (Orientation):      $STEP2"
echo "  Step 3 (Pileup):           $STEP3"
echo "  Step 4 (Contamination):    $STEP4"
echo "  Step 5 (Filter):           $STEP5"
echo "  Step 6 (Funcotator):       $STEP6"
echo "  Step 7 (MAF Subsets):      $STEP7"
echo ""
echo "Monitor progress:"
echo "  squeue -u \$USER"
echo "  squeue -j $STEP1,$STEP2,$STEP3,$STEP4,$STEP5,$STEP6,$STEP7"
echo ""
echo "Check logs:"
echo "  ls -lt slurm-*.out | head"
echo ""
echo "Cancel all jobs if needed:"
echo "  scancel $STEP1 $STEP2 $STEP3 $STEP4 $STEP5 $STEP6 $STEP7"
echo ""
