library(lattice)
library(directlabels)

args <- commandArgs(trailingOnly=T)

validate.all <- read.delim(args[1], header=T)
validate.all$center <- NA
 
pdf(file="verifyBamID_FREEMIX.pdf", width=5, height=4)
        densityplot( ~FREEMIX|center, data=validate.all, groups=center,
            scales=list(alternating=1),
            main="verifyBamID FREEMIX output", 
            xlab="FREEMIX: Sequence-only estimate of contamination (0-1)" )
dev.off()