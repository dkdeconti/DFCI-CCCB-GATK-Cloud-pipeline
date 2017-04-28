gcloud alpha genomics pipelines run \
--pipeline-file gs://dfci-cccb-pipeline-testing/default_templates/GATK_variant_discovery_from_BAM/default.yaml \
--zones us-east1-b \
--logging dfci-fake-test/logging \
--inputs WDL=gs://dfci-cccb-pipeline-testing/default_templates/GATK_variant_discovery_from_BAM/GATK_variant_calling.from_bam.wdl  \
--inputs WORKFLOW_INPUTS=a.WwEId7RNqE.inputs.json \
--inputs WORKFLOW_OPTIONS=gs://dfci-cccb-pipeline-testing/default_templates/GATK_variant_discovery_from_BAM/default.options.json \
--inputs WORKSPACE=dfci-fake-test/workspace \
--inputs OUTPUTS=dfci-fake-test/outputs