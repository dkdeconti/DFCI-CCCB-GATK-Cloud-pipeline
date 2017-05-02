gcloud alpha genomics pipelines run \
--pipeline-file default.yaml \
--zones us-east1-b \
--logging gs://dfci-cccb-pipeline-testing/logging \
--inputs WDL=gs://dfci-cccb-pipeline-testing/default_templates/GATK_variant_discovery_from_BAM/GATK_variant_calling.from_bam.wdl \
--inputs-from-file WORKFLOW_INPUTS=HG00096.947j2EFFgr.inputs.json \
--inputs WORKFLOW_OPTIONS=gs://dfci-cccb-pipeline-testing/default_templates/GATK_variant_discovery_from_BAM/default.options.json \
--inputs WORKSPACE=gs://dfci-cccb-pipeline-testing/workspace \
--inputs OUTPUTS=gs://dfci-cccb-pipeline-testing/outputs