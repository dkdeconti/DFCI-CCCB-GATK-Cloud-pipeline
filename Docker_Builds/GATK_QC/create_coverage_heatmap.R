library(gplots)

coverage_file = args[1]
coverage_summary_file = args[2]

sample.stats <- read.delim(coverage_file)
rownames(sample.stats)<-sample.stats$Source_of_reads
sample.stats <- sample.stats[,-1]
sample.stats <- as.matrix(sample.stats)
 
sample.stats[sample.stats==0] <- 1
sample.stats.log10 <- log10(sample.stats)
 
 
pdf(file="depth_histogram.pdf", height=20, width=20)
sample.stats.hist <- heatmap.2(
    sample.stats.log10,
    Rowv=TRUE,
    Colv=FALSE,
    dendrogram="row",
    symm=FALSE,
    trace="none",
    keysize = 0.75,
    cexRow=0.35,
    cexCol=0.2,
    xlab="Sequencing Depth Bins (1-500)",
    main="Depth of Sequencing Histograms (log10), within Genes of Interest"
)
dev.off()

df <- read.delim(coverage_summary_file)
df <- subset(df, sample_id != "Total")
df <- subset(df, mean < 500)

pdf(file="depth_boxplot.pdf", height=5, width=5)
boxplot(df$mean,
    las=1,
    ylab="Depth",
    main="Mean sequencing depth (mean < 500)"
)
dev.off()