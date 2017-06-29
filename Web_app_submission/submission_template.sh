gcloud alpha genomics pipelines run \
--pipeline-file $YAML_FILE \
--zones us-east1-b \
--logging $BUCKET_INJECTION/logging \
--inputs-from-file WDL=$WDL_FILE \
--inputs-from-file WORKFLOW_INPUTS=$INPUTS_FILE \
--inputs-from-file WORKFLOW_OPTIONS=$OPTIONS_FILE \
--inputs WORKSPACE=$BUCKET_INJECTION/workspace \
--inputs OUTPUTS=$BUCKET_INJECTION/outputs/$OUTPUT_FOLDER