release=July2016

repo=/SAN/vyplab/UCLex/scripts/DNASeq_pipeline/ciangene/
export repo
pipeline=${repo}/pipeline/pipeline_cian_gene.sh


script=cluster/submission/cian.sh

rootODir=/SAN/vyplab/UCLex/mainset_${release}/cian/
#rootODir=/cluster/scratch3/vyp-scratch2/cian

step1=no
step2=yes
step3=no
step4=no

mkdir -p $rootODir

sh ${pipeline} --step1 ${step1} --step2 ${step2} --step3 ${step3} --step4 ${step4} --rootODir ${rootODir} --release $release
