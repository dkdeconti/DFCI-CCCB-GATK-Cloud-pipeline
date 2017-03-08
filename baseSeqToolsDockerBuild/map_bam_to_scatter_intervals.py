#! /usr/bin/python
'''
Parses BQSR bam files to split against scatter intervals for HaplotypeCaller.
'''

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


def map_bam_to_scatters(bam_list, scatter_list, index_list):
    '''
    Maps bam_list to scatter_list.
    '''
    return (dict.fromkeys(bam_list, scatter_list),
            dict.fromkeys(bam_list, index_list))


def write_map_to_tsv(map_dict):
    '''
    Writes map_dict as TSV to bam_scatter_for_HaplotypeCaller.tsv.
    '''
    with open("bam_scatter_for_HaplotypeCaller.tsv", 'w') as handle:
        for bam, scatter_list in map_dict.items():
            for i, scatter in enumerate(scatter_list):
                vcf_name = '.'.join([bam.strip('.bam'), str(i), 'g.vcf'])
                outstr = ''.join([str(bam), 
                                  '\t', 
                                  str(scatter), 
                                  '\n'])
                handle.write(outstr)


def main(args):
    '''
    Parses CLI args.
    '''
    bamlist_filename = args[0]
    scatterintervals_filename = args[1]
    indices_filename = args[2]
    bamlist = read_filelist(bamlist_filename)
    scatterlist = read_filelist(scatterintervals_filename)
    indexlist = read_filelist(indices_filename)
    map_scatter_dict, map_index_dict = map_bam_to_scatters(bamlist, 
                                                           scatterlist,
                                                           indexlist)
    write_map_to_tsv(map_scatter_dict)


if __name__ == "__main__":
    main(sys.argv[1:])
