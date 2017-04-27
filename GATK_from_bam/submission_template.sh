gcloud alpha genomics pipelines run \
--pipeline-file $YAML_FILE \
--zones us-east1-b \
--logging gs://$BUCKET_INJECTION/logging \
--inputs-from-file WDL=$WDL_FILE  \
--inputs-from-file WORKFLOW_INPUTS=$INPUTS_FILE \
--inputs-from-file WORKFLOW_OPTIONS=$OPTIONS_FILE \
--inputs WORKSPACE=gs://$BUCKET_INJECTION/workspace \
--inputs OUTPUTS=gs://$BUCKET_INJECTION/outputs