FROM ubuntu:16.04
MAINTAINER DFCI-CCCB <deconti@jimmy.harvard.edu>

RUN mkdir /usr/bin_dir/
RUN apt-get -y update && apt-get install -y build-essential python git gcc g++ zlib1g-dev wget curl

COPY create_verifybamid_plot.R /usr/bin_dir/create_verifybamid_plot.R
COPY create_coverage_heatmap.R /usr/bin_dir/create_coverage_heatmap.R
COPY convert_bedtools_hist_to_GATK_DoC.py /usr/bin_dir/convert_bedtools_hist_to_GATK_DoC.py

RUN wget -O /usr/bin_dir/verifyBamID https://github.com/statgen/verifyBamID/releases/download/v1.1.3/verifyBamID
RUN chmod 755 /usr/bin_dir/verifyBamID
RUN wget -O /usr/bin_dir/bedtools-2.26.0.tar.gz https://github.com/arq5x/bedtools2/releases/download/v2.26.0/bedtools-2.26.0.tar.gz
RUN tar xzvf /usr/bin_dir/bedtools-2.26.0.tar.gz -C /usr/bin_dir/
RUN make -C /usr/bin_dir/bedtools2
RUN ln -s /usr/bin_dir/bedtools2/bin/bedtools /usr/bin_dir/bedtools

WORKDIR /usr/workdir