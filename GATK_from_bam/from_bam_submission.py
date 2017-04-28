import argparse
import ConfigParser
import random
import string
import subprocess
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
    with open(inputs_filename, 'w') as fileout: fileout.write(s.substitute(d))
    return inputs_filename


def create_sub_script(sample_name, template_sub, bucket, wdl_file, inputs_file,
                      options_file, yaml_file):
    '''
    Inject variables into template submission script.
    '''
    injects = {"BUCKET_INJECTION": bucket,
               "WDL_FILE": wdl_file,
               "INPUTS_FILE": inputs_file,
               "OPTIONS_FILE": options_file,
               "YAML_FILE": yaml_file}
    with open(template_sub) as filein:
        template_string = Template(filein.read())
    bar_code = ''.join(random.SystemRandom().choice(string.ascii_letters +
                                                    string.digits)
                       for _ in range(10))
    sub_filename = '.'.join([sample_name, bar_code, "submission.sh"])
    with open(sub_filename, 'w') as fileout:
        fileout.write(template_string.substitute(injects))
    return sub_filename


def submit_variant_calling(sample_name, bam_file, bucket, template_json,
                           submission_file, wdl_file, options_file, yaml_file):
    '''
    Submission script for individual bam.
    '''
    inputs_filename = create_inputs_json(template_json, bucket,
                                         sample_name, bam_file)
    sub_script = create_sub_script(sample_name, submission_file, bucket,
                                   wdl_file, inputs_filename, options_file,
                                   yaml_file)
    with open(sub_script) as filein:
        script = filein.read()
    subprocess.Popen(script, shell=True)
    # do something about retrieving the stdout
    #with open(sub_script) as filein: print filein.read()
    return sub_script


def map_bam_tsv(tsv):
    '''
    Maps sample names to bam files.
    '''
    with open(tsv) as filein:
        return dict(s.split('\t')
                    for s in filein.read().split('\n')
                    if len(s.split('\t')) == 2)


def main():
    '''
    Parses CLI args and setup.
    '''
    parser = argparse.ArgumentParser(description="Cloud VCF pipeline from BAMs")
    parser.add_argument("bamtsv", metavar="BAM_TSV",
                        help="sample name and BAM TSV file")
    parser.add_argument("bucket", metavar="BucketName",
                        help="google bucket")
    parser.add_argument("--config", metavar="CONFIG",
                        help="Config file")
    parser.set_defaults(config="config")
    args = parser.parse_args()
    config = ConfigParser.ConfigParser()
    config.read("config")
    default_bucket = config.get('default_templates', 'default_bucket')
    inputs = config.get('default_templates', 'default_inputs')
    sub_script = config.get('default_templates', 'sub_script')
    wdl = default_bucket + config.get('default_templates', 'default_wdl')
    yaml = default_bucket + config.get('default_templates', 'default_yaml')
    options = default_bucket + config.get('default_templates',
                                          'default_options')
    samples = map_bam_tsv(args.bamtsv)
    codes = [submit_variant_calling(sample_name, bam, default_bucket, inputs,
                                    sub_script, wdl, options, yaml)
             for sample_name, bam in samples.items()]
    print codes


if __name__ == "__main__":
    main()
