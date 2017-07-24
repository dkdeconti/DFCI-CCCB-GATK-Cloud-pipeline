#! /usr/bin/python
'''
Checks a Google genomics pipeline submission and prints status.
'''

import argparse
import subprocess
import yaml


def check_status(code):
    '''
    Checks status with locally installed gsutil (in PATH).
    '''
    script = ' '.join(["gcloud alpha genomics operations describe",
                       code,
                       "--format='yaml(done, error, metadata.events)'"])
    proc = subprocess.Popen(script, shell=True,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    stdout, _ = proc.communicate()
    status = parse_status(stdout)
    print '\t'.join([code] + status)


def parse_status(yaml_status):
    '''
    Pulls completion status from yaml output.
    '''
    status_map = yaml.safe_load(yaml_status)
    done_status = str(status_map["done"])
    try:
        err = status_map["error"]
        return [done_status, "Error"]
    except KeyError:
        return [done_status]


def main():
    '''
    Arg parsing and central dispatch.
    '''
    # Arg parsing
    desc = "Checks Google pipeline job for completion"
    parser = argparse.ArgumentParser(description=desc)
    parser.add_argument("codes", metavar="CODE", nargs='+',
                        help="pipeline code")
    args = parser.parse_args()
    # Central dispatch
    for code in args.codes:
        check_status(code)


if __name__ == "__main__":
    main()
