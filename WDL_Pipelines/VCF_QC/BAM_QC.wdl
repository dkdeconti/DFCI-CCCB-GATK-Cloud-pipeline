##############################################################################
# Workflow Definition
##############################################################################

workflow BamQC {
    File input_bams_file
    Array[Array[String]] input_bams = read_tsv(input_bams_file)
    String output_basename
    
    File ref_fasta
    File ref_fasta_index
    File ref_dict
    File thousand_genomes_vcf

    File probe_intervals
    File probe_intervals_bed

    Int small_disk = 100
    Int medium_disk = 200
    Int large_disk = 400

    scatter (bams_vcfs in input_bams) {
        #File input_bam = bams_vcfs[0]
        #File input_bam_index = bams_vcfs[1]
        #File input_vcf = bams_vcfs[2]
        #File input_vcf_index = bams_vcfs[3]
        #String vbd_output_basename = bams_vcfs[4]
    
        call VerifyBamID {
            input:
                input_vcf = thousand_genomes_vcf,
                input_bam = bams_vcfs[0],
                input_bam_index = bams_vcfs[1],
                output_basename = bams_vcfs[4],
                disk_size = small_disk
        }
        call DepthOfCoverage {
            input:
                input_bam = bams_vcfs[0],
                input_bam_index = bams_vcfs[1],
                output_basename = bams_vcfs[4],
                probe_intervals = probe_intervals_bed,
                disk_size = small_disk
        }
    }
    call MergeVerifyBamID {
        input:
            inputs_selfsm = VerifyBamID.output_selfsm,
            output_basename = output_basename,
            disk_size = small_disk
    }
    call PlotDepthOfCoverage {
        input:
            input_beds = DepthOfCoverage.coverage_bed,
            disk_size = small_disk
    }
    output {
        PlotDepthOfCoverage.sample_statistics
        PlotDepthOfCoverage.sample_summary
        PlotDepthOfCoverage.depth_histogram
        PlotDepthOfCoverage.depth_boxplot
        MergeVerifyBamID.output_vbd
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
    #String output_basename = sub(sub(input_vcf, "gs://dfci-cccb-lp-06092017-1322/sorted_vcfs/", ""), ".sorted.g.vcf", "")

    Int disk_size


    command {
        /usr/bin_dir/verifyBamID \
            --vcf ${input_vcf} \
            --bam ${input_bam} \
            --maxDepth 1000 \
            --precise \
            --verbose \
            --out ${output_basename}
    }
    runtime {
        docker: "gcr.io/exome-pipeline-project/bam-qc"
        cpu: "1"
        memory: "6 GB"
        disks: "local-disk " + disk_size + " HDD"
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

    Int disk_size


    command{
        cat ${sep=" " inputs_selfsm} > ${output_basename}.selfSM
    }
    runtime {
        docker: "gcr.io/exome-pipeline-project/bam-qc"
        cpu: "1"
        memory: "6 GB"
        disks: "local-disk " + disk_size + " HDD"
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
    #String output_basename = sub(sub(input_vcf, "gs://dfci-cccb-lp-06092017-1322/sorted_vcfs/", ""), ".sorted.g.vcf", "")

    Int disk_size


    command {
        /usr/bin_dir/bedtools coverage \
        -abam ${input_bam} \
        -b ${probe_intervals} \
        -hist > ${output_basename}.coverage.bed;
        grep "^all" ${output_basename}.coverge.bed  > ${output_basename}.coverage.all_only.bed;
    }
    runtime {
        docker: "gcr.io/exome-pipeline-project/bam-qc"
        cpu: "1"
        memory: "6 GB"
        disks: "local-disk " + disk_size + " HDD"
    }
    output {
        File coverage_bed = "${output_basename}.coverage.bed"
        File coverage_all_bed = "${output_basename}.coverage.all_only.bed"
    }
}

task PlotDepthOfCoverage {
    Array[File] input_beds

    Int disk_size


    command {
        python /usr/bin_dir/convert_bedtools_hist_to_GATK_DoC.py \
        ${sep=' ' input_beds}
        Rscript /usr/bin_dir/create_coverage_heatmap.R \
        coverage.sample_statistics coverage.sample_summary
    }
    runtime {
        docker: "gcr.io/exome-pipeline-project/bam-qc"
        cpu: "1"
        memory: "4 GB"
        disks: "local-disk " + disk_size + " HDD"
    }
    output {
        File sample_statistics = "coverage.sample_statistics"
        File sample_summary = "coverage.sample_summary"
        File depth_histogram = "depth_histogram.pdf"
        File depth_boxplot = "depth_boxplot.pdf"
    }
}

task PlotVerifyBamID {
    File input_verifybamidoutput

    Int disk_size


    command {
        Rscript /usr/bin_dir/create_verifybamid_plot.R ${input_verifybamidoutput}
    }
    runtime {
        docker: "gcr.io/exome-pipeline-project/bam-qc"
        cpu: "1"
        memory: "4 GB"
        disks: "local-disk " + disk_size + " HDD"
    }
    output {
        File verifyBamID_plot = "verifyBamID_FREEMIX.pdf"
    }
}
