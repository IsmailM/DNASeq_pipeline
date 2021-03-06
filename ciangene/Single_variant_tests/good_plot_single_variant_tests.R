library(snpStats)
source("/cluster/project8/vyp/cian/data/UCLex/ciangene/scripts/LDAK/qqchisq.R") 
dir<-"/scratch2/vyp-scratch2/cian/UCLex_June2015/FastLMM_Single_Variant_all_phenos/"
files<-list.files(dir,full.names=T,pattern="merged") 

cohort.list<-c('Levine','Davina','Hardcastle','IoO','IoN','IoOFFS','IoONov2013','IoOPanos','Kelsell','LambiaseSD',
'Lambiase_','LayalKC','Manchester','Nejentsev','PrionUnit','Prionb2','Shamima','Sisodiya','Syrris','Vulliamy','WebsterURMD','gosgene')


res.files<-list.files("/scratch2/vyp-scratch2/cian/UCLex_June2015/KinshipDecomposition_combined_SNP_TK_RD",full.names=T,pattern="progress") 
prep<-TRUE
if(prep){
anno<-read.table("/scratch2/vyp-scratch2/cian/UCLex_June2015/annotations.snpStat",header=T,sep="\t") 
ex.ctrl<-read.table("/scratch2/vyp-scratch2/cian/UCLex_June2015/Ext_ctrl_variant_summary",header=T,sep="\t") 

mafs<-c(0.01) 
pdf("single_variant_tests.pdf") 
par(mfrow=c(2,2)) 
for(i in 1:length(cohort.list))
{
	print(cohort.list[i])
	cohort.files<-files[grep(cohort.list[i],files)]
	if(length(cohort.files)>0){
	base<-read.table(cohort.files[grep("base",cohort.files)],header=T,sep="\t") 
	tk<-read.table(cohort.files[grep("tk",cohort.files)],header=T,sep="\t") 
	perm<-read.table(cohort.files[grep("perm",cohort.files)],header=T,sep="\t") 
	base<-data.frame(SNP=base$SNP,baseP=base$Pvalue)
	tk<-data.frame(SNP=tk$SNP,tkP=tk$Pvalue)
	perm<-data.frame(SNP=perm$SNP,permeP=perm$Pvalue)
	base.perm<-merge(base,perm,by="SNP")
	pvals<-merge(base.perm,tk,by="SNP") 	
	dat<-merge(pvals,anno,by.x="SNP",by.y="clean.signature") 
	dat<-merge(dat,ex.ctrl,by="SNP")
	save(dat,file=paste0(dir,cohort.list[i],".RData") ) 
	dat$baseP<-as.numeric(as.character(dat$baseP))
	dat$tkP<-as.numeric(as.character(dat$tkP))
	dat$permeP<-as.numeric(as.character(dat$permeP))
	if(cohort.list[i]=="Lambiase_")cohort.list[i]<-"Lambiase\\."
	res<-read.table(res.files [grep(cohort.list[i],res.files) ],header=T,sep="\t") 
	var.explained<- paste(paste0("TK-",paste0(res$Iter[nrow(res)]*100,"%")),paste0("DP-",paste0(res$Her_K1[nrow(res)]*100,"%"))) 

	qq.chisq(-2*log(dat$baseP),df=2,x.max=30,pvals=T,main=paste(cohort.list[i],"base"),cex.main=.7) 
	qq.chisq(-2*log(dat$tkP),df=2,x.max=30,pvals=T,main=paste(cohort.list[i],"tk",var.explained),cex.main=.7) 
	qq.chisq(-2*log(dat$permeP),df=2,x.max=30,pvals=T,main=paste(cohort.list[i],"perm") ,cex.main=.7) 

	clean<-subset(dat,dat$FILTER=='PASS') 
	clean<-subset(clean,clean$MAF>0.01 ) 
	nb.snps.start<-nrow(dat)
	nb.clean.snps<-nrow(clean)
	snps.kept<-paste( paste0(round(nb.clean.snps/nb.snps.start*100),"%"),"kept") 

	qq.chisq(-2*log(clean$baseP),df=2,x.max=30,pvals=T,main=paste(cohort.list[i],"base PASS",snps.kept),cex.main=.7)  
	qq.chisq(-2*log(clean$tkP),df=2,x.max=30,pvals=T,main=paste(cohort.list[i],"tk PASS",var.explained,snps.kept),cex.main=.7) 
	qq.chisq(-2*log(clean$permeP),df=2,x.max=30,pvals=T,main=paste(cohort.list[i],"perm PASS",snps.kept),cex.main=.7) 
	for(maf in 1:length(mafs)) 	
	{
		tra<-subset(clean,clean$MAF > mafs[maf]) 
		nb.clean.snps<-nrow(tra)
		snps.kept<-paste( paste0(round(nb.clean.snps/nb.snps.start*100),"%"),"kept") 
		qq.chisq(-2*log(clean$baseP),df=2,x.max=30,pvals=T,main=paste(cohort.list[i],"base PASS maf",mafs[maf],snps.kept),cex.main=.7)  
		qq.chisq(-2*log(clean$tkP),df=2,x.max=30,pvals=T,main=paste(cohort.list[i],"tk PASS",mafs[maf],var.explained,snps.kept),cex.main=.7) 
		qq.chisq(-2*log(clean$permeP),df=2,x.max=30,pvals=T,main=paste(cohort.list[i],"perm PASS",mafs[maf],snps.kept),cex.main=.7)
	}
}
}
	dev.off()


load("Lambiase_.RData")
library(snpStats) 
dat$baseP<-as.numeric(as.character(dat$baseP))
dat$tkP<-as.numeric(as.character(dat$tkP)) 

png("Lambiase.png") 
par(mfrow=c(2,2))
qq.chisq(-2*log(dat$baseP),df=2,x.max=30,pvals=T,main="base")
qq.chisq(-2*log(dat$tkP),df=2,x.max=30,pvals=T,main="tk dp")
clean<-subset(dat,dat$FILTER=="PASS") 
clean<-subset(clean,clean$Call.rate>0.9) 
clean<-subset(clean,clean$MAF>0.01 ) 
qq.chisq(-2*log(clean$baseP),df=2,x.max=30,pvals=T,main="base clean")
qq.chisq(-2*log(clean$tkP),df=2,x.max=30,pvals=T,main="tk dp clean")
dev.off()

} # prep

### short list of plots
files<-list.files(dir,pattern="RData",full.names=T) 
message("Starting quick plots") 
mafs<-c(0.01) ;maf=1
pdf("single_variant_tests_filt.pdf") 
par(mfrow=c(2,2)) 
for(i in 1:length(cohort.list))
{
	print(cohort.list[i])
	cohort.files<-files[grep(cohort.list[i],files)]
	if(length(cohort.files)>0){
	if(cohort.list[i]=="Lambiase_")cohort.list[i]<-"Lambiase\\."
	load(cohort.files) 
	dat$baseP<-as.numeric(as.character(dat$baseP))
	dat$tkP<-as.numeric(as.character(dat$tkP)) 
	dat$permeP<-as.numeric(as.character(dat$permeP)) 
	qq.chisq(-2*log(dat$baseP),df=2,x.max=30,pvals=T,main=paste(cohort.list[i],"base"),cex.main=.7)  
	qq.chisq(-2*log(dat$tkP),df=2,x.max=30,pvals=T,main=paste(cohort.list[i],"tk dp"),cex.main=.7) 
	qq.chisq(-2*log(dat$permeP),df=2,x.max=30,pvals=T,main=paste(cohort.list[i],"perm"),cex.main=.7)

	res<-read.table(res.files [grep(cohort.list[i],res.files) ],header=T,sep="\t") 
	var.explained<- paste(paste0("TK-",paste0(res$Iter[nrow(res)]*100,"%")),paste0("DP-",paste0(res$Her_K1[nrow(res)]*100,"%"))) 
	clean<-subset(dat,dat$FILTER=="PASS") 
	clean<-subset(clean,clean$Call.rate>0.9) 
	clean<-subset(clean,clean$MAF>0.01 ) 
	nb.snps.start<-nrow(dat)
	nb.clean.snps<-nrow(clean)
	snps.kept<-paste( paste0(round(nb.clean.snps/nb.snps.start*100),"%"),"kept") 

	qq.chisq(-2*log(clean$baseP),df=2,x.max=30,pvals=T,main=paste(cohort.list[i],"base PASS maf",mafs[maf],snps.kept),cex.main=.7)  
	qq.chisq(-2*log(clean$tkP),df=2,x.max=30,pvals=T,main=paste(cohort.list[i],"tk PASS",mafs[maf],var.explained,snps.kept),cex.main=.7)  
	qq.chisq(-2*log(clean$permeP),df=2,x.max=30,pvals=T,main=paste(cohort.list[i],"perm PASS",mafs[maf],snps.kept),cex.main=.7)  
}
}
dev.off()


ensembl = useMart("ensembl",dataset="hsapiens_gene_ensembl")
biomart.filter="ensembl_gene_id"
attributes =  c("ensembl_gene_id", "external_gene_name", "chromosome_name","start_position","end_position")
genes.annotated<- getBM(attributes= attributes , filters = biomart.filter , values = dat$Gene , mart = ensembl)
genes<-genes.annotated[,1]





