##############################################################################
# Workflow Definition
##############################################################################

workflow GenotyepAndQC {
    File input_bams
    File input_vcfs
    File input_bams_vcfs_file
    Array[Array[File]] input_bams_vcfs = read_tsv(input_bams_vcfs_file)
    String output_basename
    File ped
    
    File ref_fasta
    File ref_fasta_index
    File ref_dict
    #File dbsnp
    #File dbsnp_index
    #File omni
    #File omni_index
    #File thousand_genomes
    #File thousand_genomes_index
    #File hapmap
    #File hapmap_index
    #File mills
    #File mills_index

    File probe_intervals
    File scattered_calling_intervals_list_file
    Array[File] scattered_calling_intervals = read_lines(scattered_calling_intervals_list_file)

    scatter (scatter_interval in scattered_calling_intervals) {
        call GenotypeGVCFs {
            input:
                input_vcfs = input_vcfs,
                interval_list = scatter_interval,
                output_basename = output_basename,
                ref_dict = ref_dict,
                ref_fasta = ref_fasta,
                ref_fasta_index = ref_fasta_index#,
                #disk_size = medium_disk,
                #preemptible_tries = preemptible_tries
        }
    }
    call MergeGenotypedVCF {
        input:
            input_vcfs = GenotypeGVCFs.output_genotyped_vcf,
            output_vcf_name = output_basename,
            ref_dict = ref_dict,
            ref_fasta = ref_fasta,
            ref_fasta_index = ref_fasta_index#,
            #disk_size = small_disk,
            #preemptible_tries = preemptible_tries
    }
    #call VQSR {
    #    input:
    #        input_vcf = MergeGenotypedVCF.output_vcf,
    #        output_vcf_name = output_basename,
    #        ref_dict = ref_dict,
    #        ref_fasta = ref_fasta,
    #        ref_fasta_index = ref_fasta_index,
    #        hapmap = hapmap,
    #        hapmap_index = hapmap_index,
    #        omni = omni,
    #        omni_index = omni_index,
    #        thousand_genomes = thousand_genomes,
    #        thousand_genomes_index = thousand_genomes_index,
    #        dbsnp = dbsnp,
    #        dbsnp_index = dbsnp_index,
    #        mills = mills,
    #        mills_index = mills_index
    #}
    scatter (bams_vcfs in input_bams_vcfs) {
        File input_bam = bams_vcfs[0]
        File input_vcf = bams_vcfs[1]
        String vbd_output_basename = bams_vcfs[2]

        call VerifyBamID {
            input:
                input_vcf = input_vcf,
                input_bam = input_bam,
                output_basename = vbd_output_basename
        }
    }
    call MergeVerifyBamID {
        input:
            inputs_foo = VerifyBamID.output_stuff
    }
    call XChromosomeFStat {
        input:
            genotyped_vcf = MergeGenotypedVCF.output_vcf
    }
    call PlotFStat {
        input:
            f_stats = XChromosomeFStat.f_stats,
            ped = ped
    }
    scatter (bam in input_bams) {
        call DepthOfCoverage {
            input:
                bam = bam,
                probe_intervals = probe_intervals,
                output_basename = output_basename
        }
    }
    call PlotDepthOfCoverage {
        input:
            input_beds = DepthOfCoverage.coverage_bed
    }
    output {
        MergeGenotypedVCF.output_vcf
        PlotDepthOfCoverage.sample_statistics
        PlotDepthOfCoverage.sample_summary
        PlotDepthOfCoverage.depth_histogram
        PlotDepthOfCoverage.depth_boxplot
        PlotFStat.f_stats_plot
    }
}

##############################################################################
# Task Definitions
##############################################################################

task GenotypeGVCFs {
    Array[File] input_vcfs
    File interval_list
    String output_basename
    File ref_dict
    File ref_fasta
    File ref_fasta_index
    #Int disk_size
    #Int preemptible_tries

    command {
        #java -Xmx8000m -jar /usr/bin_dir/GATK.jar \
        ~/binjava -Xmx3000m -jar ~/bin/gatk.jar \
            -T GenotypeGVCFs \
            -R ${ref_fasta} \
            -L ${interval_list} \
            --variant ${sep=' --variant=' input_vcfs} \
            -o ${output_basename}.gt.g.vcf
    }
    #runtime {
    #    docker: "gcr.io/exome-pipeline-project/basic-seq-tools"
    #    memory: "10 GB"
    #    cpu: "1"
    #    disks: "local-disk " + disk_size + " HDD"
    #    preemptible: preemptible_tries
    #}
    output {
        File output_genotyped_vcf = "${output_basename}.gt.g.vcf"
    }
}

task MergeGenotypedVCF {
    Array[File] input_vcfs
    String output_vcf_name
    File ref_fasta
    File ref_fasta_index
    File ref_dict

    command {
        #java -Xmx3000m -cp /usr/bin_dir/GATK.jar \
        ~/bin/java -Xmx2000m -cp ~/bin/gatk.jar \
            org.broadinstitute.gatk.tools.CatVariants \
            -R ${ref_fasta} \
            -V ${sep=' -V ' input_vcfs} \
            -out ${output_vcf_name}.gt.g.vcf \
            --assumeSorted
    }
    #runtime {
    #    docker: "gcr.io/exome-pipeline-project/basic-seq-tools"
    #    memory: "4 GB"
    #    cpu: "1"
    #    disks: "local-disk " + disk_size + " HDD"
    #    preemptible: preemptible_tries
    #}
    output {
        File output_vcf = "${output_vcf_name}.g.vcf"
    }
}

task VQSR {
    File input_vcf
    String output_vcf_name
    File ref_dict
    File ref_fasta
    File ref_fasta_index
    File hapmap
    File hapmap_index
    File omni
    File omni_index
    File thousand_genomes
    File thousand_genomes_index
    File dbsnp
    File dbsnp_index
    File mills
    File mills_index

    Int disk_size
    Int preemptible_tries

    command {
        java -Xmx6000m -jar /usr/bin_dir/GATK.jar \
            -T VariantRecalibrator \
            -R ${ref_fasta} \
            -input ${input_vcf} \
            -resource:hapmap,known=false,training=true,truth=true,prior=15.0 ${hapmap} \
            -resource:omni,known=false,training=true,truth=true,prior=12.0 ${omni} \
            -resource:1000G,known=false,training=true,truth=false,prior=10.0 ${thousand_genomes} \
            -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 ${dbsnp} \
            -an DP \
            -an QD \
            -an FS \
            -an SOR \
            -an MQ \
            -an MQRankSum \
            -an ReadPosRankSum \
            -an InbreedingCoeff \
            -mode SNP \
            -tranche 100.0 -tranche 99.9 -tranche 99.0 -tranche 90.0 \
            -recalFile recalibrate_SNP.recal \
            -tranchesFile recalibrate_SNP.tranches \
            -rscriptFile recalibrate_SNP_plots.R
        java -Xmx6000m /usr/bin_dir/GATK.jar \
            -T ApplyRecalibration \
            -R ${ref_fasta} \
            -input ${input_vcf} \
            -mode SNP \
            --ts_filter_level 99.0 \
            -recalFile recalibrate_SNP.recal \
            -tranchesFile recalibrate_SNP.tranches \
            -o recalibrated_snps_raw_indels.vcf
        java -Xmx6000m /usr/bin_dir/GATK.jar \
            -T VariantRecalibrator \
            -input recalibrated_snps_raw_indels.vcf \
            -resource:mills,known=true,training=true,truth=true,prior=12.0 ${mills} \
            -an QD \
            -an DP \
            -an FS \
            -an SOR \
            -an MQRankSum \
            -an ReadPosRankSum \
            -an InbreedingCoeff \
            -mode INDEL \
            -tranche 100.0 -tranche 99.9 -tranche 99.0 -tranche 90.0 \
            --maxGaussians 4 \
            -recalFile recalibrate_INDEL.recal \
            -tranchesFile recalibrate_INDEL.tranches \
            -rscriptFile recalibrate_INDEL_plots.R
        java -Xmx6000m -jar /usr/bin_dir/GATK.jar \
            -T ApplyRecalibration \
            -R ${ref_fasta} \
            -input recalibrated_snps_raw_indels.vcf \
            -mode INDEL \
            --ts_filter_level 99.0 \
            -recalFile recalibrate_INDEL.recal \
            -tranchesFile recalibrate_INDEL.tranches \
            -o ${output_vcf_name}.vqsr.gt.g.vcf
    }
    #runtime {
    #    docker: "gcr.io/exome-pipeline-project/basic-seq-tools"
    #    memory: "8000 MB"
    #    cpu: "1"
    #    disks: "local-disk " + disk_size + " HDD"
    #    preemptible: preemptible_tries
    #}
    output {
        File output_vcf = "${output_vcf_name}.vqsr.gt.g.vcf"
    }
}

task VerifyBamID {
    File input_vcf
    File input_bam
    String output_basename

    command {
        verifyBamID \
            --vcf ${input_vcf} \
            --bam ${input_bam} \
            --maxDepth1000 \
            --precise \
            --verbose \
            --out ${output_basename}
    }
    output {
        File output_stuff = "${output_basename}"
    }
}

task MergeVerifyBamID {
    Array[File] inputs_foo

    command{
        cat ${sep=" " inputs_foo} > output.vbd.txt
    }
    output {
        File output_vbd = "output.vbd.txt"
    }
}

task DepthOfCoverage {
    File bam
    File probe_intervals
    String output_basename

    command {
        ~/bin/bedtools coverage -abam ${bam} -b ${probe_intervals} -hist > ${output_basename}.coverage.bed
        grep "^all" ${output_basename}.coverage.bed > ${output_basename}.coverage.all_only.bed
    }
    output {
        File coverage_bed = "${output_basename}.coverage.all_only.bed"
    }
}

task PlotDepthOfCoverage {
    Array[File] input_beds

    command {
        python convert_bedtools_hist_to_GATK_DoC.py ${sep=' ' input_beds}
        Rscript create_coverage_heatmap.R coverage.sample_statistics coverage.sample_summary
    }
    output {
        File sample_statistics = "coverage.sample_statistics"
        File sample_summary = "coverage.sample_summary"
        File depth_histogram = "depth_histogram.pdf"
        File depth_boxplot = "depth_boxplot.pdf"
    }
}

task XChromosomeFStat {
    File genotyped_vcf

    command {
        ~/bin/vcftools --het --chr chrX --vcf ${genotyped_vcf} --out f_stat.het
    }
    output {
        File f_stats = "f_stat.het"
    }
}

task PlotFStat {
    File f_stats
    File ped

    command {
        Rscript create_f_stat_plots.R ${f_stats} ${ped} f_stat.density_plot.pdf
    }
    output {
        File f_stats_plot = "f_stat.density_plot.pdf"
    }
}

task IdentityByDescent {
    File genotyped_vcf

    command {
        vcftools \
            --vcf ${genotyped_vcf} \
            --plink-tped \
            --not-chr chrX \
            --not-chr chrY \
            --out ${genotyped_vcf}.prelim.gt
        plink \
            --tfile ${genotyped_vcf}.prelim.gt \
            --indep-pairwise 50 5 .3 \
            --out ${genotyped_vcf}.prelim.gt
        plink \
            --tfile ${genotyped_vcf}.prelim.gt \
            --extract ${genotyped_vcf}.prelim.gt.prune.in \
            --genome \
            --out ibs_autosome;
        Rscript create_ibd_plots.R ibs_autosome.genome ibd.density_plots.pdf
    }
    output {
        File ibs_autosome_genome = "ibs_autosome.genome"
        File ibd_density_plots = "ibd.density_plots.pdf"
    }
}