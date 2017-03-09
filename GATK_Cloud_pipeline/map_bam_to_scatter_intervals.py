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


def map_bam_to_scatters(bam_list, tomap_list):
    '''
    Maps bam_list to scatter_list.
    '''
    return dict.fromkeys(bam_list, tomap_list)


def map_bam_to_indices(bam_list, index_list):
    '''
    Maps bam_list to respective index_list.
    '''
    index_dict = {}
    for idx in index_list:
        k = idx.strip('.bai')
        index_dict[k] = idx
    mapped_index = {}
    for bam in bam_list:
        mapped_index[bam] = index_dict[bam]
    return mapped_index


def write_map_to_tsv(map_dict, mapped_indices):
    '''
    Writes map_dict as TSV to bam_scatter_for_HaplotypeCaller.tsv.
    '''
    with open("bam_scatter_for_HaplotypeCaller.tsv", 'w') as handle:
        for bam, scatter_list in map_dict.items():
            for i, scatter in enumerate(scatter_list):
                idx = mapped_indices[bam]
                vcf_name = '.'.join([bam.strip('.bam'), str(i), 'g.vcf'])
                outstr = ''.join([str(bam), '\t',
                                  str(idx), '\t',
                                  str(scatter), '\t',
                                  vcf_name, '\n'])
                handle.write(outstr)


def main(args):
    '''
    Parses CLI args.
    '''
    # CLI args assignment
    bamlist_filename = args[0]
    indexlist_filename = args[1]
    to_map_filename = args[2]
    # Create lists from the files
    bamlist = read_filelist(bamlist_filename)
    indexlist = read_filelist(indexlist_filename)
    tomaplist = read_filelist(to_map_filename)
    # Create dicts mapping to bam
    map_scatter_dict = map_bam_to_scatters(bamlist, tomaplist)
    mapped_indices = map_bam_to_indices(bamlist, indexlist)
    # Write to TSV the mapping
    write_map_to_tsv(map_scatter_dict, mapped_indices)


if __name__ == "__main__":
    main(sys.argv[1:])
