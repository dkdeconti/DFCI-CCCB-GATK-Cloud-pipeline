'''
Creates a TSV for vcf gather.
'''

from collections import defaultdict
import re
import sys


def read_filelist(filename):
    '''
    Reads filenames from file.
    '''
    filelist = []
    with open(filename, 'rU') as handle:
        for line in handle:
            filelist.append(line.strip('\n'))
    return filelist


def map_vcf_by_basename(file_list):
    '''
    Maps vcfs to keys based on basename.
    '''
    mapped_vcf = defaultdict(list)
    for filename in file_list:
        basename = filename[:filename.rfind('.')]
        basename = basename[:basename.rfind('.')]
        mapped_vcf[basename].append(filename)
    return mapped_vcf


def write_mapped_vcf(mapped_vcf):
    '''
    Writes basename and input commands to TSV from mapped scattered VCF.
    '''
    with open("vcf_map_for_gather.tsv", 'w') as handle:
        for basename, scattered_vcf in mapped_vcf.items():
            cmd = ' '.join([''.join(["INPUT=", vcf]) for vcf in scattered_vcf])
            outstr = '\t'.join([basename, cmd]) + '\n'
            handle.write(outstr)


def main(args):
    '''
    Parse CLI args.
    '''
    vcflist_filename = args[0]
    vcf_list = read_filelist(vcflist_filename)
    map_vcf_by_basename(vcf_list)


if __name__ == "__main__":
    main(sys.argv[1:])
