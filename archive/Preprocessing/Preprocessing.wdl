import "subPreprocessing.wdl" as subPre

##############################################################################
# Workflow Definition
##############################################################################

# RG info from Broad
# https://software.broadinstitute.org/gatk/guide/article?id=6472

workflow AlignFASTQs {
    File mappedInputsTSV
    Array[Array[String]] mapped_inputs_array = read_tsv(mappedInputsTSV)
    String bwa_commandline="bwa mem -p -v 3 -t 3 $bash_ref_fasta"

    File ref_fasta
    File ref_fasta_index
    File ref_dict
    File ref_bwt
    File ref_sa
    File ref_amb
    File ref_ann
    File ref_pac

    scatter (mapped_inputs in mapped_inputs_array) {
        # Something fishy about this sections
        # NOt working right
        # Figure out the right input type
        Array[File] fastqs_list = read_lines(mapped_inputs[1])

        call subPre.Preprocess {
            input:
                sample_name = mapped_inputs[0],
                fastqs_list = fastq_list,
                bwa_commands = bwa_commandline,
                ref_fasta = ref_fasta,
                ref_fasta_index = ref_fasta_index,
                ref_dict = ref_dict,
                ref_bwt = ref_bwt,
                ref_sa = ref_sa,
                ref_amb = ref_amb,
                ref_ann = ref_ann, 
                ref_pac = ref_pac
        }
    }
}


##############################################################################
# Task Definitions
##############################################################################
