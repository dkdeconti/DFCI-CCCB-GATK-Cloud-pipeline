##############################################################################
# Workflow Definition
##############################################################################

workflow RealignAndVariantCalling {
    File input_first_normal_fastq
    File input_second_normal_fastq
    File input_first_tumor_fastq
    File input_second_tumor_fastq
    String output_basename
    File scattered_calling_intervals_list_file
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

    String bwa_commandline="bwa mem -p -v 3 -t 3 $bash_ref_fasta"

    # Recommended sizes:
    # small_disk = 200
    # medium_disk = 300
    # large_disk = 400
    # preemptible_tries = 3
    Int small_disk
    Int medium_disk
    Int large_disk
    Int preemptible_tries

    call GetBwaVersion
    call BwaMem {
        input:
            input_first_normal_fastq = input_first_normal_fastq,
            input_second_normal_fastq = input_second_normal_fastq,
            input_first_tumor_fastq = input_first_tumor_fastq,
            input_second_tumor_fastq = input_second_tumor_fastq,
            output_normal_bam_basename = output_normal_basename,
            output_tumor_bam_basename = output_tumor_basename,
            ref_fasta = ref_fasta,
            ref_fasta_index = ref_fasta_index,
            ref_dict = ref_dict,
            ref_bwt = ref_bwt,
            ref_amb = ref_amb,
            ref_ann = ref_ann,
            ref_pac = ref_pac,
            ref_sa = ref_sa,
            disk_size = large_disk,
            preemptible_tries = preemptible_tries
    }
}

##############################################################################
# Task Definitions
##############################################################################

task GetBwaVersion {
    command {
        bwa 2>&1 | \
        grep -e '^Version' | \
        sed 's/Version: //'
    }
    runtime {
        docker: "gcr.io/exome-pipeline-project/basic-seq-tools"
        memory: "1 GB"
    }
    output {
        String version = read_string(stdout())
    }
}

task BwaMemTumor {
    File input_first_tumor_fastq
    File input_second_tumor_fastq
    File output_tumor_bam_basename

    File ref_fasta
    File ref_fasta_index
    File ref_dict
    File ref_amb
    File ref_ann
    File ref_bwt
    File ref_pac
    File ref_sa

    Int disk_size
    Int preemptible_tries

    command {
        ${bwa_commandline} \
            ${input_first_tumor_fastq} \
            ${input_second_tumor_fastq} \
        2> >(tee ${output_tumor_bam_basename}.bwa.stderr.log >&2) \
        > ${output_tumor_bam_basename}.sam
        java -Xmx2500m -jar /usr/bin_dir/picard.jar \
            SamFormatConverter \
            I=${output_tumor_bam_basename}.sam \
            O=${output_tumor_bam_basename}.bam
    }
    runtime {
        docker: "gcr.io/exome-pipeline-project/basic-seq-tools"
        cpu: "3"
        memory: "14 GB"
        cpu: "16"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File output_bam = "${output_tumor_bam_basename}.bam"
        File bwa_stderr_log = "${output_tumor_bam_basename}.bwa.stderr.log"
    }
}

task BwaMemNormal {
    File input_first_tumor_fastq
    File input_second_tumor_fastq
    File output_tumor_bam_basename

    File ref_fasta
    File ref_fasta_index
    File ref_dict
    File ref_amb
    File ref_ann
    File ref_bwt
    File ref_pac
    File ref_sa

    Int disk_size
    Int preemptible_tries

    command {
        ${bwa_commandline} \
            ${input_first_tumor_fastq} \
            ${input_second_tumor_fastq} \
        2> >(tee ${output_tumor_bam_basename}.bwa.stderr.log >&2) \
        > ${output_tumor_bam_basename}.sam
        java -Xmx2500m -jar /usr/bin_dir/picard.jar \
            SamFormatConverter \
            I=${output_tumor_bam_basename}.sam \
            O=${output_tumor_bam_basename}.bam
    }
    runtime {
        docker: "gcr.io/exome-pipeline-project/basic-seq-tools"
        cpu: "3"
        memory: "14 GB"
        cpu: "16"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File output_bam = "${output_tumor_bam_basename}.bam"
        File bwa_stderr_log = "${output_tumor_bam_basename}.bwa.stderr.log"
    }
}