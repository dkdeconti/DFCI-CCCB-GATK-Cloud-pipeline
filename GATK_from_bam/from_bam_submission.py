import argparse
import ConfigParser
import os
import random
import string
import subprocess
import sys
import time
import yaml
from string import Template


def create_inputs_json(sample_name, bam, genome, probe, config):
    '''
    Injects variables into template json for inputs.
    '''
    bar_code = ''.join(random.SystemRandom().choice(string.ascii_letters +
                                                    string.digits)
                       for _ in range(10))
    inputs_filename = '.'.join([sample_name, bar_code, "inputs.json"])
    d = {"BUCKET_INJECTION": config.get('default_templates',
                                        'reference_bucket'),
         "BAM_INJECTION": bam,
         "INPUT_BASENAME_INJECTION": sample_name,
         "PROBE_INJECTION": config.get('default_templates',
                                       'reference_bucket') +
                            config.get(probe,
                                       'bucket') +
                            config.get(probe,
                                       'scattered_probe_list'),
         "REF_FASTA": config.get(genome, 'ref_fasta'),
         "REF_FASTA_INDEX": config.get(genome, "ref_fasta_index"),
         "REF_DICT": config.get(genome, 'ref_dict'),
         "REF_FASTA_AMB": config.get(genome, 'ref_fasta_amb'),
         "REF_FASTA_ANN": config.get(genome, 'ref_fasta_ann'),
         "REF_FASTA_BWT": config.get(genome, 'ref_fasta_bwt'),
         "REF_FASTA_PAC": config.get(genome, 'ref_fasta_pac'),
         "REF_FASTA_SA": config.get(genome, 'ref_fasta_sa'),
         "DBSNP": config.get(genome, 'dbsnp'),
         "DBSNP_INDEX": config.get(genome, 'dbsnp_index'),
         "KNOWN_INDELS": config.get(genome, 'known_indels'),
         "KNOWN_INDELS_INDEX": config.get(genome, 'known_indels_index')}
    with open(config.get('default_templates', 'default_inputs')) as filein:
        s = Template(filein.read())
    with open(inputs_filename, 'w') as fileout:
        fileout.write(s.substitute(d))
    return inputs_filename


def create_sub_script(sample_name, bucket, inputs, config):
    '''
    Inject variables into template submission script.
    '''
    bar_code = inputs.strip('.inputs.json').split('.')[-1]
    if config.get('default_templates', 'template_loc') == 'False':
        ref_loc = os.path.dirname(os.path.realpath(__file__))
    else:
        ref_loc = config.get('default_templates', 'reference_loc')
    injects = {"BUCKET_INJECTION": bucket,
               "WDL_FILE": os.path.join(ref_loc,
                                        config.get('default_templates',
                                                   'default_wdl')),
               "INPUTS_FILE": inputs,
               "OPTIONS_FILE": os.path.join(ref_loc,
                                            config.get('default_templates',
                                                       'default_options')),
               "OUTPUT_FOLDER": '-'.join([sample_name, bar_code, "wdl_output"]),
               "YAML_FILE": os.path.join(ref_loc,
                                         config.get('default_templates',
                                                    'default_yaml'))
              }
    with open(config.get('default_templates', 'default_submission')) as filein:
        template_string = Template(filein.read())
    sub_filename = '.'.join([sample_name, bar_code, "submission.sh"])
    with open(sub_filename, 'w') as fileout:
        fileout.write(template_string.substitute(injects))
    return sub_filename


def submit_variant_calling(sample_name, bam_file, bucket, genome, probe, config):
    '''
    Submission script for individual bam.
    '''
    inputs = create_inputs_json(sample_name, bam_file, genome, probe, config)
    sub_script = create_sub_script(sample_name, bucket, inputs, config)
    with open(sub_script) as filein:
        script = filein.read().replace('\n', '').replace('\\', '')
    proc = subprocess.Popen(script, shell=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    _, stderr = proc.communicate()
    #print stderr
    code = stderr.split('/')[1].strip('].\n')
    sys.stderr.write(code + '\n')
    barcode = inputs.strip('.inputs.json').split('.')[-1]
    with open('.'.join([sample_name, barcode, "operation_id"]), 'w') as fileout:
        fileout.write(code)
    return code


def map_bam_tsv(tsv):
    '''
    Maps sample names to bam files.
    '''
    with open(tsv) as filein:
        return dict(s.split('\t')
                    for s in filein.read().split('\n')
                    if len(s.split('\t')) == 2)


def wait_until_complete(codes):
    '''
    Idles until all google compute pipelines/instances are complete.
    '''
    keep_waiting = True
    errors = {}
    while keep_waiting:
        sys.stderr.write('.')
        #time.sleep(3600) # Waits 1 hour
        time.sleep(300) # Waits 5 minutes
        for code in codes:
            script = ' '.join(["gcloud alpha genomics operations describe",
                               code,
                               "--format='yaml(done, error, metadata.events)'"])
            proc = subprocess.Popen(script, shell=True,
                                    stdout=subprocess.PIPE,
                                    stderr=subprocess.PIPE)
            stdout, _ = proc.communicate()
            out_map = yaml.safe_load(stdout)
            done_status = out_map["done"]
            errors[code] = out_map["error"]
            if done_status:
                keep_waiting = False
            else:
                keep_waiting = True
    sys.stderr.write('\n')
    return errors

def main():
    '''
    Parses CLI args and setup.
    '''
    # Arg parsing
    parser = argparse.ArgumentParser(description="Cloud VCF pipeline from BAMs")
    parser.add_argument("bamtsv", metavar="BAM_TSV",
                        help="sample name and BAM TSV file")
    parser.add_argument("bucket", metavar="BucketName",
                        help="google bucket (leave out trailing /)")
    parser.add_argument("--config", metavar="CONFIG",
                        help="Config file")
    parser.add_argument("--genome", metavar="GENOME",
                        help="genome to analyze against [hg19]")
    parser.add_argument("--probe", metavar="PROBE_TYPE",
                        help="probe type for scatter-gather")
    script_path = os.path.dirname(os.path.realpath(__file__))
    parser.set_defaults(config=os.path.join(script_path,
                                            "config"),
                        genome="hg19",
                        probe="haloplex")
    args = parser.parse_args()
    # Set up config
    config = ConfigParser.ConfigParser()
    config.read(args.config)
    # Work
    sys.stderr.write("Submitting jobs...\n")
    codes = [submit_variant_calling(sample_name, bam, args.bucket, args.genome,
                                    args.probe, config)
             for sample_name, bam in map_bam_tsv(args.bamtsv).items()]
    sys.stderr.write("Done submitting jobs.\n")
    with open("all_submitted_codes.txt", 'w') as handle:
        [handle.write(code + '\n') for code in codes]
    #sys.stderr.write("Waiting for job completion.")
    #errors = wait_until_complete(codes)
    #sys.stderr.write("Done waiting for job completion.\n")
    #print errors


if __name__ == "__main__":
    main()
