#!/usr/bin/python

import argparse
import subprocess
import time


def get_uploaded(manifest_filename):
    '''
    Gets files that aren't uploaded yet.
    '''
    files = []
    with open(manifest_filename, 'rU') as handle:
        for line in handle:
            if not line.strip('\n') or line[0] == "#":
                continue
            file.append(line.strip('\n').split()[0][1:-1])
    return set(files)


def populate_uploaded(log_filename):
    '''
    Parses log file of uploaded files to populate upload.
    '''
    uploaded = []
    with open(log_filename) as handle:
        for line in handle:
            uploaded.append(line.strip('\n'))
    return set(uploaded)


def update_log(uploaded, log_filename):
    '''
    Updates log file of already updated files.
    '''
    with open(log_filename, 'w') as handle:
        for to_up in uploaded:
            handle.write(to_up + '\n')


def upload(files, bucket):
    '''
    Uploads files to Google bucket.
    '''
    cmd = ' '.join(["gsutil -m cp", ' '.join(files), bucket])
    #subprocess.call(cmd, shell=True)


def main():
    '''

    '''
    # Arg parsing
    desc = "Periodically checks manifest to upload downloaded to google bucket"
    parser = argparse.ArgumentParser(description=desc)
    parser.add_argument("MANIFEST", metavar="MANIFEST",
                        help="Aspera download manifest")
    parser.add_argument("BUCKET", metavar="GOOGLE_BUCKET",
                        help="target Google ")
    parser.add_argument("-t", "--time", metavar="TIME",
                        help="Wait time intervals in minutes [default: 30min]")
    parser.add_argument("-l", "-log", metavar="UPLOAD_LOG",
                        help="Log of uploaded files")
    parser.add_argument("-o", "--out", metavar="OUTPUT_LOG",
                        help="output log of uploaded; default=uploaded.log")
    parser.set_defaults(time=30, log=None, out="uploaded.log")
    args = parser.parse_args()
    # Work
    if args.log:
        uploaded = populate_uploaded(populate_uploaded(args.log))
    else:
        uploaded = set([])
    skips = 0
    while True:
        to_upload =
        to_upload = get_uploaded(args.MANIFEST)
        print "to upload:", to_upload
        upload(to_upload, args.BUCKET)
        uploaded.update(to_upload)
        update_log(uploaded, args.out)
        time.sleep(args.time * 60)
        if not to_upload:
            skips += 1
        else:
            skips = 0
        if skips > 3:
            break


if __name__ == "__main__":
    main()
