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

    scatter (inputs in inputs_array) {
        getBWARGValues {
    	    input:
                sample_name = inputs[0],
	    	fastq_name = inputs[1]
    	}
	
    }
}


##############################################################################
# Task Definitions
##############################################################################

task getBWARGValues {
    String sample_name
    File fastq_name
    
    command {
        python /usr/bin_dir/get_RG_vals.py sample_name fastq_name
    }
    
    output {
        String rg_values = read_strin(stdout())
    }
}

task printBWARGValues {
    String rg_values

    command {
        echo "rg_values"
    }
}