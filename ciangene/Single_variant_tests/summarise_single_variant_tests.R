## Run after plot_singleVariant_results.R to get more detailed stats about interesting variants. 
library(HardyWeinberg)
library(snpStats) 
library(biomaRt)
library(foreach) 
library(doMC)
registerDoMC(4) ## Run across 4 cores cos this script is slow AS


## Some data and links to start
release<-'July2015'
ldak<-'/cluster/project8/vyp/cian/support/ldak/ldak'
bDir<-paste0("/scratch2/vyp-scratch2/cian//UCLex_",release,"/") 
data<-paste0(bDir,'allChr_snpStats_out') 
func <- c("nonsynonymous SNV", "stopgain SNV", "nonframeshift insertion", "nonframeshift deletion", "frameshift deletion", 
		"frameshift substitution", "frameshift insertion",  "nonframeshift substitution", "stoploss SNV", "splicing"
		,"exonic;splicing")
lof <-  c("frameshift deletion", "frameshift substitution", "frameshift insertion",  "stoploss SNV", "splicing"
		,"stopgain SNV","exonic;splicing"
		)


pheno<-read.table(paste0(bDir,'Clean_pheno_subset'))
fam<-read.table(paste0(bDir,'allChr_snpStats_out.fam'))
cohorts<-read.table(paste0(bDir,'cohort.list'))
colnames(pheno)<-c(rep("Samples",2),cohorts[,1])
## Do initial filtering, by pvalue, quality, extCtrl maf and function/LOF status
variant.filter<-function(dat,pval=0.0001,pval.col="TechKinPvalue",func.filt=TRUE, lof.filt=FALSE,max.maf=.05) 
{
	message("Filtering data")
#	clean<-subset(dat, dat$FILTER=="PASS") 
#	pval.col.nb<-colnames(clean)%in%pval.col
#	sig<-subset(clean,clean[,pval.col.nb]<=pval) 
	sig<-subset(dat,dat$Pvalue<=pval|dat$TechKinPvalue<=pval) 
	funcy<-sig[sig$ExonicFunc %in% func | sig$Func %in% func,]
	funcy$ESP6500si_ALL[is.na(funcy$ESP6500si_ALL)]<-0
	funcy$ExtCtrl_MAF[is.na(funcy$ExtCtrl_MAF)]<-0
	rare<- subset(funcy,funcy$ExtCtrl_MAF < max.maf & funcy$ESP6500si_ALL < max.maf) 
#	return(funcy)
	return(rare) 
}#

## Get calls for variants that are left after filtering. 
prepData<-function(file,snp.col="SNP", cases="Syrris")
{
	snps<-file[,colnames(file)%in%snp.col]
	write.table(snps,paste0(bDir,cases),col.names=F,row.names=F,quote=F,sep="\t") 
	message(paste("Extracting",length(snps)," variants from full file") ) 
	system( paste(ldak, "--make-sp", cases,"--bfile", data, "--extract", paste0(bDir,cases) )) 
	message("Reading variants into R session") 
	calls<-read.table(paste0(cases,"_out.sp"),header=F)
	fam<-read.table(paste0(cases,"_out.fam"),header=F)
	bim<-read.table(paste0(cases,"_out.bim"),header=F) 
	rownames(calls)<-bim[,2]
	colnames(calls)<-fam[,1]
	return(calls)
}


############# Now do fisher test
## data is the data.frame/matrix of calls, rows are variants. cases is the character vector of phenotype to be treated as cases. 
doFisher<-function(data, cases="Syrris")
{
	data<-data[,colnames(data)%in%pheno[,1] ]
	cc.col<-colnames(pheno)%in%cases
	remove<-pheno[is.na(pheno[,cc.col]) ,1]
	data<-data[,!colnames(data)%in%remove ]

	case.cols<-grep(cases, colnames(data)) 
	ctrl.cols<-which(!grepl(cases, colnames(data)) )

	## make dataframe for results
	colNamesDat <- c("SNP",  "FisherPvalue", "nb.mutations.HCM", "nb.mutations.ARVC", "nb.HCM", "nb.ARVC", 
	"HCM.maf", "ARVC.maf" , "nb.Homs.HCM", "nb.Homs.ARVC", "nb.Hets.HCM", "nb.Hets.ARVC",
	"nb.NAs.HCM", "nb.NAs.ARVC") 
	dat <- data.frame(matrix(nrow = nrow(calls), ncol = length(colNamesDat) ) )
	colnames(dat) <- colNamesDat
	dat[,1] <- rownames(calls) 

	message("Starting fisher tests")
	## calc fisher pvals
	for(i in 1:nrow(data))
	{
	if(i%%50==0)message(paste(i, 'tests done'))
	case.calls <-  t(as.matrix(calls[i,colnames(calls)%in%colnames(data)[case.cols]]))
	ctrl.calls <- t(as.matrix(calls[i,colnames(calls)%in%colnames(data)[ctrl.cols]]))

	chr<-gsub(rownames(data[i,]),pattern="_.*",replacement="")
	if(chr=="X"|chr==23) 
	{
		case.gender<-fam[fam[,1]%in%rownames(case.calls),]
		males<-case.gender[case.gender[,5]==1,1]
		case.calls[ rownames(case.calls) %in% males & case.calls[,1] == 2 & is.finite(case.calls[,1]),1]  <- 1

		ctrl.gender<-fam[fam[,1]%in%rownames(ctrl.calls),]
		males<-ctrl.gender[ctrl.gender[,5]==1,1]
		ctrl.calls[ rownames(ctrl.calls) %in% males & ctrl.calls[,1] == 2 & is.finite(ctrl.calls[,1]),1]  <- 1
	}

	number_Homs_cases <- length(which(unlist(case.calls) == 2))
	number_Homs_ctrls <- length(which(unlist(ctrl.calls) == 2))

	case.hom.major <- length(which(unlist(case.calls) == 0))
	case.hets<- length(which(unlist(case.calls) == 1))
	case.freqs <- c(case.hom.major, case.hets, number_Homs_cases)
	case.maf <- maf(case.freqs)

	ctrl.hom.major <- length(which(unlist(ctrl.calls) == 0))
	ctrl.hets<- length(which(unlist(ctrl.calls) == 1))
	ctrl.freqs <- c(ctrl.hom.major, ctrl.hets, number_Homs_ctrls)
	ctrl.maf <- maf(ctrl.freqs)	

	flip<-TRUE
	if(flip) 
	{
	if(number_Homs_cases>case.hom.major) ## fix minor allele switch. 
	{
	tmp<-case.hom.major
	case.hom.major<-number_Homs_cases
	number_Homs_cases<-tmp
	case.calls[which(unlist(case.calls) == 2)]<-3
	case.calls[which(unlist(case.calls) == 0)]<-2
	case.calls[which(unlist(case.calls) == 3)]<-0
	}
	if(number_Homs_ctrls>ctrl.hom.major)
	{
	tmp<-ctrl.hom.major
	ctrl.hom.major<-number_Homs_ctrls
	number_Homs_ctrls<-tmp
	ctrl.calls[which(unlist(ctrl.calls) == 2)]<-3
	ctrl.calls[which(unlist(ctrl.calls) == 0)]<-2
	ctrl.calls[which(unlist(ctrl.calls) == 3)]<-0
	}	
	}

	number_mutations_cases <- sum( case.calls , na.rm=T )
	number_mutations_ctrls <- sum( ctrl.calls , na.rm=T ) 

	nb.nas.cases <- length(which(is.na(case.calls)))
	nb.nas.ctrls <- length(which(is.na(ctrl.calls)))

	nb.cases <-  length(which(!is.na( case.calls )) ) 
	nb.ctrls <-  length(which(!is.na( ctrl.calls )) ) 
		
	mean_number_case_chromosomes <- nb.cases * 2
	mean_number_ctrl_chromosomes <- nb.ctrls * 2

	if (!is.na(number_mutations_cases)  & !is.na(number_mutations_ctrls)  )
	{
	if (nb.cases > 0 & nb.ctrls > 0)
	{
		fishertest <-  fisher.test((matrix(c(number_mutations_cases, mean_number_case_chromosomes
		                         - number_mutations_cases, number_mutations_ctrls, mean_number_ctrl_chromosomes - number_mutations_ctrls),
		                       nrow = 2, ncol = 2)))


	dat$FisherPvalue[i] <- fishertest$p.value 
	dat$nb.mutations.HCM[i] <- number_mutations_cases
	dat$nb.mutations.ARVC[i]<- number_mutations_ctrls
	dat$nb.HCM[i]<- nb.cases 
	dat$nb.ARVC[i] <- nb.ctrls 
	dat$nb.NAs.HCM[i] <- nb.nas.cases 
	dat$nb.NAs.ARVC[i] <- nb.nas.ctrls
	dat$nb.Homs.HCM[i]<- number_Homs_cases
	dat$nb.Homs.ARVC[i]<- number_Homs_ctrls	
	dat$HCM.maf[i]<- case.maf
	dat$ARVC.maf[i]	<- ctrl.maf
	dat$nb.Hets.HCM[i] <- case.hets
	dat$nb.Hets.ARVC[i] <- ctrl.hets

	}
	}
} # for(i in 1:nrow(data))

colnames(dat)<-gsub(colnames(dat), pattern="HCM", replacement=cases) 
colnames(dat)<-gsub(colnames(dat), pattern="ARVC", replacement="ctrls") 
dat<-dat[order(dat$FisherPvalue),]
message("Finished Fisher tests")
return(dat)
} # End of function 


annotate<-function(data,genes)
{
	ensembl = useMart("ensembl",dataset="hsapiens_gene_ensembl")
	filter="ensembl_gene_id"
	attributes =  c("ensembl_gene_id", "external_gene_name",  "phenotype_description")
	gene.data <- getBM(attributes= attributes , filters = filter , values=data$Gene , mart = ensembl)
	gene.data.uniq <- gene.data[!duplicated(gene.data$external_gene_name),]
	anno<-merge(data,gene.data.uniq,by.x='Gene',by.y='ensembl_gene_id',all.x=T)
	return(anno)
}


#########################################
######### Now run
#########################################
dataDir<-paste0("/scratch2/vyp-scratch2/cian/UCLex_",release,"/FastLMM_Single_Variant_all_phenos/") 
files<-list.files(dataDir,pattern='final',full.names=T)
names<-gsub(basename(files),pattern="_.*",replacement='')
extCtrlDir<-paste0("/scratch2/vyp-scratch2/cian/UCLex_",release,"/External_Control_data/") 
extCtrlFiles<-list.files(extCtrlDir,pattern='lmiss',full.names=T)
extCtrlnames<-gsub(basename(extCtrlFiles),pattern="_.*",replacement='')
exit
source("LDAK/qqchisq.R")
mafs<-c(0,0.00001,0.0001,0.001,0.01,0.1) 
exit
process<-TRUE
pdf(paste0(dataDir,"Single.variant_ex_ctrl_maf_filter.pdf") ) 
par(mfrow=c(2,2)) 

variables<-ls() 
#foreach(i=1:length(files), .export=variables, .packages=c("biomaRt",'HardyWeinberg','snpStats')  ) %dopar%
 for(i in 1:length(files))
{
	print(paste("Reading in",names[i]))
	file<-read.csv(files[i],header=T,sep="\t",quote = "",stringsAsFactors=F) 
	file$TechKinPvalue<-as.numeric(file$TechKinPvalue)
	file$Pvalue<-as.numeric(file$Pvalue)
	for(maf in 1:length(mafs))
	{
	dat<-subset(file,file$ExtCtrl_MAF>=mafs[maf]) 
	qq.chisq(-2*log(dat$Pvalue),df=2,x.max=30,main=paste(names[i],"uncorrected pvalues -",nrow(dat),"SNPS"),pvals=T,cex.main=.8) 
	qq.chisq(-2*log(dat$TechKinPvalue),df=2,x.max=30,main=paste(names[i],"TKRD pvalues - maf",mafs[maf]),pvals=T,cex.main=.8) 
	}
	if(process)   ###########################################################
	{
	filt<-variant.filter(file,pval=.0001) 
	calls<-prepData(filt,cases=names[i]) 
	pvals<-doFisher(calls,cases=names[i]) 
	## want to verify the significant techKin pvalues with fisher
	merged<-merge(filt, pvals,by="SNP",all=T) 
#	anno<-annotate(merged,merged$Gene) 
	anno<-merged ## annotated in first script now. 	

	ex.ctrl<-extCtrlFiles[extCtrlnames %in% names[i] ]
	ex.case<-ex.ctrl[grep('case',ex.ctrl)]
	ex.ctrl<-ex.ctrl[grep('CC',ex.ctrl)]
	if(length(ex.case)>0&length(ex.ctrl)>0) 
	{
		system( paste('tr -s " " <',ex.case , '>', paste0(ex.case,'_clean') ) [1])
		system( paste('tr -s " " <',ex.ctrl, '>', paste0(ex.ctrl,'_clean') ) [1] )
		ex.case<-read.table( paste0(ex.case,'_clean')[1],header=T,sep=" ") 
		ex.ctrl<-read.table( paste0(ex.ctrl,'_clean')[1],header=T,sep=" ") 
		callrates=data.frame(SNP=ex.ctrl$SNP,CaseCallRate=ex.case$F_MISS,CtrlCallRate=ex.ctrl$F_MISS) 
		anno<-merge(anno,callrates,by='SNP',all.x=T) 
	}
	anno<-anno[order(anno$FisherPvalue),]
	anno$Pvalue<-as.numeric(as.character(anno$Pvalue))
	anno$TechKinPvalue<-as.numeric(as.character(anno$TechKinPvalue))
	write.table(anno, paste0(dataDir,names[i],'_single_variant_vs_UCLex.csv'), col.names=T,row.names=F,quote=T,sep=",") 
	} # process
}
dev.off() 
