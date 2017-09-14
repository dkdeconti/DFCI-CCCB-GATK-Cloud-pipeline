for i in {a..b}; do
    sed "s/VCF_INJECTION/sorted_vcfs.${i}.txt/g" inputs.merge.template.json | \
    sed "s/INDEX_INJECTION/sorted_vcfs.indices.${i}.txt/g" | \
    sed "s/NAME_INJECTION/cohort.${i}.g.vcf/g" > inputs.merge.json;
    gcloud alpha genomics pipelines run \
    --pipeline-file default.yaml \
    --zones us-east1-b \
    --logging gs://dfci-cccb-lp-06092017-1322/logging \
    --inputs-from-file WDL=Merge_VCFs.wdl \
    --inputs-from-file WORKFLOW_INPUTS=inputs.merge.json \
    --inputs-from-file WORKFLOW_OPTIONS=default.options.json \
    --inputs WORKSPACE=gs://dfci-cccb-lp-06092017-1322/workspace \
    --inputs OUTPUTS=gs://dfci-cccb-lp-06092017-1322/outputs/merged_gvcfs \
    --labels lp-06092017-1322=genotyping,william-crowley=lp-06092017-1322 \
    --memory 4;
done;