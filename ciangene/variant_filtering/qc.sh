#!/bin/bash
ldak=/home/sejjcmu/bin/ldak/ldak.4.9.fast
Rbin=/share/apps/R/bin/R
plink=/share/apps/genomics/plink-1.07/plink
#rootODir=/scratch2/vyp-scratch2/ciangene
rootODir=/cluster/project8/vyp/cian/data/UCLex/
release=June2016
rootODir=${1-$rootODir}
release=${2-$release}
bDir=${rootODir}

iData=$bDir"allChr_snpStats"
ln -s $bDir"UCLex_${release}.bim" $iData".bim"
ln -s $bDir"UCLex_${release}.fam" $iData".fam"

$ldak --make-bed $iData --sp $iData

HPOpheno=/cluster/project8/vyp/pontikos/UCLex/phenotypes.csv
keep=/cluster/project8/vyp/cian/data/UCLex/DNAseq_pipeline/HPO/keep.samples
sed 's/,/\t/g' $HPOpheno | sed 's/ //g' | awk '{print $3,$3}' > $keep
#$plink --bfile $data --keep $keep --make-bed --out $data

data=$bDir"allChr_snpStats_out" 
$plink --noweb --allow-no-sex --bfile $data --freq --out $bDir/gstats
$plink --noweb --allow-no-sex --bfile $data --missing --out $bDir/gstats
$plink --noweb --allow-no-sex --bfile $data --hardy --out $bDir/gstats
$plink --noweb --bfile $data  --impute-sex --out $bDir/gstats


 
sed -i 's/ \+ /\t/g' $bDir/gstats.imiss
tr -s " " < ${bDir}gstats.imiss > ${bDir}gstats.imiss_clean

oFile=$bDir/plot.qc.R
echo "dir<-'"$bDir"'" > $oFile
echo '
	library(plyr) 
	library(ggplot2)

	miss <- read.table(paste0(dir,"gstats.lmiss"),header=T )
	frq <- read.table(paste0(dir,"gstats.frq"),header=T )

	cohort.list<-c("Levine","Davina","Hardcastle","IoO","IoN","IoOFFS","IoONov2013","IoOPanos","Kelsell","LambiaseSD",
	"Lambiase","LayalKC","Manchester","Nejentsev","PrionUnit","Prionb2","Shamima","Sisodiya","Syrris","Vulliamy","WebsterURMD")

	png(paste0(dir, "/plots/gstats.png") )
		par(mfrow=c(2,2))  
		plot.ecdf(miss$F_MISS, xlab="Missingness", main = "UCLex Variant Missingness") ### Change to CDF 		
		plot.ecdf(frq$MAF, xlab="MAF", main = "UCLex_MAF")
	dev.off() 

	file<-read.table("gstats.imiss_clean",header=T,sep=" ") 
	sample<-read.table("Sample.cohort",header=F,sep="\t")
	plot.data<-data.frame(sample=sample[,1],cohort=sample[,2],Missingness=file[,ncol(file)]) 
	plot.data<-plot.data[plot.data$cohort%in%cohort.list,] 
	dat<-ddply(plot.data,.(cohort),summarize,CallRate=1-mean(Missingness) ) 
	pdf(paste0(dir, "/plots/callRate_cohort.pdf"))
	print(qplot(cohort,CallRate,data=dat)+ theme(axis.text.x = element_text(angle = 45, hjust = 1)) )
	dev.off()
	' >> $oFile
$Rbin CMD BATCH --no-save --no-restore $oFile

		
