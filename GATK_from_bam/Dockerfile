FROM ubuntu:16.04
MAINTAINER DFCI-CCCB <deconti@jimmy.harvard.edu>

RUN mkdir /usr/bin_dir/
COPY from_bam_submission.py /usr/bin_dir/
RUN chmod 755 /usr/bin_dir/from_bam_submission.py
#COPY default.yaml /usr/bin_dir/
RUN apt-get -y update && apt-get install -y build-essential python
ENV PATH $PATH:/usr/bin_dir/
WORKDIR /usr/workdir