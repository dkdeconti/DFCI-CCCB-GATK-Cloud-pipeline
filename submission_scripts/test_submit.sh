# Set the PATH to the location of the WDL files
GATK_GOOGLE_DIR="dfci-testgenomes"
# Call the pipeline with "gcloud alpha genomics pipelines"
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
Running [operations/ENTxy6uiKxjbxbKq2Irh0boBIICdk4KGHCoPcHJvZHVjdGlvblF1ZXVl].

# Check the status of the pipeline
gcloud alpha genomics operations describe operation-id \
    --format='yaml(done, error, metadata.events)'
    