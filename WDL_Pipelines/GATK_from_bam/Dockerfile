FROM google/cloud-sdk
MAINTAINER DFCI-CCCB <deconti@jimmy.harvard.edu>

# Use when google moves image to alpine linux
#RUN apk add --update python python-dev py-pip build-base
RUN apt-get -y update && apt-get install -y build-essential python python-pip
RUN pip install pyyaml
RUN mkdir /usr/bin_dir/
COPY from_bam_submission.py /usr/bin_dir/
COPY config /usr/bin_dir/
RUN chmod 755 /usr/bin_dir/from_bam_submission.py
#COPY default.yaml /usr/bin_dir/
ENV PATH $PATH:/usr/bin_dir/
WORKDIR /usr/workdir
# Try making from_bam_submission the default process for this docker
#CMD ["python from_bam_submission.py"]