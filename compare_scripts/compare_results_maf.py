# compare maf results of two runs

import pandas as pd

# specify which pair do you want to include
pair ="pair_01"
# specify the paths to the two results directories
results_dir1 = '/home/frans/scratch/rna-seq/results'
results_dir2 = '/project/rrg-bourqueg-ad/C3G/share/Lerner-Ellis_Sinai/RNA-seq/FINAL_MUTECT2_ANALYSIS/results'

# load both maf
maf1 = pd.read_csv(f'{results_dir1}/funcotator_pass_only/{pair}_pass_only.maf')
maf2 = pd.read_csv(f'{results_dir2}/funcotator_pass_only/{pair}_pass_only.maf')

# create key columns for comparison
maf1['key'] = maf1['Chromosome'] + '_' + maf1['Start'].astype(str) + '_' + maf1['End'].astype(str) + '_' + maf1['Strand'].astype(str)
maf2['key'] = maf2['Chromosome'] + '_' + maf2['Start'].astype(str) + '_' + maf2['End'].astype(str) + '_' + maf2['Strand'].astype(str)

# find unique keys in each maf
unique_to_maf1 = maf1[~maf1['key'].isin(maf2['key'])]
unique_to_maf2 = maf2[~maf2['key'].isin(maf1['key'])]

print(f"number of unique entries in maf1: {len(unique_to_maf1)}")
print(f"number of unique entries in maf2: {len(unique_to_maf2)}")
print("=="*50)

# print AS_FilterStatus for unique entries in maf1
print("AS_FilterStatus for unique entries in maf1:")
print(unique_to_maf1['AS_FilterStatus'].value_counts())
print("=="*50)
# print AS_FilterStatus for unique entries in maf2
print("AS_FilterStatus for unique entries in maf2:")
print(unique_to_maf2['AS_FilterStatus'].value_counts())
print("=="*50)

print("DONE")
