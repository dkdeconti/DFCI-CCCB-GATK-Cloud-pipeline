gcloud alpha genomics pipelines run \
--pipeline-file /home/deconti/Workspace/DFCI-CCCB-GATK-Cloud-pipeline/GATK_from_bam/default.yaml \
--zones us-east1-b \
--logging gs://dfci-cccb-pipeline-testing/logging \
--inputs-from-file WDL=/home/deconti/Workspace/DFCI-CCCB-GATK-Cloud-pipeline/GATK_from_bam/GATK_variant_calling.from_bam.wdl \
--inputs-from-file WORKFLOW_INPUTS=HG00119.rPpARGXZAl.inputs.json \
--inputs-from-file WORKFLOW_OPTIONS=/home/deconti/Workspace/DFCI-CCCB-GATK-Cloud-pipeline/GATK_from_bam/default.options.json \
--inputs WORKSPACE=gs://dfci-cccb-pipeline-testing/workspace \
--inputs OUTPUTS=gs://dfci-cccb-pipeline-testing/outputs/HG00119-rPpARGXZAl-wdl_output