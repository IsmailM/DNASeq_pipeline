# Multiple Sample Calling

Once the gvcf files have been generated using WGS, the samples can then be joined and integrated in the
next UCL Exome release.

# Merging gVCFs

First the gVCFs obtained from different batches can be merged with the following script:
```
merge_gVCF.sh
```
This script takes as input a list of gVCF files and joins them per chromosome.
The output goes to the combinedFolder per chromosome:

```
/scratch2/vyp-scratch2/vincent/GATK/HC/combinedVCFs/
```

The next step is to do the joint genotyping and the variant recalibration.
The output goes to:
```
/scratch2/vyp-scratch2/vincent/GATK/mainset_${currentUCLex}/mainset_${currentUCLex}
```