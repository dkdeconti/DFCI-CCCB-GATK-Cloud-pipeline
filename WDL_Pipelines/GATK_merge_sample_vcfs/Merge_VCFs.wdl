##############################################################################
# Workflow Definition
##############################################################################

workflow MergeVCFs {
    # Fix it to single file at a time
    File input_vcf_array_file
    File input_vcf_index_array_file
    File scattered_calling_intervals_list_file
    Array[File] input_vcf_array = read_lines(input_vcf_array_file)
    Array[File] input_vcf_index_array = read_lines(input_vcf_index_array_file)
    Array[File] scattered_calling_intervals = read_lines(scattered_calling_intervals_list_file)
    String output_vcf_basename
        
    File ref_fasta
    File ref_fasta_index
    File ref_dict

    # Recommended sizes:
    # small_disk = 200
    # medium_disk = 300
    # large_disk = 400
    Int small_disk

    scatter (scatter_interval in scattered_calling_intervals) {
        call GATKMergeVCFs {
            input:
                input_vcfs = input_vcf_array,
                input_indices = input_vcf_index_array,
                interval_list = scatter_interval,
                output_basename = output_vcf_basename,
                ref_fasta = ref_fasta,
                ref_fasta_index = ref_fasta_index,
                ref_dict = ref_dict,
                disk_size = small_disk
        }
    }
    call CatVCFs {
        input:
            input_vcfs = GATKMergeVCFs.merged_gvcf,
            input_indices = GATKMergeVCFs.merged_gvcf_index,
            output_basename = output_vcf_basename,
            ref_dict = ref_dict,
            ref_fasta = ref_fasta,
            ref_fasta_index = ref_fasta_index,
            disk_size = small_disk,
            preemptible_tries = preemptible_tries
    }
    output {
        CatVCFs.output_vcf
        CatVCFs.output_index
    }
}

##############################################################################
# Task Definitions
##############################################################################

task GATKMergeVCFs {
    Array[File] input_vcfs
    Array[File] input_indices
    File interval_list
    String output_basename

    File ref_fasta
    File ref_fasta_index
    File ref_dict

    Int disk_size

    command {
        java -Xmx12000M -jar /usr/bin_dir/GATK.jar \
            -T CombineGVCFs \
            -R ${ref_fasta} \
            --variant ${sep=" --variant" input_vcfs} \
            -L ${interval_list} \
            -o ${output_basename}.pre_merge.g.vcf
    }
    runtime {
        docker: "gcr.io/exome-pipeline-project/basic-seq-tools"
        memory: "14 GB"
        cpu: "2"
        disks: "local-disk " + disk_size + " HDD"
    }
    output {
        File merged_gvcf = "${output_basename}"
        File merged_gvcf_index = "${output_basename}.idx"
    }
}

task CatVCFs {
    Array[File] input_vcfs
    Array[File] input_indices
    String output_basename
    File ref_dict
    File ref_fasta
    File ref_fasta_index
    Int disk_size
    Int preemptible_tries

    command {
        java -Xmx3000m -cp /usr/bin_dir/GATK.jar \
            org.broadinstitute.gatk.tools.CatVariants \
            -R ${ref_fasta} \
            -V ${sep=' -V ' input_vcfs} \
            -out ${output_basename}.g.vcf \
            --assumeSorted
    }
    runtime {
        docker: "gcr.io/exome-pipeline-project/basic-seq-tools"
        memory: "4 GB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File output_vcf = "${output_basename}.g.vcf"
        File output_index = "${output_basename}.g.vcf.idx"
    }
}
