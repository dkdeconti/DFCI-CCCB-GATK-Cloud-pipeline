#!/usr/bin/python

import argparse
import subprocess
import time


def get_non_uploaded(manifest_filename, uploaded):
    '''
    Gets files that aren't uploaded yet.
    '''
    files = []
    with open(manifest_filename, 'rU') as handle:
        for line in handle:
            f = line.strip('\n').split('\t')[0]
            if f not in uploaded:
                files.append(f)
    return files


def upload(files, bucket):
    '''
    Uploads files to Google bucket.
    '''
    cmd = ["gsutil -m cp", files, bucket]
    subprocess.call(cmd, shell=True)


def main():
    # Arg parsing
    desc = "Periodically checks manifest to upload downloaded to google bucket"
    parser = argparse.ArgumentParser(description=desc)
    parser.add_argument("MANIFEST", metavar="MANIFEST",
                        help="Aspera download manifest")
    parser.add_argument("BUCKET", metavar="GOOGLE_BUCKET",
                        help="target Google ")
    parser.add_argument("-t", "--time", metavar="TIME",
                        help="Wait time intervals in minutes [default: 30min]")
    parser.set_defaults(time=30)
    args = parser.parse_args()
    # Work
    uploaded = set([])
    skips = 0
    while True:
        to_upload = get_non_uploaded(args.MANIFEST, uploaded)
        upload(to_upload, args.BUCKET)
        uploaded.update(to_upload)
        time.sleep(args.time * 60)
        if not to_upload:
            skips += 1
        else:
            skips = 0
        if skips > 3:
            break


if __name__ == "__main__":
    main()
