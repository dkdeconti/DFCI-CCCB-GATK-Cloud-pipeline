# inputs file
INPUTS_TSV=$1
GATK_GOOGLE_DIR="dfci-testgenomes"

while read line; do
    cp VariantCalling.cloud.inputs.template.json VariantCalling.cloud.inputs.json
    INPUT=$(echo $line | awk '{ print $1 }')
    SAMPLENAME=$(echo $line | awk '{ print $2 }')
    sed -i "s#BAM_INJECTION#${INPUT}#g" VariantCalling.cloud.inputs.json
    sed -i "s#INPUT_BASENAME_INJECTION#${SAMPLENAME}#g" VariantCalling.cloud.inputs.json
    gcloud alpha genomics pipelines run \
        --pipeline-file wdl_pipeline.yaml \
        --zones us-east1-b \
        --logging gs://dfci-testgenomes/logging \
        --inputs-from-file WDL=VariantCalling.cloud.wdl  \
        --inputs-from-file WORKFLOW_INPUTS=VariantCalling.cloud.inputs.json \
        --inputs-from-file WORKFLOW_OPTIONS=VariantCalling.cloud.options.json \
        --inputs WORKSPACE=gs://dfci-testgenomes/workspace \
        --inputs OUTPUTS=gs://dfci-testgenomes/outputs
done < $INPUTS_TSV