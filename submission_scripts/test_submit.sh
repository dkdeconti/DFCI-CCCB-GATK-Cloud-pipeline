# Set the PATH to the location of the WDL files
GATK_GOOGLE_DIR="dfci-testgenomes"
# Call the pipeline with "gcloud alpha genomics pipelines"
gcloud alpha genomics pipelines run \
  --pipeline-file wdl_pipeline.yaml \
  --zones us-east1-b \
  --logging gs://dfci-testgenomes/logging \
  --inputs-from-file WDL=RealignBam.cloud.wdl \
  --inputs-from-file WORKFLOW_INPUTS=RealignBam.cloud.inputs.json \
  --inputs-from-file WORKFLOW_OPTIONS=RealignBam.cloud.options.json \
  --inputs WORKSPACE=gs://dfci-testgenomes/workspace \
  --inputs OUTPUTS=gs://dfci-testgenomes/outputs

# Call pipeline without options files
gcloud alpha genomics pipelines run \
  --pipeline-file wdl_pipeline.yaml \
  --zones us-east1-b \
  --logging gs://dfci-testgenomes/logging \
  --inputs-from-file WDL=RealignBam.cloud.wdl \
  --inputs-from-file WORKFLOW_INPUTS=RealignBam.cloud.inputs.json \
  --inputs WORKSPACE=gs://dfci-testgenomes/workspace \
  --inputs OUTPUTS=gs://dfci-testgenomes/outputs

# --inputs-from-file WORKFLOW_OPTIONS=RealignBam.cloud.options.json \

# Output to track the pipeline
Running [operations/ELK9zOyjKxjrsaHo2pLUiXUggJ2TgoYcKg9wcm9kdWN0aW9uUXVldWU].

# Check the status of the pipeline
gcloud alpha genomics operations describe operation-id \
    --format='yaml(done, error, metadata.events)'
    