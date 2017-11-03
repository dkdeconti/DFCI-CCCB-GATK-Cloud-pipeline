##############################################################################
# Workflow Definition
##############################################################################

workflow GenotypeAndQC {
    File input_vcfs_file
    Array[File] input_vcfs = read_lines(input_vcfs_file)
    String output_basename
    
    File ref_fasta
    File ref_fasta_index
    File ref_dict

    File scattered_calling_intervals_list_file
    Array[File] scattered_calling_intervals = read_lines(scattered_calling_intervals_list_file)

    # Recommended sizes:
    # small_disk = 200
    # medium_disk = 300
    # large_disk = 400
    Int small_disk
    Int medium_disk
    Int large_disk

    scatter (input_vcf in input_vcfs) {
        #call SortVCF {
        #    input:
        #        input_vcf = input_vcf,
        #        ref_fasta = ref_fasta,
        #        ref_fasta_index = ref_fasta_index,
        #        ref_dict = ref_dict,
        #        disk_size = small_disk
        #}
        call IndexVCF {
            input:
                input_vcf = input_vcf,
                ref_fasta = ref_fasta,
                ref_fasta_index = ref_fasta_index,
                ref_dict = ref_dict,
                disk_size = small_disk
        }
    }
    scatter (scatter_interval in scattered_calling_intervals) {
        call GenotypeGVCFs {
            input:
                input_vcfs = input_vcfs,
                input_vcf_indices = IndexVCF.output_vcf_index,
                interval_list = scatter_interval,
                output_basename = output_basename,
                ref_dict = ref_dict,
                ref_fasta = ref_fasta,
                ref_fasta_index = ref_fasta_index,
                disk_size = large_disk
        }
    }
    call MergeGenotypedVCF {
        input:
            input_vcfs = GenotypeGVCFs.output_genotyped_vcf,
            output_vcf_name = output_basename,
            ref_dict = ref_dict,
            ref_fasta = ref_fasta,
            ref_fasta_index = ref_fasta_index,
            disk_size = large_disk,
    }
    output {
        MergeGenotypedVCF.output_vcf
    }
}

##############################################################################
# Task Definitions
##############################################################################

task SortVCF {
    File input_vcf
    File ref_fasta
    File ref_fasta_index
    File ref_dict

    Int disk_size

    command {
        java -Xmx8000m -jar /usr/bin_dir/picard.jar \
            I=${input_vcf}
            O=${input_vcf}.sorted.g.vcf
    }
    runtime {
        docker: "gcr.io/exome-pipeline-project/basic-seq-tools"
        memory: "10 GB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
    }
    output {
        File output_sorted_vcf = "${input_vcf}.sorted.g.vcf"
    }
}

task IndexVCF {
    File input_vcf
    File ref_fasta
    File ref_fasta_index
    File ref_dict

    Int disk_size

    command {
        java -Xmx8000m -jar /usr/bin_dir/GATK.jar \
            -T ValidateVariants \
            -R ${ref_fasta} \
            -V ${input_vcf} \
            --validationTypeToExclude ALL
    }
    runtime {
        docker: "gcr.io/exome-pipeline-project/basic-seq-tools"
        memory: "10 GB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
    }
    output {
        File output_vcf_index = "${input_vcf}.idx"
    }
}

task GenotypeGVCFs {
    Array[File] input_vcfs
    Array[File] input_vcfs_indices
    File interval_list
    String output_basename
    File ref_dict
    File ref_fasta
    File ref_fasta_index
    Int disk_size

    command {
        java -Xmx8000m -jar /usr/bin_dir/GATK.jar \
            -T GenotypeGVCFs \
            -R ${ref_fasta} \
            -L ${interval_list} \
            --variant ${sep=' --variant ' input_vcfs} \
            -o ${output_basename}.gt.g.vcf
    }
    runtime {
        docker: "gcr.io/exome-pipeline-project/basic-seq-tools"
        memory: "10 GB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
    }
    output {
        File output_genotyped_vcf = "${output_basename}.gt.g.vcf"
    }
}

task MergeGenotypedVCF {
    Array[File] input_vcfs
    String output_vcf_name
    File ref_fasta
    File ref_fasta_index
    File ref_dict

    Int disk_size

    command {
        #java -Xmx8000m -jar /usr/bin_dir/picard.jar \
        #    I=${sep=' I=' input_vcfs} \
        #    O=${output_vcf_name}.g.vcf;
        #java -Xmx3000m -cp /usr/bin_dir/GATK.jar \
        #    org.broadinstitute.gatk.tools.CatVariants \
        #    -R ${ref_fasta} \
        #    -V ${sep=' -V ' input_vcfs} \
        #    -out ${output_vcf_name}.gt.g.vcf \
        #    --assumeSorted
        java -Xmx3000m -jar /usr/bin_dir/picard.jar \
            INPUT=${sep=' INPUT=' input_vcfs} \
            OUTPUT=${output_vcf_name}.gt.g.vcf
    }
    runtime {
        docker: "gcr.io/exome-pipeline-project/basic-seq-tools"
        memory: "4 GB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
    }
    output {
        File output_vcf = "${output_vcf_name}.g.vcf"
    }
}
