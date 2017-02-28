#! /usr/bin/python

import gzip
import sys


def main(sa):
    sample_name = sa[0]
    filename = sa[1]
    with gzip.open(filename, "rU") as handle:
        line = handle.readline()
        arow = line.strip('\n').split()
        info = arow[0].split(':')
        instrument_id = info[0]
        run_id = info[1]
        flowcell_id = info[2]
        flowcell_lane = info[3]
        index_seq = arow[1].split(':')[3]
    rgid = '.'.join([sample_name, flowcell_id, flowcell_lane])
    rglb = '.'.join([sample_name, run_id])
    rgpu = '.'.join([instrument_id,
                     flowcell_lane,
                     index_seq])
    rgsm = sample_name
    rgcn = "DFCI-CCCB"
    rgpl = "ILLUMINA"
    out = "@RG\\tID:" + rgid + "\\tPL:" + rgpl + "\\tLB:" + \
          rglb + "\\tSM:" + rgsm + "\\tCN:" + rgcn + "\\tPU:" + \
          rgpu
    sys.stdout.write(out)


if __name__ == "__main__":
    main(sys.argv[1:])
