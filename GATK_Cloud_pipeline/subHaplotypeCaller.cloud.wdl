##############################################################################
# Workflow Definition
##############################################################################

workflow HaplotypeCallerAndGatherVCFs {
    File input_bam
    File input_bam_index

    File ref_fasta
    File ref_fasta_index
    File ref_dict
    
    String gvcf_basename
    String final_gvcf_name = gvcf_basename + ".all.g.vcf"
    
    # Note: Scattered intervals should be non-intersecting
    #       Insure the case with bedtools cluster
    # http://bedtools.readthedocs.io/en/latest/content/tools/cluster.html
    Array[File] scattered_calling_intervals

    scatter (subInterval in scattered_calling_intervals) {
        call HaplotypeCaller {
            input:
                input_bam = input_bam,
                input_bam_index = input_bam_index,
                interval_list = subInterval,
                gvcf_basename = gvcf_basename,
                ref_dict = ref_dict,
                ref_fasta = ref_fasta,
                ref_fasta_index = ref_fasta_index,
                disk_size = small_disk,
                preemptible_tries = preemptible_tries
        }
    }
    
    call GatherVCFs {
        input:
            input_gvcfs = HaplotypeCaller.output_gvcf,
            input_gvcfs_indices = HaplotypeCaller.output_gvcf_index,
            output_gvcf_name = final_gvcf_name,
            disk_size = small_disk,
            preemptible_tries = preemptible_tries
    }
}

##############################################################################
# Task Definitions
##############################################################################

task HaplotypeCaller {
File input_bam
    File input_bam_index
    File interval_list
    String gvcf_basename
    File ref_dict
    File ref_fasta
    File ref_fasta_index
    Int disk_size
    Int preemptible_tries

    command {
        java -Xmx8000m -jar /usr/bin_dir/GATK.jar \
            -T HaplotypeCaller \
            -R ${ref_fasta} \
            -o ${gvcf_basename}.g.vcf \
            -I ${input_bam} \
            -L ${interval_list} \
            -ERC GVCF
    }
    runtime {
        docker: "gcr.io/dfci-cccb/basic-seq-tools"
        memory: "10 GB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File output_gvcf = "${gvcf_basename}.g.vcf"
        File output_gvcf_index = "${gvcf_basename}.vcf.tbi"
    }
}

task GatherVCFs {
    Array[File] input_gvcfs
    Array[File] input_gvcfs_indices
    String output_gvcf_name
    Int disk_size
    Int preemptible_tries

    command {
        java -Xmx2g -jar /usr/bin_dir/picard.jar \
            MergeVcfs \
            INPUT=${sep=' INPUT=' input_gvcfs} \
            OUTPUT=${output_gvcf_name}
    }
    runtime {
        docker: "gcr.io/dfci-cccb/basic-seq-tools"
        memory: "3 GB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File merged_output_gvcf = "${output_gvcf_name}"
        File merged_output_gvcf_index = "${output_gvcf_name}.tbi"
    }
}