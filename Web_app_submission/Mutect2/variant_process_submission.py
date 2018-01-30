'''
Runs exome pipeline from within web app.
'''
# TODO Get project organization from Brian first thing
from google.cloud import storage
import googleapiclient.discovery
import os
import shutil
import glob
import json
import urllib
import urllib2
from ConfigParser import ConfigParser
from string import Template
import sys
import datetime
import re
import subprocess
import random
import pandas as pd
sys.path.append(os.path.abspath('..'))
import email_utils
from client_setup.models import Project, Sample
from download.models import Resource
from django.conf import settings
from . import tasks
CONFIG_FILE = os.path.join(os.path.abspath(os.path.dirname(__file__)),
                                           'config.cfg')
CALLBACK_URL = 'analysis/notify/'
#def parse_config():
#    with open(CONFIG_FILE) as cfg_handle:
#        parser = SafeConfigParser()
#        parser.readfp(cfg_handle)
#        return parser.defaults()

def setup(project_pk):
    
    # note that project was already confirmed for ownership previously. 
    # No need to check here.
    project = Project.objects.get(pk=project_pk)
    # get the reference genome
    reference_genome = project.reference_organism.reference_genome
    bucket_name = project.bucket
    
    # get datasources from db:
    datasources = project.datasource_set.all()
    datasource_paths = [os.path.join(bucket_name, x.filepath)
                        for x in datasources]
    #TODO put gs:// in settings
    datasource_paths = ['gs://' + x
                        for x in datasource_paths]
    # check that those datasources exist in the actual bucket
    storage_client = storage.Client()
    bucket = storage_client.get_bucket(bucket_name)
    all_contents = bucket.list_blobs()
    uploads = [x.name for x in all_contents
               if x.name.startswith(settings.UPLOAD_PREFIX)] # string of rel path
    
    # compare-- it's ok if there were more files in the bucket
    bucket_set = set(uploads)
    datasource_set = set(datasource_paths)
    if len(datasource_set.difference(uploads)) > 0:
        # TODO raise exception
        pass
    # get the mapping of samples to data sources:
    sample_mapping = {}
    all_samples = project.sample_set.all()
    for s in all_samples:
        sample_mapping[(s.pk, s.name)] = []
    for ds in datasources:
        if ds.sample in all_samples:
            sample_mapping[(ds.sample.pk, ds.sample.name)].append(ds)
    # sample_mapping
    #   key = (primary key of sample as int representing sample, sample name)
    #   value = object representing file ex: ds.path <- path to source
    #           ex: gs://<bucket>/ds.path where ds.path == path/file.bam
    return project, bucket_name, sample_mapping

def create_inputs_json(sample_name, bam, genome, config):
    '''
    Injects variables into template json for inputs.
    ''' 
    #input_filename = os.path.join(os.path.abspath(os.path.dirname(__file__)),
    #                              sample_name + ".inputs.json")
    #inputs_filename = os.path.join(settings.TEMP_DIR,
    #                              sample_name + ".inputs.json")
    inputs_filename = '.'.join([sample_name, "inputs.json"])
    d = {"BUCKET_INJECTION": config.get('default_templates',
                                        'reference_bucket'),
         "BAM_INJECTION": bam,
         "INPUT_BASENAME_INJECTION": sample_name,
         "PROBE_INJECTION": config.get('default_templates',
                                       'reference_bucket') +
                            config.get(genome,
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
    template_json = os.path.join(os.path.dirname(os.path.abspath(__file__)), 
                                 config.get('default_templates',
                                            'default_inputs'))
    with open(template_json) as filein:
        s = Template(filein.read())
    inputs_file = os.path.join('/tmp', inputs_filename)
    with open(inputs_file, 'w') as fileout:
        fileout.write(s.substitute(d))
    return inputs_file

def create_submission_template(config, sample_name, bucket, inputs):
    current_dir = os.path.abspath(os.path.dirname(__file__))
    timestamp = datetime.datetime.now().strftime('%H%M%S')
    output_folder = '-'.join([sample_name, timestamp, "output"])
    injects = {"BUCKET_INJECTION": bucket,
               "WDL_FILE": os.path.join(current_dir,
                                        config.get('default_templates',
                                                   'default_wdl')),
               "INPUTS_FILE": inputs,
               "OPTIONS_FILE": os.path.join(current_dir,
                                            config.get('default_templates',
                                                       'default_options')),
               "OUTPUT_FOLDER": output_folder,
               "YAML_FILE": os.path.join(current_dir,
                                         config.get('default_templates',
                                                    'default_yaml'))
               }
    template_file = os.path.join(current_dir, config.get('default_templates',
                                                         'default_submission'))
    with open(template_file) as filein:
        template_string = Template(filein.read())
    submission_string = \
    template_string.substitute(injects).replace('\n', '').replace('\\', '')
    print submission_string # goes to logger automatically
    submission_filename = '.'.join([sample_name, "submission.sh"])
    submission_file = os.path.join('/tmp/', submission_filename)
    with open(submission_file, 'w') as fileout:
        fileout.write(submission_string)
    return output_folder, submission_file

def start_analysis(project_pk):
    """
    This is called when you click 'analyze'
    """
    #config_params = parse_config()
    config = ConfigParser()
    config.read(os.path.join(os.path.abspath(os.path.dirname(__file__)),
                             'config.cfg'))
    project, bucket_name, sample_mapping = setup(project_pk)
    # do work
    #codes = {}
    codes = []
    for key, ds_list in sample_mapping.items():
        ds = ds_list[0]
        sample_pk, sample_name = key
        # set bam location
        bam = "gs://" + os.path.join(project.bucket, ds.filepath)
        inputs_json = create_inputs_json(sample_name, bam, "hg19",
                                         config)
        out_folder, submission_script = create_submission_template(config,
                                                                   sample_name,
                                                                   bucket_name,
                                                                   inputs_json)
        proc = subprocess.Popen("sh %s" % submission_script,
                                shell=True,
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE)
        stdout, stderr = proc.communicate()
        code_key = stderr.split('/')[1].strip('].\n')
        # ToDo define codes data
        #codes[key] = {"code": code_key,
        #              "samplename": sample_name,
        #              "vcffilename": '.'.join([sample_name, "g.vcf"]),
        #              "bucket_path": out_folder}
        codes.append((code_key,
                      sample_name,
                      '.'.join([sample_name, 'g.vcf']),
                      out_folder))
        # Delete injected files after done with them
        os.remove(inputs_json)
        os.remove(submission_script)
    # celery background task for checking completion status of jobs
    tasks.check_completion.delay(project_pk, codes, bucket_name)
    project.in_progress = True
    project.status_message = "Alignment and variant calling in progress"
