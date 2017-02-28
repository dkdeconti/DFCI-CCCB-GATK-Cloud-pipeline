import "subPreprocessing.wdl" as IndividualFastqPreprocess

##############################################################################
# Workflow Definition
##############################################################################

# RG info from Broad
# https://software.broadinstitute.org/gatk/guide/article?id=6472

# Try a JSON read to map
# example:
# Map[String, Array[File]] = read_json(filename)
# not working yet

workflow AlignFASTQs {
    File inputsTSV
    Array[File] tsv_array = read_string()
    Array[Array[File]] inputs_array = read_tsv(inputsTSV)
    Map[String, Array[File]] sample_map = read_json(create_sample_map.inputsJSON)


    File ref_fasta
    File ref_fasta_index
    File ref_dict
    File ref_bwt
    File ref_sa
    File ref_amb
    File ref_ann
    File ref_pac

    String inputsJSON_name
    String bwa_commandline="bwa mem -p -v 3 -t 3 $bash_ref_fasta"

    call create_sample_map {
        inputs:
            inputs_array = inputsTSV,
            inputsJSON_name = inputsJSON_name
    }

    #Map[String, Array[File]] sample_map = read_json(create_sample_map.inputsJSON)


    scatter (String

    scatter (inputs in inputs_array) {
        call getBWARGValues {
    	    input:
                sample_name = inputs[0],
	            fastq_name = inputs[1]
    	}
        call printBWARGValues {
            inputs:
                rg_values = getBWARGValues.rg_values
        }
    }
    call printBWARGValues as printwithin {
        inputs:
            rg_values = getBWARGValues.rg_values
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
        String rg_values = read_string(stdout())
    }
}

task printBWARGValues {
    String rg_values

    command {
        echo "rg_values"
    }
}

task catFastq {
    Array[File] input_fastq
    String output_fastq_name

    command <<<
        cat ${sep=' ' input_fastq} > $output_fastq_name
    >>>
    output {
        File output_fastq = "${output_fastq_name}"
    }
}