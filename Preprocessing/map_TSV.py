#!/usr/bin/python

import sys
from collections import defaultdict


def read_tsv_as_array(filename):
    tsv_array = []
    with open(filename, 'rU') as handle:
        for line in handle:
            arow = line.strip('\n').split('\t')
            tsv_array.append(arow)
    return tsv_array


def map_array_to_dict(tsv_array):
    mapped_tsv = defaultdict(list)
    for k,v in tsv_array:
        mapped_tsv[k].append(v)
    return mapped_tsv


def create_mapped_files(mapped_tsv):
    for k,v in mapped_tsv.items():
        write_list(k + ".list", v)


def write_list(filename, list_text):
    with open(filename, 'w') as handle:
        for str in list_text:
            handle.write(str + '\n')


def main(sa):
    inputs_tsv_filename = sa[0]
    mapped_tsv = map_array_to_dict(read_tsv_as_array(inputs_tsv_filename))
    create_mapped_files(mapped_tsv)


if __name__ == "__main__":
    main(sys.argv[1:])
