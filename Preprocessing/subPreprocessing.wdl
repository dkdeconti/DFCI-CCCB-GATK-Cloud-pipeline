##############################################################################
# Workflow Definition
##############################################################################

workflow Preprocess {
    String sample_name
    Array[File] fastqs_list
    String bwa_commands

    File ref_fasta
    File ref_fasta_index
    File ref_dict
    File ref_bwt
    File ref_sa
    File ref_amb
    File ref_ann
    File ref_pac

    scatter (fastq in fastqs_list) {
        call getBWARGValues {
            input:
                sample_name = sample_name,
                fastq = fastq
        }
        call alignFastq {
            input:
                rg = getBWARGValues.rg_values,
                first_fastq = first_fastq,
                second_fastq = second_fastq,
                bwa_commands = bwa_commands,
                ref_fasta = ref_fasta,
                ref_fasta_index = ref_fasta_index,
                ref_dict = ref_dict,
                ref_bwt = ref_bwt,
                ref_amb = ref_amb,
                ref_ann = ref_ann,
                ref_pac = ref_pac,
                ref_sa = ref_sa
        }
    }
    #call mergeFastq {
    #    input:
    #        alignFastq.
    #}
}


##############################################################################
# Task Definitions
##############################################################################

task getBWARGValues {
    String sample_name
    File fastq
    
    command {
        python /home/ddeconti/scratch/test_splitjoin/get_RG_vals.py sample_name fastq
    }
    
    output {
        String rg_values = read_string(stdout())
    }
}

task alignFastq {
    String rg
    String output_bam_basename
    File first_fastq
    File second_fastq
    String bwa_commands

    File ref_fasta
    File ref_fasta_index
    File ref_dict
    File ref_amb
    File ref_ann
    File ref_bwt
    File ref_pac
    File ref_sa

    command {
        bash_ref_fasta=${ref_fasta}
        ${bwa_commands} -R ${rg} $first_fastq $second_fastq > \
        ${output_bam_basename}.sample_name
        java -Xmx2500m -jar /home/ddeconti/bin/picard.jar \
            SamFormatConverter \
            I=${output_bam_basename}.sam \
            O=${output_bam_basename}.bam
    }
    output {
        File output_bam = "${output_bam_basename}.bam"
    }
}