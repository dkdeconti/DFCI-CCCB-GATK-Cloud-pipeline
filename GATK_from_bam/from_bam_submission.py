import argparse
import ConfigParser
import os
import random
import string
import subprocess
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
                            config.get('hg19_1000G_phase3_exome_probe',
                                       'bucket') +
                            config.get('hg19_1000G_phase3_exome_probe',
                                       'scattered_probe_list'),
         "PROBE_BUCKET_INJECTION": config.get('default_templates',
                                              'reference_bucket') +
                                   config.get('hg19_1000G_phase3_exome_probe',
                                              'bucket'),
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
    injects = {"BUCKET_INJECTION": bucket,
               "WDL_FILE": config.get('default_templates', 'reference_bucket') +
                           config.get('default_templates', 'default_wdl'),
               "INPUTS_FILE": inputs,
               "OPTIONS_FILE": config.get('default_templates',
                                          'reference_bucket') +
                               config.get('default_templates',
                                          'default_options'),
               "YAML_FILE": config.get('default_templates',
                                       'reference_bucket') +
                            config.get('default_templates', 'default_yaml')
              }
    #           "YAML_FILE": os.path.join(os.path.abspath(__file__),
    #                                     config.get('default_templates',
    #                                                'default_yaml'))  
    with open(config.get('default_templates', 'default_submission')) as filein:
        template_string = Template(filein.read())
    bar_code = inputs.strip('.inputs.json').split('.')[-1]
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
    p = subprocess.Popen(script, shell=True,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = p.communicate()
    # stderr return 'Running ....' info
    #[('', 'Running [operations/ENTKy7C8KxjOlOjrhajz69EBIMWa4Pu3GSoPcHJvZHVjdGlvblF1ZXVl].\n'), ('', 'Running [operations/EO7Ty7C8KxjZm5-LrPDg-4YBIMWa4Pu3GSoPcHJvZHVjdGlvblF1ZXVl].\n')]
    return (stdout, stderr)


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
    # Arg parsing
    parser = argparse.ArgumentParser(description="Cloud VCF pipeline from BAMs")
    parser.add_argument("bamtsv", metavar="BAM_TSV",
                        help="sample name and BAM TSV file")
    parser.add_argument("bucket", metavar="BucketName",
                        help="google bucket")
    parser.add_argument("--config", metavar="CONFIG",
                        help="Config file")
    parser.add_argument("--genome", metavar="GENOME",
                        help="genome to analyze against [hg19]")
    parser.add_argument("--probe", metavar="PROBE_TYPE",
                        help="probe type for scatter-gather")
    parser.set_defaults(config="config", genome="hg19",
                        probe="hg19_1000G_phase3_exome_probe")
    args = parser.parse_args()
    # Set up config
    config = ConfigParser.ConfigParser()
    config.read(args.config)
    # Work
    #samples = map_bam_tsv(args.bamtsv)
    codes = [submit_variant_calling(sample_name, bam, args.bucket, args.genome,
                                    args.probe, config)
             for sample_name, bam in map_bam_tsv(args.bamtsv).items()]
    print codes


if __name__ == "__main__":
    main()
