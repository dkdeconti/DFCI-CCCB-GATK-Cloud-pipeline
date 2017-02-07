# Set the PATH to the location of the WDL files
GATK_GOOGLE_DIR=/home/deconti/scratch/FireCloud
# Call the pipeline with "gcloud alpha genomics pipelines"
gcloud alpha genomics pipelines run \
  --pipeline-file wdl_pipeline.yaml \
  --zones us-central1-f \
  --logging gs://my-bucket/my-path/logging \
  --inputs-from-file WDL=${GATK_GOOGLE_DIR}/RealignBam.cloud.wdl \
  --inputs-from-file WORKFLOW_INPUTS=${GATK_GOOGLE_DIR}/RealignBam.cloud.inputs.json \
  --inputs WORKSPACE=gs://dfci-testgenome-workspace/workspace \
  --inputs OUTPUTS=gs://dfci-testgenomes-output/outputs

# Output to track the pipeline
Running [operations/EMnu3dahKxjz8bjVwYTA_jgggJ2TgoYcKg9wcm9kdWN0aW9uUXVldWU].

# Check the status of the pipeline
gcloud alpha genomics operations describe operation-id \
    --format='yaml(done, error, metadata.events)'
