## copyright DFCI CCCB, 2017
##
## 

#import "subHaplotypeCaller.cloud.wdl" as HaplotypeCaller

##############################################################################
# Workflow Definition
##############################################################################

workflow RealignBam {
    #String bin_dir

    File inputsTSV
    File scattered_calling_intervals_list_file
    Array[Array[File]] inputs_array = read_tsv(inputsTSV)
    Array[File] scattered_calling_intervals = read_lines(scattered_calling_intervals_list_file)

    File ref_fasta
    File ref_fasta_index
    File ref_dict
    File ref_bwt
    File ref_sa
    File ref_amb
    File ref_ann
    File ref_pac

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

    scatter (inputs in inputs_array) {
        #File input_bam = inputs[0]
        #String output_bam_basename = inputs[1]

        call RemoveNonProperPairs {
            input:
                input_bam = inputs[0],
                output_bam_basename = inputs[1],
                disk_size = medium_disk,
                preemptible_tries = preemptible_tries
        }
        call UnmapBam {
            input:
                input_bam = RemoveNonProperPairs.properpairs_bam,
                output_bam_basename = inputs[1],
                disk_size = medium_disk,
                preemptible_tries = preemptible_tries
        }
        call SamToFastqAndBwaMem {
            input:
                input_bam = UnmapBam.output_bam,
                bwa_commandline = bwa_commandline,
                output_bam_basename = inputs[1],
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
        call MergeBamAlignment {
            input:
                unmapped_bam = UnmapBam.output_bam,
                bwa_commandline = bwa_commandline,
                bwa_version = GetBwaVersion.version,
                realn_bam = SamToFastqAndBwaMem.output_bam,
                output_bam_basename = inputs[1],
                ref_fasta = ref_fasta,
                ref_fasta_index = ref_fasta_index,
                ref_dict = ref_dict,
                disk_size = large_disk,
                preemptible_tries = preemptible_tries
        }
        call SortAndFixTags {
            input:
                input_bam = MergeBamAlignment.output_bam,
                output_bam_basename = inputs[1],
                ref_dict = ref_dict,
                ref_fasta = ref_fasta,
                ref_fasta_index = ref_fasta_index,
                disk_size = medium_disk,
                preemptible_tries = preemptible_tries
        }
        call BaseRecalibrator {
            input:
                input_bam = SortAndFixTags.output_bam,
                input_bam_index = SortAndFixTags.output_bam_index,
                recalibration_report_filename = inputs[1] + ".recal_data.table",
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
        call ApplyBQSR {
            input:
                input_bam = SortAndFixTags.output_bam,
                input_bam_index = SortAndFixTags.output_bam_index,
                output_bam_basename = inputs[1],
                recalibration_report = BaseRecalibrator.recalibration_report,
                ref_dict = ref_dict,
                ref_fasta = ref_fasta,
                ref_fasta_index = ref_fasta_index,
                disk_size = small_disk,
                preemptible_tries = preemptible_tries
        }
        # to create a nested scatter, use a sub workflow
        # https://github.com/broadinstitute/cromwell
        #call HaplotypeCaller.HaplotypeCallerAndGatherVCFs {
        #    input:
        #        input_bam = ApplyBQSR.recalibrated_bam,
        #        input_bam_index = ApplyBQSR.recalibrated_bam_index,
        #        ref_fasta = ref_fasta,
        #        ref_fasta_index = ref_fasta_index,
        #        ref_dict = ref_dict,
        #        gvcf_basename = inputs[1],
        #        scattered_calling_intervals = scattered_calling_intervals
        #}
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
        docker: "gcr.io/dfci-cccb/basic-seq-tools"
        memory: "1 GB"
    }
    output {
        String version = read_string(stdout())
    }
}

task RemoveNonProperPairs {
    File input_bam
    String output_bam_basename

    Int disk_size
    Int preemptible_tries

    command {
        samtools view -f 2 -b \
        -o ${output_bam_basename}.proper-pairs.bam \
        ${input_bam}
    }
    runtime {
        docker: "gcr.io/dfci-cccb/basic-seq-tools"
        memory: "2 GB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File properpairs_bam = "${output_bam_basename}.proper-pairs.bam"
    }
}

task UnmapBam {
    File input_bam
    String output_bam_basename

    Int disk_size
    Int preemptible_tries

    command {
        java -Xmx2500m -jar /usr/bin_dir/picard.jar \
            RevertSam \
            I=${input_bam} \
            O=${output_bam_basename}.proper-pairs.unmapped.bam
    }
    runtime {
        docker: "gcr.io/dfci-cccb/basic-seq-tools"
        memory: "3 GB"
        cpu: "2"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File output_bam = "${output_bam_basename}.proper-pairs.unmapped.bam"
    }
}

task SamToFastqAndBwaMem {
    File input_bam
    String bwa_commandline
    String output_bam_basename

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

    command <<<
        # set the bash variable needed for the command-line
        # initialized in workflow, but invoked here
        bash_ref_fasta=${ref_fasta}
        # May have a problem with picard here...
        java -Xmx2500m -jar /usr/bin_dir/picard.jar \
            SamToFastq \
            INPUT=${input_bam} \
            FASTQ=/dev/stdout \
            INTERLEAVE=true \
            NON_PF=true | \
        ${bwa_commandline} - \
        2> >(tee ${output_bam_basename}.realn.bwa.stderr.log >&2) \
        > ${output_bam_basename}.realn.sam
        #samtools view -b ${output_bam_basename}.realn.sam \
        #> ${output_bam_basename}.realn.bam
        java -Xmx2500m -jar /usr/bin_dir/picard.jar \
            SamFormatConverter \
            I=${output_bam_basename}.realn.sam \
            O=${output_bam_basename}.realn.bam
    >>>
    runtime {
        docker: "gcr.io/dfci-cccb/basic-seq-tools"
        cpu: "3"
        memory: "14 GB"
        cpu: "16"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File output_bam = "${output_bam_basename}.realn.bam"
        File bwa_stderr_log = "${output_bam_basename}.realn.bwa.stderr.log"
    }
}

task MergeBamAlignment {
    File unmapped_bam
    String bwa_commandline
    String bwa_version
    File realn_bam
    String output_bam_basename
    File ref_fasta
    File ref_fasta_index
    File ref_dict

    Int disk_size
    Int preemptible_tries

    command {
        java -Xmx2500m -jar /usr/bin_dir/picard.jar \
            MergeBamAlignment \
            VALIDATION_STRINGENCY=SILENT \
            EXPECTED_ORIENTATIONS=FR \
            ATTRIBUTES_TO_RETAIN=X0 \
            ALIGNED_BAM=${realn_bam} \
            UNMAPPED_BAM=${unmapped_bam} \
            OUTPUT=${output_bam_basename}.realn.info.bam \
            REFERENCE_SEQUENCE=${ref_fasta} \
            PAIRED_RUN=true \
            SORT_ORDER="unsorted" \
            IS_BISULFITE_SEQUENCE=false \
            ALIGNED_READS_ONLY=false \
            CLIP_ADAPTERS=false \
            MAX_RECORDS_IN_RAM=2000000 \
            ADD_MATE_CIGAR=true \
            MAX_INSERTIONS_OR_DELETIONS=-1 \
            PRIMARY_ALIGNMENT_STRATEGY=MostDistant \
            PROGRAM_RECORD_ID="bwamem" \
            PROGRAM_GROUP_VERSION="${bwa_version}" \
            PROGRAM_GROUP_COMMAND_LINE="${bwa_commandline}" \
            PROGRAM_GROUP_NAME="bwamem" \
            UNMAP_CONTAMINANT_READS=true
    }
    runtime {
        docker: "gcr.io/dfci-cccb/basic-seq-tools"
        memory: "3500 MB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File output_bam = "${output_bam_basename}.realn.info.bam"
    }
}

task SortAndFixTags {
    File input_bam
    String output_bam_basename
    File ref_dict
    File ref_fasta
    File ref_fasta_index

    Int disk_size
    Int preemptible_tries

    command {
        java -Xmx4000m -jar /usr/bin_dir/picard.jar \
            SortSam \
            INPUT=${input_bam} \
            OUTPUT=/dev/stdout \
            SORT_ORDER="coordinate" \
            CREATE_INDEX=false \
            CREATE_MD5_FILE=false | \
        java -Xmx100m -jar /usr/bin_dir/picard.jar \
            SetNmAndUqTags \
            INPUT=/dev/stdin \
            OUTPUT=${output_bam_basename}.realn.sorted.bam \
            CREATE_INDEX=true \
            CREATE_MD5_FILE=false \
            REFERENCE_SEQUENCE=${ref_fasta};
    }
    runtime {
        docker: "gcr.io/dfci-cccb/basic-seq-tools"
        memory: "5000 MB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File output_bam = "${output_bam_basename}.realn.sorted.bam"
        File output_bam_index = "${output_bam_basename}.realn.sorted.bai"
    }
}

task BaseRecalibrator {
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
        docker: "gcr.io/dfci-cccb/basic-seq-tools"
        memory: "5000 MB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File recalibration_report = "${output_bam_basename}.recal_data.table"
    }
}

task ApplyBQSR {
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
            -O ${output_bam_basename}.realn.sorted.bqsr.bam \
            -BQSR ${recalibration_report}
    }
    runtime {
        docker: "gcr.io/dfci-cccb/basic-seq-tools"
        memory: "3 GB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File recalibrated_bam = "${output_bam_basename}.realn.sorted.bqsr.bam"
        File recalibrated_bam_index = "${output_bam_basename}.realn.sorted.bqsr.bai"
    }
}

#task GenotypeGVCFs {
#    Array[File] input_gvcfs
#    String output_genotyped_gvcf_name
#    
#    File ref_dict
#    File ref_fasta
#    File ref_fasta_index
#
#    Int disk_size
#    Int preemptible_tries
#
#    command {
#        java -Xmx
#    }
#}
