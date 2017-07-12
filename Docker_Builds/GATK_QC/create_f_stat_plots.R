f_stat_file = args[1]
ped_file = args[2]
plot_filename = args[3]

f_stats <- read.delim(f_stat_file, sep="\t", header=T)
ped <- read.delim(ped_file, sep="\t", header=F)
plink.sexcheck <- merge(f_stats, ped, by.x="INDV", by.y="V2")
plink.sexcheck$gender<-NA
plink.sexcheck[plink.sexcheck$V5==1,"gender"] <- "male"
plink.sexcheck[plink.sexcheck$V5==2,"gender"] <- "female"
pdf(file=plot_filename, height=5, width=7)
densityplot( ~F|gender, data=plink.sexcheck, groups=gender,
    scales=list(alternating=1),
    main="Plink F stat: X chromosome inbreeding (homozygosity) estimate",
    xlab="Plink male call at F > 0.7; female call at F < 0.35",
    panel=function(...){
        panel.abline( v=0.03, lty=2, lwt=0.5 )
        lrect( xleft=-100, ybottom=-100, xright=0.35, ytop=100, 
               col="#FFC6FF", density=5, angle=45, lty=2, lwt=0.5)
        lrect( xleft=0.7, ybottom=-100, xright=100, ytop=100, 
               col="#C4C4FF", density=5, angle=45, lty=2, lwt=0.5)
        panel.densityplot(...)
    }
)
dev.off()