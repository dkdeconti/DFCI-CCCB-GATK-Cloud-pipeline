library(lattice)

ibs_file <- args[1]
plot_filename <- args[2]

ibs.genome <- read.table(ibs_file, header=T)
ibd.un <- subset(ibs.genome, ibs.genome$RT == "UN")
ibd.related <- subset(ibs.genome, ibs.genome$RT != "UN")
ibd.high <- subset(ibs.genome, ibs.genome$PI_HAT >=.50)
ibd.maybe <- subset(ibd.high, ibd.high$RT == "UN")
ibd.problems <- setdiff(unique(ibd.maybe$IID1), unique(ibd.related$IID1))
pdf(file=plot_filename, height=5, width=7)
densityplot(ibd.un$PI_HAT)
dev.off()