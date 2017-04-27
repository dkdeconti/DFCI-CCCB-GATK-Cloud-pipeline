##############################################################################
# Workflow Definition
##############################################################################

workflow VariantMergeAnnotateAndGemini {
    File input_vcf_list
    Array[File] input_vcfs = read_lines(input_vcf_list)
    String output_basename
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

    # Recommended sizes:
    # small_disk = 500
    # medium_disk = 800
    # large_disk = 1000
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
                gvcf_name = output_basename,
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
            input_vcf = MergeGenotypedVCF.output_vcf
    }

}

##############################################################################
# Task Definitions
##############################################################################

task GenotypeGVCFs {
    Array[File] input_vcfs
    File interval_list
    String output_vcf_name
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
            --variant ${sep=' --variant=' input_vcfs} \
            -o ${output_vcf_name}.gt.g.vcf
    }
    runtime {
        docker: "gcr.io/dfci-cccb/basic-seq-tools"
        memory: "10 GB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File output_genotyped_vcf = "${output_vcf_name}.gt.g.vcf"
    }
}

task MergeGenotypedVCF {
    Array[File] input_vcfs
    String output_vcf_name

    command {
        java -Xmx3000m -cp /usr/bin_dir/GATK.jar \
            org.broadinstitute.gatk.tools.CatVariants \
            -R ${ref_fasta} \
            -V ${sep=' -V ' input_vcfs} \
            -out ${output_vcf_name}.gt.g.vcf \
            --assumeSorted
    }
    runtime {
        docker: "gcr.io/dfci-cccb/basic-seq-tools"
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
        docker: "gcr.io/dfci-cccb/basic-seq-tools"
        memory: "8000 MB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File output_vcf = "${output_vcf_name}.vqsr.gt.g.vcf"
    }
}

task DecomposeAndNormalizeGVCF {
    File input_vcf
    String output_vcf_name
    File ref_fasta
    File ref_fasta_index

    Int disk_size
    Int preemptible_tries

    command {
        sed 's/ID=AD,Number=./ID=AD,Number=R/' ${input_vcf} \
        | vt decompose -s - \
        | vt normalize -r ${ref_fasta} - > \
        ${output_vcf_name}.dn.vqsr.gt.g.vcf
    }
    runtime {
        docker: "gcr.io/dfci-cccb/basic-seq-tools"
        memory: "3500 MB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File output_vcf = "${output_vcf_name}.dn.vqsr.gt.g.vcf"
    }
}

task VEPAnnotate {
    File input_vcf
    String output_vcf_name
    File exac_syn
    File exac_mis
    File exac_lof

    Int disk_size
    Int preemptible_tries

    command {
        /home/vep/src/ensembl-vep/vep \
            --cache \
            --dir /home/vep/src/ensembl-vep/.vep \
            --species homo_sapiens \
            --stats_file vcf_stats.vep.htm \
            --offline \
            --everything \
            --fork 15 \
            --vcf \
            --input_file ${input_vcf} \
            --output_file ${output_vcf_name}.vep.dn.vqsr.gt.g.vcf \
            --plugin LoF \
            --custom ${exac_syn},syn_z,bed,overlap,0 \
            --custom ${exac_mis},mis_z,bed,overlap,0 \
            --custom ${exac_lof},lof_z,bed,overlap,0
    }
    runtime {
        docker: "gcr.io/dfci-cccb/vep"
        memory: "3500 MB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File output_vcf = "${output_vcf_name}.vep.dn.vqsr.gt.g.vcf"
    }
}

task LoadGeminiDB {
    File input_vcf
    File ped
    String output_basename

    command {
        gemini load -p ${ped} -t VEP -v ${input_vcf} ${output_basename}.db
    }
    runtime {
        docker: "gcr.io/dfci-cccb/basic-seq-tools"
        memory: "3500 MB"
        cpu: "1"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible_tries
    }
    output {
        File output_db = "${output_basename}.db"
    }
}