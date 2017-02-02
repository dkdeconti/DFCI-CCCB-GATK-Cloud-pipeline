FROM broadinstitute/java-baseimage
MAINTAINER DSDE <jangofett@broadinstitute.org>

COPY picard.jar /usr/workdir/picard.jar
RUN apt-get -y update && apt-get install -y samtools bwa
WORKDIR /usr/workdir