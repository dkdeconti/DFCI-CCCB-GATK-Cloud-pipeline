#!/usr/bin/python

import sys
from collections import defaultdict


def read_tsv_as_array(filename):
    '''
    Converts 2 column tsv to array.
    First column is samplename.
    Second column is location of file.
    '''
    tsv_array = []
    with open(filename, 'rU') as handle:
        for line in handle:
            arow = line.strip('\n').split('\t')
            tsv_array.append(arow)
    return tsv_array


def map_array_to_dict(tsv_array):
    '''
    Converts array of paired samplename and file to dict.
    Sample name is key.
    '''
    mapped_tsv = defaultdict(list)
    for key, value in tsv_array:
        mapped_tsv[key].append(value)
    return mapped_tsv


def create_mapped_files(mapped_tsv):
    '''
    Creates file listing files from key.
    Creates a mapped file to stdout.
    '''
    for key, value in mapped_tsv.items():
        write_list(key + ".list", value)
        sys.stdout.write('\t'.join([key, key+".list"]) + '\n')


def write_list(filename, list_text):
    '''
    Writes file with listed files.
    key (samplename) is filename + ".list", .list passed
    '''
    with open(filename, 'w') as handle:
        for out_str in list_text:
            handle.write(out_str + '\n')


def main(sa):
    '''
    Parses CLI input
    '''
    inputs_tsv_filename = sa[0]
    mapped_tsv = map_array_to_dict(read_tsv_as_array(inputs_tsv_filename))
    create_mapped_files(mapped_tsv)


if __name__ == "__main__":
    main(sys.argv[1:])
