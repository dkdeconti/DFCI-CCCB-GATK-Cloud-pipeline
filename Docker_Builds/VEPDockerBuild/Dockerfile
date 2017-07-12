FROM willmclaren/ensembl-vep
MAINTAINER DFCI-CCCB <deconti@jimmy.harvard.edu>
# Maintainer has a re-write of VEP that is mostly feature complete

# Sets up VEP for GRCH
# Installs plugins for Loftee into VEP
RUN mkdir /home/vep/.vep && mkdir /home/vep/.vep/Plugins
RUN wget -O /home/vep/src/ensembl-vep/v0.3-beta.tar.gz https://github.com/konradjk/loftee/archive/v0.3-beta.tar.gz
RUN tar xzvf v0.3-beta.tar.gz -C /home/vep/src/ensembl-vep/
RUN perl /home/vep/src/ensembl-vep/INSTALL.pl -a c -s homo_sapiens --ASSEMBLY GRCh37
#RUN perl /home/vep/src/ensembl-vep/INSTALL.pl -a c -s mus_musculus
RUN ln -s /home/vep/src/ensembl-vep/loftee-0.3-beta/LoF.pm /home/vep/.vep/Plugins/LoF.pm
RUN ln -s /home/vep/src/ensembl-vep/loftee-0.3-beta/splice_module.pl /home/vep/.vep/Plugins/splice_module.pl

WORKDIR /usr/workdir

ENTRYPOINT ["/home/vep/src/ensembl-vep/vep"]