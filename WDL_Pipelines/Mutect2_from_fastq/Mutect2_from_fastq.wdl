##############################################################################
# Workflow Definition
##############################################################################

workflow RealignAndVariantCalling {
    File input_first_normal_fastq
    File input_second_normal_fastq
    File input_first_tumor_fastq
    File input_second_tumor_fastq
    String input_normal_rgid
    String input_tumor_rgid
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
    File gnomad_vcf

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
    call BwaMemTumor {
        input:
            input_first_tumor_fastq = input_first_tumor_fastq,
            input_second_tumor_fastq = input_second_tumor_fastq,
            input_rgid = input_tumor_rgid,
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
    call BwaMemNormal {
        input:
            input_first_normal_fastq = input_first_normal_fastq,
            input_second_normal_fastq = input_second_normal_fastq,
            input_rgid = input_normal_rgid,
            output_normal_bam_basename = output_normal_basename,
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
    call SortAndFixTagsNormal {
        input:
            input_bam = BwaMemNormal.output_bam,
            output_bam_basename = output_normal_basename,
            ref_dict = ref_dict,
            ref_fasta = ref_fasta,
            ref_fasta_index = ref_fasta_index,
            disk_size = medium_disk,
            preemptible_tries = preemptible_tries
    }
    call SortAndFixTagsTumor {
        input:
            input_bam = BwaMemTumor.output_bam,
            output_bam_basename = output_tumor_basename,
            ref_dict = ref_dict,
            ref_fasta = ref_fasta,
            ref_fasta_index = ref_fasta_index,
            disk_size = medium_disk,
            preemptible_tries = preemptible_tries
    }
    call BaseRecalibratorNormal {
        input:
            input_bam = SortAndFixTagsNormal.output_bam,
            input_bam_index = SortAndFixTagsNormal.output_bam_index,
            recalibration_report_filename = output_normal_basename + ".recal_data.table",
            dbsnp = dbsnp,
            dbsnp_index = dbsnp_index,
            known_indels = known_indels,
            known_indels_index = known_indels_index,
            ref_dict = ref_dict,
            ref_fasta = ref_fasta,
            ref_fasta_index = ref_fasta_index,
            disk_size = small_disk,
            preemptible_tries = preemptible_tries
    }
    call ApplyBQSRNormal {
        input:
            input_bam = SortAndFixTagsNormal.output_bam,
            input_bam_index = SortAndFixTagsNormal.output_bam_index,
            output_bam_basename = output_normal_basename,
            recalibration_report = BaseRecalibratorNormal.recalibration_report,
            ref_dict = ref_dict,
            ref_fasta = ref_fasta,
            ref_fasta_index = ref_fasta_index,
            disk_size = small_disk,
            preemptible_tries = preemptible_tries
    }
    call BaseRecalibratorTumor {
        input:
            input_bam = SortAndFixTagsTumor.output_bam,
            input_bam_index = SortAndFixTagsTumor.output_bam_index,
            recalibration_report_filename = output_tumor_basename + ".recal_data.table",
            dbsnp = dbsnp,
            dbsnp_index = dbsnp_index,
            known_indels = known_indels,
            known_indels_index = known_indels_index,
            ref_dict = ref_dict,
            ref_fasta = ref_fasta,
            ref_fasta_index = ref_fasta_index,
            disk_size = small_disk,
            preemptible_tries = preemptible_tries
    }
    call ApplyBQSRTumor {
        input:
            input_bam = SortAndFixTagsTumor.output_bam,
            input_bam_index = SortAndFixTagsTumor.output_bam_index,
            output_bam_basename = output_tumor_basename,
            recalibration_report = BaseRecalibratorTumor.recalibration_report,
            ref_dict = ref_dict,
            ref_fasta = ref_fasta,
            ref_fasta_index = ref_fasta_index,
            disk_size = small_disk,
            preemptible_tries = preemptible_tries
    }
    scatter (scatter_interval in scattered_calling_intervals) {
        call Mutect2Caller {
            input:
                input_normal_bam = ApplyBQSRNormal.recalibrated_bam,
                input_normal_bam_index = ApplyBQSRNormal.recalibrated_bam_index,
                normal_basename = output_normal_basename,
                input_tumor_bam = ApplyBQSRTumor.recalibrated_bam,
                input_tumor_bam_index = ApplyBQSRTumor.recalibrated_bam_index,
                tumor_basename = output_tumor_basename,
                interval_list = scatter_interval,
                gnomad_vcf = gnomad_vcf,
                vcf_name = output_basename,
                ref_dict = ref_dict,
                ref_fasta = ref_fasta,
                ref_fasta_index = ref_fasta_index,
                disk_size = small_disk
        }
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
    String input_rgid

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
            -R '${input_rgid}' \
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
    File input_first_normal_fastq
    File input_second_normal_fastq
    File output_normal_bam_basename
    String input_rgid

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
            -R '${input_rgid}' \
            ${input_first_normal_fastq} \
            ${input_second_normal_fastq} \
        2> >(tee ${output_normal_bam_basename}.bwa.stderr.log >&2) \
        > ${output_normal_bam_basename}.sam
        java -Xmx2500m -jar /usr/bin_dir/picard.jar \
            SamFormatConverter \
            I=${output_normal_bam_basename}.sam \
            O=${output_normal_bam_basename}.bam
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
        File output_bam = "${output_normal_bam_basename}.bam"
        File bwa_stderr_log = "${output_normal_bam_basename}.bwa.stderr.log"
    }
}

task SortAndFixTagsNormal {
    File input_bam
    String output_bam_basename
    File ref_dict
    File ref_fasta
    File ref_fasta_index

    Int disk_size
    Int preemptible_tries

    command {
        java -Xmx8000m -jar /usr/bin_dir/picard.jar \
            SortSam \
            INPUT=${input_bam} \
            OUTPUT=/dev/stdout \
            SORT_ORDER="coordinate" \
            CREATE_INDEX=false \
            CREATE_MD5_FILE=false | \
        java -Xmx1000m -jar /usr/bin_dir/picard.jar \
            SetNmAndUqTags \
            INPUT=/dev/stdin \
            OUTPUT=${output_bam_basename}.sorted.bam \
            CREATE_INDEX=true \
            CREATE_MD5_FILE=false \
            REFERENCE_SEQUENCE=${ref_fasta};
    }
    runtime {
        docker: "gcr.io/exome-pipeline-project/basic-seq-tools"
        memory: "10000 MB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File output_bam = "${output_bam_basename}.sorted.bam"
        File output_bam_index = "${output_bam_basename}.sorted.bai"
    }
}

task SortAndFixTagsTumor {
    File input_bam
    String output_bam_basename
    File ref_dict
    File ref_fasta
    File ref_fasta_index

    Int disk_size
    Int preemptible_tries

    command {
        java -Xmx8000m -jar /usr/bin_dir/picard.jar \
            SortSam \
            INPUT=${input_bam} \
            OUTPUT=/dev/stdout \
            SORT_ORDER="coordinate" \
            CREATE_INDEX=false \
            CREATE_MD5_FILE=false | \
        java -Xmx1000m -jar /usr/bin_dir/picard.jar \
            SetNmAndUqTags \
            INPUT=/dev/stdin \
            OUTPUT=${output_bam_basename}.sorted.bam \
            CREATE_INDEX=true \
            CREATE_MD5_FILE=false \
            REFERENCE_SEQUENCE=${ref_fasta};
    }
    runtime {
        docker: "gcr.io/exome-pipeline-project/basic-seq-tools"
        memory: "10000 MB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File output_bam = "${output_bam_basename}.sorted.bam"
        File output_bam_index = "${output_bam_basename}.sorted.bai"
    }
}

task BaseRecalibratorNormal {
    File input_bam
    File input_bam_index
    String recalibration_report_filename
    File dbsnp
    File dbsnp_index
    File known_indels
    File known_indels_index
    File ref_dict
    File ref_fasta
    File ref_fasta_index

    Int disk_size
    Int preemptible_tries

    command {
        java -Xmx4000m -jar /usr/bin_dir/GATK.jar \
            -T BaseRecalibrator \
            -R ${ref_fasta} \
            -I ${input_bam} \
            -o ${recalibration_report_filename} \
            -knownSites ${dbsnp} \
            -knownSites ${known_indels}
    }
    runtime {
        docker: "gcr.io/exome-pipeline-project/basic-seq-tools"
        memory: "5000 MB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File recalibration_report = "${recalibration_report_filename}"
    }
}

task BaseRecalibratorTumor {
    File input_bam
    File input_bam_index
    String recalibration_report_filename
    File dbsnp
    File dbsnp_index
    File known_indels
    File known_indels_index
    File ref_dict
    File ref_fasta
    File ref_fasta_index

    Int disk_size
    Int preemptible_tries

    command {
        java -Xmx4000m -jar /usr/bin_dir/GATK.jar \
            -T BaseRecalibrator \
            -R ${ref_fasta} \
            -I ${input_bam} \
            -o ${recalibration_report_filename} \
            -knownSites ${dbsnp} \
            -knownSites ${known_indels}
    }
    runtime {
        docker: "gcr.io/exome-pipeline-project/basic-seq-tools"
        memory: "5000 MB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File recalibration_report = "${recalibration_report_filename}"
    }
}

task ApplyBQSRNormal {
    File input_bam
    File input_bam_index
    String output_bam_basename
    File recalibration_report
    File ref_dict
    File ref_fasta
    File ref_fasta_index

    Int disk_size
    Int preemptible_tries

    command {
        java -Xmx2000m -jar /usr/bin_dir/GATK.jar \
            -T PrintReads \
            -R ${ref_fasta} \
            -I ${input_bam} \
            -o ${output_bam_basename}.sorted.bqsr.bam \
            -BQSR ${recalibration_report}
    }
    runtime {
        docker: "gcr.io/exome-pipeline-project/basic-seq-tools"
        memory: "3 GB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File recalibrated_bam = "${output_bam_basename}.sorted.bqsr.bam"
        File recalibrated_bam_index = "${output_bam_basename}.sorted.bqsr.bai"
    }
}

task ApplyBQSRTumor {
    File input_bam
    File input_bam_index
    String output_bam_basename
    File recalibration_report
    File ref_dict
    File ref_fasta
    File ref_fasta_index

    Int disk_size
    Int preemptible_tries

    command {
        java -Xmx2000m -jar /usr/bin_dir/GATK.jar \
            -T PrintReads \
            -R ${ref_fasta} \
            -I ${input_bam} \
            -o ${output_bam_basename}.sorted.bqsr.bam \
            -BQSR ${recalibration_report}
    }
    runtime {
        docker: "gcr.io/exome-pipeline-project/basic-seq-tools"
        memory: "3 GB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File recalibrated_bam = "${output_bam_basename}.sorted.bqsr.bam"
        File recalibrated_bam_index = "${output_bam_basename}.sorted.bqsr.bai"
    }
}

task Mutect2Caller {
    File input_normal_bam
    File input_normal_bam_index
    String normal_basename
    File input_tumor_bam
    File input_tumor_bam_index
    String tumor_basename
    File interval_list
    File gnomad_vcf
    String vcf_name
    
    File ref_dict
    File ref_fasta
    File ref_fasta_index
    
    Int disk_size
    
    command {
        # ToDo Add a panel of normals in the future.
        java -Xmx8000m -jar /usr/bin_dir/gatk4.jar Mutect2 \
            -R ${ref_fasta} \
            -I ${input_tumor_bam} \
            -tumor ${tumor_basename} \
            -I ${input_normal_bam} \
            -normal ${normal_basename} \
            --germline-resource ${gnomad_vcf} \
            -L ${interval_list} \
            -O ${vcf_name}.vcf
    }
    runtime {
        docker: "gcr.io/exome-pipeline-project/basic-seq-tools" # TODO change to gatk4-beta
        memory: "10 GB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File output_vcf = "${vcf_name}.vcf"
    }
}