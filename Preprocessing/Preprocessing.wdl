##############################################################################
# Workflow Definition
##############################################################################

# RG info from Broad
# https://software.broadinstitute.org/gatk/guide/article?id=6472

workflow AlignFASTQs {
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

    
}