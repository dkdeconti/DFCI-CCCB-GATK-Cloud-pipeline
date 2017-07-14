##############################################################################
# Workflow Definition
##############################################################################

workflow GenotypeAndQC {
    File input_bams_vcfs_file
    File input_genotyped_vcf
    Array[Array[File]] input_bams_vcfs = read_tsv(input_bams_vcfs_file)
    String output_basename
    File ped
    
    File ref_fasta
    File ref_fasta_index
    File ref_dict

    File probe_intervals

    scatter (bams_vcfs in input_bams_vcfs) {
        File input_bam = bams_vcfs[0]
        File input_bam_index = bams_vcfs[1]
        File input_vcf = bams_vcfs[2]
        String vbd_output_basename = bams_vcfs[3]
    
        #call VerifyBamID {
        #    input:
        #        input_vcf = input_vcf,
        #        input_bam = input_bam,
        #        input_bam_index = input_bam_index,
        #        output_basename = vbd_output_basename
        #}
        call DepthOfCoverage {
            input:
                input_bam = input_bam,
                input_bam_index = input_bam_index,
                probe_intervals = probe_intervals,
                output_basename = vbd_output_basename
        }
    }
    #call MergeVerifyBamID {
    #    input:
    #        inputs_selfsm = VerifyBamID.output_selfsm,
    #        output_basename = output_basename
    #}
    call XChromosomeFStat {
        input:
            genotyped_vcf = input_genotyped_vcf
    }
    call PlotFStat {
        input:
            f_stats = XChromosomeFStat.f_stats,
            ped = ped
    }
    call PlotDepthOfCoverage {
        input:
            input_beds = DepthOfCoverage.coverage_bed
    }
    output {
        PlotDepthOfCoverage.sample_statistics
        PlotDepthOfCoverage.sample_summary
        PlotDepthOfCoverage.depth_histogram
        PlotDepthOfCoverage.depth_boxplot
        PlotFStat.f_stats_plot
        #MergeVerifyBamID.output_vbd
    }
}

##############################################################################
# Task Definitions
##############################################################################

task VerifyBamID {
    File input_vcf
    File input_bam
    File input_bam_index
    String output_basename

    command {
        ~/bin/verifyBamID \
            --vcf ${input_vcf} \
            --bam ${input_bam} \
            --maxDepth1000 \
            --precise \
            --verbose \
            --out ${output_basename}
    }
    output {
        File output_selfrg = "${output_basename}.selfRG"
        File output_selfsm = "${output_basename}.selfSM"
        File output_bestrg = "${output_basename}.bestRG"
        File output_bestsm = "${output_basename}.bestSM"
        File output_depthrg = "${output_basename}.depthRG"
        File output_depthsm = "${output_basename}.depthSM"
    }
}

task MergeVerifyBamID {
    Array[File] inputs_selfsm
    String output_basename

    command{
        cat ${sep=" " inputs_selfsm} > ${output_basename}.selfSM
    }
    output {
        File output_vbd = "${output_basename}.selfSM"
    }
}

task DepthOfCoverage {
    File input_bam
    File input_bam_index
    File probe_intervals
    String output_basename

    command {
        ~/bin/bedtools coverage \
        -abam ${input_bam} \
        -b ${probe_intervals} \
        -hist | \
        grep "^all" > ${output_basename}.coverage.all_only.bed
    }
    output {
        File coverage_bed = "${output_basename}.coverage.all_only.bed"
    }
}

task PlotDepthOfCoverage {
    Array[File] input_beds

    command {
        python ~/scratch/QC_test/convert_bedtools_hist_to_GATK_DoC.py \
        ${sep=' ' input_beds}
        Rscript ~/scratch/QC_test/create_coverage_heatmap.R \
        coverage.sample_statistics coverage.sample_summary
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
        ~/bin/vcftools --het --chr chrX --vcf ${genotyped_vcf} --out f_stat
    }
    output {
        File f_stats = "f_stat.het"
    }
}

task PlotFStat {
    File f_stats
    File ped

    command {
        Rscript ~/scratch/QC_test/create_f_stat_plots.R \
        ${f_stats} ${ped} f_stat.density_plot.pdf
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
        Rscript ~/scratch/QC_test/create_ibd_plots.R ibs_autosome.genome ibd.density_plots.pdf
    }
    output {
        File ibs_autosome_genome = "ibs_autosome.genome"
        File ibd_density_plots = "ibd.density_plots.pdf"
    }
}