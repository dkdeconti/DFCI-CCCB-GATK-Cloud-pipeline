gcloud alpha genomics pipelines run \
--pipeline-file $YAML_FILE \
--zones us-east1-b \
--logging $BUCKET_INJECTION/logging \
--inputs WDL=$WDL_FILE \
--inputs-from-file WORKFLOW_INPUTS=$INPUTS_FILE \
--inputs WORKFLOW_OPTIONS=$OPTIONS_FILE \
--inputs WORKSPACE=$BUCKET_INJECTION/workspace \
--inputs OUTPUTS=$BUCKET_INJECTION/outputs