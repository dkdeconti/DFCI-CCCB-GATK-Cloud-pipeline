##############################################################################
# Workflow Definition
##############################################################################

workflow GenotyepAndQC {
    File input_vcfs_file
    String output_basename
    
    File ref_fasta
    File ref_fasta_index
    File ref_dict
    File dbsnp
    File dbsnp_index
    File omni
    File omni_index
    File thousand_genomes
    File thousand_genomes_index
    File hapmap
    File hapmap_index
    File mills
    File mills_index

    File scattered_calling_intervals_list_file
    Array[File] scattered_calling_intervals = read_lines(scattered_calling_intervals_list_file)

    # Recommended sizes:
    # small_disk = 200
    # medium_disk = 300
    # large_disk = 400
    # preemptible_tries = 3
    Int small_disk
    Int medium_disk
    Int large_disk
    Int preemptible_tries

    scatter (scatter_interval in scattered_calling_intervals) {
        call GenotypeGVCFs {
            input:
                input_vcfs = input_vcfs,
                interval_list = scatter_interval,
                output_basename = output_basename,
                ref_dict = ref_dict,
                ref_fasta = ref_fasta,
                ref_fasta_index = ref_fasta_index,
                disk_size = medium_disk,
                preemptible_tries = preemptible_tries
        }
    }
    call MergeGenotypedVCF {
        input:
            input_vcfs = GenotypeGVCFs.output_genotyped_vcf,
            output_vcf_name = output_basename,
            ref_dict = ref_dict,
            ref_fasta = ref_fasta,
            ref_fasta_index = ref_fasta_index,
            disk_size = small_disk,
            preemptible_tries = preemptible_tries
    }
    call VQSR {
        input:
            input_vcf = MergeGenotypedVCF.output_vcf,
            output_vcf_name = output_basename,
            ref_dict = ref_dict,
            ref_fasta = ref_fasta,
            ref_fasta_index = ref_fasta_index,
            hapmap = hapmap,
            hapmap_index = hapmap_index,
            omni = omni,
            omni_index = omni_index,
            thousand_genomes = thousand_genomes,
            thousand_genomes_index = thousand_genomes_index,
            dbsnp = dbsnp,
            dbsnp_index = dbsnp_index,
            mills = mills,
            mills_index = mills_index,
            disk_size = medium_disk,
            preemptible_tries = preemptible_tries
    }
    output {
        MergeGenotypedVCF.output_vcf
        VQSR.output_vcf
    }
}

##############################################################################
# Task Definitions
##############################################################################

task GenotypeGVCFs {
    Array[File] input_vcfs
    File interval_list
    String output_basename
    File ref_dict
    File ref_fasta
    File ref_fasta_index
    Int disk_size
    Int preemptible_tries

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
        preemptible: preemptible_tries
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
    Int preemptible_tries

    command {
        java -Xmx3000m -cp /usr/bin_dir/GATK.jar \
            org.broadinstitute.gatk.tools.CatVariants \
            -R ${ref_fasta} \
            -V ${sep=' -V ' input_vcfs} \
            -out ${output_vcf_name}.gt.g.vcf \
            --assumeSorted
    }
    runtime {
        docker: "gcr.io/exome-pipeline-project/basic-seq-tools"
        memory: "4 GB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File output_vcf = "${output_vcf_name}.g.vcf"
    }
}

task VQSR {
    File input_vcf
    String output_vcf_name
    File ref_dict
    File ref_fasta
    File ref_fasta_index
    File hapmap
    File hapmap_index
    File omni
    File omni_index
    File thousand_genomes
    File thousand_genomes_index
    File dbsnp
    File dbsnp_index
    File mills
    File mills_index

    Int disk_size
    Int preemptible_tries

    command {
        java -Xmx6000m -jar /usr/bin_dir/GATK.jar \
            -T VariantRecalibrator \
            -R ${ref_fasta} \
            -input ${input_vcf} \
            -resource:hapmap,known=false,training=true,truth=true,prior=15.0 ${hapmap} \
            -resource:omni,known=false,training=true,truth=true,prior=12.0 ${omni} \
            -resource:1000G,known=false,training=true,truth=false,prior=10.0 ${thousand_genomes} \
            -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 ${dbsnp} \
            -an DP \
            -an QD \
            -an FS \
            -an SOR \
            -an MQ \
            -an MQRankSum \
            -an ReadPosRankSum \
            -an InbreedingCoeff \
            -mode SNP \
            -tranche 100.0 -tranche 99.9 -tranche 99.0 -tranche 90.0 \
            -recalFile recalibrate_SNP.recal \
            -tranchesFile recalibrate_SNP.tranches \
            -rscriptFile recalibrate_SNP_plots.R
        java -Xmx6000m /usr/bin_dir/GATK.jar \
            -T ApplyRecalibration \
            -R ${ref_fasta} \
            -input ${input_vcf} \
            -mode SNP \
            --ts_filter_level 99.0 \
            -recalFile recalibrate_SNP.recal \
            -tranchesFile recalibrate_SNP.tranches \
            -o recalibrated_snps_raw_indels.vcf
        java -Xmx6000m /usr/bin_dir/GATK.jar \
            -T VariantRecalibrator \
            -input recalibrated_snps_raw_indels.vcf \
            -resource:mills,known=true,training=true,truth=true,prior=12.0 ${mills} \
            -an QD \
            -an DP \
            -an FS \
            -an SOR \
            -an MQRankSum \
            -an ReadPosRankSum \
            -an InbreedingCoeff \
            -mode INDEL \
            -tranche 100.0 -tranche 99.9 -tranche 99.0 -tranche 90.0 \
            --maxGaussians 4 \
            -recalFile recalibrate_INDEL.recal \
            -tranchesFile recalibrate_INDEL.tranches \
            -rscriptFile recalibrate_INDEL_plots.R
        java -Xmx6000m -jar /usr/bin_dir/GATK.jar \
            -T ApplyRecalibration \
            -R ${ref_fasta} \
            -input recalibrated_snps_raw_indels.vcf \
            -mode INDEL \
            --ts_filter_level 99.0 \
            -recalFile recalibrate_INDEL.recal \
            -tranchesFile recalibrate_INDEL.tranches \
            -o ${output_vcf_name}.vqsr.gt.g.vcf
    }
    runtime {
        docker: "gcr.io/exome-pipeline-project/basic-seq-tools"
        memory: "8000 MB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File output_vcf = "${output_vcf_name}.vqsr.gt.g.vcf"
    }
}
