FROM broadinstitute/java-baseimage
MAINTAINER DSDE <jangofett@broadinstitute.org>

COPY picard.jar /usr/bin_dir/picard.jar
COPY GenomeAnalysisTK.jar /usr/bin_dir/GATK.jar
COPY map_bam_to_scatter_intervals.py /usr/bin_dir/map_bam_to_scatter_intervals.py
COPY create_vcf_gather_tsv.py /usr/bin_dir/create_vcf_gather_tsv.py

RUN apt-get -y update && apt-get install -y curl samtools bwa

RUN mkdir -p /usr/bin_dir/vt && \
    curl -SL https://github.com/atks/vt/archive/0.5772.tar.gz | \
    tar xzC /usr/bin_dir/vt && \
    make -c /usr/bin_dir/vt 

WORKDIR /usr/workdir

# location:
# us.gcr.io/dfci-cccb/basic-seq-tools
# docker tag basic-seq-tools gcr.io/dfci-cccb/basic-seq-tools
# gcloud docker -- push gcr.io/dfci-cccb/basic-seq-tools