# Set the PATH to the location of the WDL files
GATK_GOOGLE_DIR="dfci-testgenomes"
# Call the pipeline with "gcloud alpha genomics pipelines"
gcloud alpha genomics pipelines run \
  --pipeline-file wdl_pipeline.yaml \
  --zones us-central1-f \
  --logging gs://${GATK_GOOGLE_DIR}/logging \
  --inputs-from-file WDL=RealignBam.cloud.wdl \
  --inputs-from-file WORKFLOW_INPUTS=RealignBam.cloud.inputs.json \
  --inputs WORKSPACE=gs://${GATK_GOOGLE_DIR}/workspace \
  --inputs OUTPUTS=gs://${GATK_GOOGLE_DIR}/outputs

# Output to track the pipeline
Running [operations/EOWo9f-hKxiMkuvynJO5jlAggJ2TgoYcKg9wcm9kdWN0aW9uUXVldWU].

# Check the status of the pipeline
gcloud alpha genomics operations describe operation-id \
    --format='yaml(done, error, metadata.events)'

# Error from the latest run... Debug.
#gcloud alpha genomics operations describe EOWo9f-hKxiMkuvynJO5jlAggJ2TgoYcKg9wcm9kdWN0aW9uUXVldWU --format='yaml(done, error, metadata.events)'
#done: true
#error:
#  code: 10
#  message: |-
#    11: Docker run failed: command failed: /wdl_runner/wdl_runner.sh: line 28: WORKFLOW_OPTIONS: unbound variable
#    . See logs at gs://dfci-testgenomes/logging
#metadata:
#  events:
#  - description: start
#    startTime: '2017-02-08T23:10:38.187538015Z'
#  - description: pulling-image
#    startTime: '2017-02-08T23:10:38.187595606Z'
#  - description: localizing-files
#    startTime: '2017-02-08T23:11:16.154525474Z'
#  - description: running-docker
#    startTime: '2017-02-08T23:11:16.154553707Z'
#  - description: fail
#    startTime: '2017-02-08T23:11:18.551521317Z'