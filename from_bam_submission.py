import argparse
from string import Template


def submit_variant_calling(sample_name, bam_file, bucket, template_json):
    '''
    Submission script for individual bam.
    '''
    d = {"BUCKET_INJECTION": bucket,
         "BAM_INJECTION": bam_file,
         "INPUT_BASENAME_INJECTION": sample_name}
    filein = open(template_json)
    s = Template(filein.read())
    result = s.substitute(d)
    print result


def main():
    '''
    Parses CLI args and setup.
    '''
    parser = argparse.ArgumentParser(description="Cloud VCF pipeline from BAMs")
    parser.add_argument("bamtsv", metavar="BAM_TSV",
                        help="sample name and BAM TSV file")
    parser.add_argument("bucketname", metavar="BucketName",
                        help="google bucket name")
    parser.add_argument("foo", metavar="foo", help="foo")
    parser.set_defaults()
    args = parser.parse_args()
    submit_variant_calling(args.bamtsv, args.foo, args.bucketname, "input_template.json")


if __name__ == "__main__":
    main()
