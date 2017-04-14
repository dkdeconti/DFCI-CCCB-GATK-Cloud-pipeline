FROM ubuntu:16.04
MAINTAINER DFCI-CCCB <deconti@jimmy.harvard.edu>

RUN mkdir /usr/bin_dir/
RUN apt-get -y update && apt-get install -y build-essential python git gcc g++ zlib1g-dev wget curl
RUN wget -O /usr/bin_dir/v0.19.1.tar.gz https://github.com/arq5x/gemini/archive/v0.19.1.tar.gz
RUN tar xzvf /usr/bin_dir/v0.19.1.tar.gz -C /usr/bin_dir/
RUN python /usr/bin_dir/gemini-0.19.1/gemini/scripts/gemini_install.py --nodata  /usr/bin_dir/gemini-0.19.1 /usr/bin_dir/gemini-0.19.1
ENV PATH $PATH:/usr/bin_dir/gemini-0.19.1/bin
#RUN python /usr/bin_dir/gemini-0.19.1/gemini/install-data.py /usr/bin-dir/gemini-0.19.1/
#RUN gemini update --dataonly --extra cadd_score
#RUN gemini update --dataonly --extra gerp_bp