FROM broadinstitute/java-baseimage
MAINTAINER DSDE <jangofett@broadinstitute.org>

COPY picard.jar /usr/bin_dir/picard.jar
COPY GenomeAnalysisTK.jar /usr/bin_dir/GenomeAnalysisTK.jar
RUN apt-get -y update && apt-get install -y samtools bwa
WORKDIR /usr/workdir

# location:
# us.gcr.io/dfci-cccb/basic-seq-tools
# docker tag basic-seq-tools us.gcr.io/dfci-cccb/basic-seq-tools
# gcloud docker -- push us.gcr.io/dfci-cccb/basic-seq-tools