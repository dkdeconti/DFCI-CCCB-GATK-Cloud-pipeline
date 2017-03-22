##############################################################################
# Workflow Definition
##############################################################################

workflow VariantMergeAnnotateAndGemini {
    File input_vcf_list
    Array[File] input_vcfs = read_lines(input_vcf_list)
    String output_basename
    Array[File] scattered_calling_intervals = read_lines(scattered_calling_intervals_list_file)

    File ref_fasta
    File ref_fasta_index
    File ref_dict
    File ref_bwt
    File ref_sa
    File ref_amb
    File ref_ann
    File ref_pac
    File dbsnp
    File dbsnp_index
    File known_indels
    File known_indels_index

    # Recommended sizes:
    # small_disk = 200
    # medium_disk = 300
    # large_disk = 400
    # preemptible_tries = 3
    Int small_disk
    Int medium_disk
    Int large_disk
    Int preemptible_tries

    scatter (scatter_interval in scattered_calling_intervals) {
        call GenotypeGVCFs {
            input:
                input_vcfs = input_vcfs,
                interval_list = scatter_interval,
                gvcf_name = output_basename,
                ref_dict = ref_dict,
                ref_fasta = ref_fasta,
                ref_fasta_index = ref_fasta_index,
                disk_size = small_disk,
                preemptible_tries = preemptible_tries
        }
    }
    call MergeGenotypedVCF {
        input:
    }
    call VQSR {
        input:
    }

}

##############################################################################
# Task Definitions
##############################################################################

task GenotypeGVCFs {
    Array[File] input_vcfs
    File interval_list
    String output_vcf_name
    File ref_dict
    File ref_fasta
    File ref_fasta_index
    Int disk_size
    Int preemptible_tries

    command {
        java -Xmx 8000m -jar /usr/bin_dir/GATK.jar \
            -T GenotypeGVCFs \
            -R ${ref_fasta} \
            -L ${interval_list} \
            --variant ${sep=' --variant=' input_vcfs} \
            -o ${output_vcf_name}.gt.g.vcf
    }
    runtime {
        docker: "gcr.io/dfci-cccb/basic-seq-tools"
        memory: "10 GB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File output_genotyped_vcf = "${output_vcf_name}.gt.g.vcf"
    }
}

task MergeGenotypedVCF {
    Array[File] genotyped_vcfs

    command {

    }
    runtime {

    }
    output {

    }
}