##############################################################################
# Workflow Definition
##############################################################################

workflow HaplotypeCaller {
    File input_bam
    File ref_fasta
    File ref_fasta_index
    File ref_dict
    File Intervals
    File scattered_calling_intervals
    #Array[File] scattered_calling_intervals
    #why array? should I make this an array?

    scatter (subInterval in scattered_calling_intervals) {
        call HaplotypeCaller {

        }
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
            -o ${gvcf_basename}.vcf.gz \
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
        File output_gvcf = "${gvcf_basename}.vcf.gz"
        File output_gvcf_index = "${gvcf_basename}.vcf.gz.tbi"
    }
}