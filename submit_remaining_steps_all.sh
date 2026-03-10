#!/bin/bash
WORK_DIR="/scratch/rad123/FINAL_MUTECT2_ANALYSIS"
cd ${WORK_DIR}

mkdir -p results/pileup_summaries results/contamination results/filtered_calls

echo "Submitting pipeline steps..."

JOB2=$(sbatch scripts/step2_learn_orientation_all.sh | awk '{print $4}')
echo "Step 2: ${JOB2}"

JOB3=$(sbatch scripts/step3_pileup_summaries_all.sh | awk '{print $4}')
echo "Step 3: ${JOB3}"

JOB4=$(sbatch --dependency=afterok:${JOB3} scripts/step4_calculate_contamination_all.sh | awk '{print $4}')
echo "Step 4: ${JOB4} (after ${JOB3})"

JOB5=$(sbatch --dependency=afterok:${JOB2}:${JOB4} scripts/step5_filter_mutect_all.sh | awk '{print $4}')
echo "Step 5: ${JOB5} (after ${JOB2} and ${JOB4})"

echo ""
echo "Monitor: squeue -u $USER"