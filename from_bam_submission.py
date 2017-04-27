import argparse
import random
import string
from string import Template


def create_inputs_json(template_json, bucket, sample_name, bam_file):
    '''
    Injects variables into template json for inputs.
    '''
    bar_code = ''.join(random.SystemRandom().choice(string.ascii_letters +
                                                    string.digits)
                       for _ in range(10))
    inputs_filename = '.'.join([sample_name, bar_code, "inputs.json"])
    d = {"BUCKET_INJECTION": bucket,
         "BAM_INJECTION": bam_file,
         "INPUT_BASENAME_INJECTION": sample_name}
    with open(template_json) as filein: s = Template(filein.read())
    result = s.substitute(d)
    with open(inputs_filename, 'w') as handle:
        handle.write(result)
    return inputs_filename


def submit_variant_calling(sample_name, bam_file, bucket, template_json):
    '''
    Submission script for individual bam.
    '''
    inputs_file = create_inputs_json(template_json, bucket,
                                     sample_name, bam_file)
    with open("") as filein:
        
    return
    

def map_bam_tsv(tsv):
    '''
    Maps sample names to bam files.
    '''
    with open(tsv) as filein:
        return dict(s.split('\t') for s in filein.read().split('\n'))


def main():
    '''
    Parses CLI args and setup.
    '''
    parser = argparse.ArgumentParser(description="Cloud VCF pipeline from BAMs")
    parser.add_argument("bamtsv", metavar="BAM_TSV",
                        help="sample name and BAM TSV file")
    parser.add_argument("bucketname", metavar="BucketName",
                        help="google bucket name")
    parser.add_argument("", metavar="foo", help="foo")
    parser.set_defaults()
    args = parser.parse_args()
    samples = map_bam_tsv(args.bamtsv)
    codes = [submit_variant_calling(sample_name, bam, args.bucketname,
                                    "input_template.json")
             for sample_name, bam in samples.items()]
    print codes


if __name__ == "__main__":
    main()
