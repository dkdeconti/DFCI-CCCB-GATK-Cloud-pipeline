workflow RealignBam {
    #String bin_dir

    File inputsTSV
    Array[Array[File]] inputs_array = read_tsv(inputsTSV)

    File ref_fasta
    File ref_fasta_index
    File ref_dict
    File ref_bwt
    File ref_sa
    File ref_amb
    File ref_ann
    File ref_pac

    String bwa_commandline="bwa mem -p -v 3 -t 3 $bash_ref_fasta"

    call GetBwaVersion

    scatter (inputs in inputs_array) {
        #File input_bam = inputs[0]
        #String output_bam_basename = inputs[1]

        call RemoveNonProperPairs {
            input:
                input_bam = inputs[0],
                output_bam_basename = inputs[1]
        }
        call UnmapBam {
            input:
                input_bam = RemoveNonProperPairs.properpairs_bam,
                output_bam_basename = inputs[1]
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
                ref_sa = ref_sa
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
        docker: "basic-seq-tools"
        memory: "1 GB"
    }
    output {
        String version = read_string(stdout())
    }
}

task RemoveNonProperPairs {
    File input_bam
    String output_bam_basename

    command {
        samtools view -f 2 -b \
        -o ${output_bam_basename}.proper-pairs.bam \
        ${input_bam}
    }
    runtime {
        docker: "basic-seq-tools"
        memory: "2 GB"
        cpu: "1"
    }
    output {
        File properpairs_bam = "${output_bam_basename}.proper-pairs.bam"
    }
}

task UnmapBam {
    File input_bam
    String output_bam_basename

    command {
        java -Xmx2500m -jar /usr/workdir/picard.jar \
            RevertSam \
            I=${input_bam} \
            O=${output_bam_basename}.proper-pairs.unmapped.bam
    }
    runtime {
        docker: "basic-seq-tools"
        memory: "3 GB"
        cpu: "2"
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

    command <<<
        # set the bash variable needed for the command-line
        # initialized in workflow, but invoked here
        bash_ref_fasta=${ref_fasta}
        # May have a problem with picard here...
        java -Xmx2500m -jar /usr/workdir/picard.jar \
            SamToFastq \
            INPUT=${input_bam} \
            FASTQ=/dev/stdout \
            INTERLEAVE=true \
            NON_PF=true | \
        ${bwa_commandline} - 2> >(tee ${output_bam_basename}.realn.bwa.stderr.log >&2) > ${output_bam_basename}.realn.sam
        #samtools view -b ${output_bam_basename}.realn.sam \
        #> ${output_bam_basename}.realn.bam
        java -Xmx2500m -jar /usr/workdir/picard.jar \
            SamFormatConverter \
            I=${output_bam_basename}.realn.sam \
            O=${output_bam_basename}.realn.bam
    >>>
    runtime {
        docker: "basic-seq-tools"
        memory: "6 GB"
        cpu: "3"
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

    command {
        java -Xmx2500m -jar /usr/workdir/picard.jar \
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
        docker: "basic-seq-tools"
        memory: "3 GB"
        cpu: "4"
    }
    output {
        File output_bam = "${output_bam_basename}.realn.info.bam"
    }
}





