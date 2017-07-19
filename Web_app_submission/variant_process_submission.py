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

import pandas as pd

sys.path.append(os.path.abspath('..'))
import email_utils
from client_setup.models import Project, Sample
from download.models import Resource

from django.conf import settings


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
    # TODO move into settings
    datasource_paths = [config_params['gs_prefix'] + x
                        for x in datasource_paths]

    # check that those datasources exist in the actual bucket
    storage_client = storage.Client()
    bucket = storage_client.get_bucket(bucket_name)
    all_contents = bucket.list_blobs()
    uploads = [x.name for x in all_contents
               if x.name.startswith(settings.UPLOAD_PREFIX)] #string of rel path
    
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


def create_inputs_json(sample_name, bam, genome, probe, config):
    '''
    Injects variables into template json for inputs.
    ''' 
    #input_filename = os.path.join(os.path.abspath(os.path.dirname(__file__)),
    #                              sample_name + ".inputs.json")
    input_filename = os.path.join(settings.TEMP_DIR,
                                  sample_name + ".inputs.json")
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


def create_submission_template(config, bucket, inputs):
    current_dir = os.path.abspath(os.path.dirname(__file__))
    injects = {"BUCKET_INJECTION": bucket,
               "WDL_FILE": os.path.join(current_dir,
                                        config.get('default_templates',
                                                   'default_wdl')),
               "INPUTS_FILE": inputs,
               "OPTIONS_FILE": os.path.join(current_dir,
                                            config.get('default_templates',
                                                       'default_options')),
               "OUTPUT_FOLDER": '-'.join([sample_name, "output"]),
               "YAML_FILE": os.path.join(current_dir,
                                         config.get('default_templates',
                                                    'default_yaml'))
              }
    with open(config.get('default_templates', 'default_submission')) as filein:
        template_string = Template(filein.read())
    submission_string = \
    template_string.substitute(injects).replace('\n', '').replace('\\', '')
    return submission_string


def start_analysis(project_pk):
    """
    This is called when you click 'analyze'
    """
    #config_params = parse_config()
    config = ConfigParser.ConfigParser()
    config.read(os.path.join(os.path.abspath(os.path.dirname(__file__)),
                             'config.cfg'))
    project, bucket_name, sample_mapping = setup(project_pk)
    # do work
    codes = {}
    for key, ds in sample_mapping.items():
        sample_pk, sample_name = key
        # set bam
        # TODO adjust ds.filepath to single
        bam = "gs://" + os.path.join(project, ds.filepath) # sets bam location
        inputs_json = create_inputs_json(sample_name, bam, "hg19",
                                         "hg19_1000G_phase3_exome_probe",
                                         config)
        submission_script = create_submission_template(config,
                                                       bucket_name,
                                                       inputs_json)
        proc = subprocess.Popen(submission_script,
                                shell=True,
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE)
        stdout, stderr = proc.communicate()
        codes[key] = stderr.split('/')[1].strip('].\n')
        os.remove(inputs_json) # delete inputs json when done with it


def finish(project):
    """
    This pulls together everything and gets it ready for download.
    Can do things like zipping up output files, creating reports, etc. here
    """

    # notify the client
    # the second arg is supposedd to be a list of emails
    print('send notification email')
    message_html = write_completion_message(project)
    email_utils.send_email(message_html, [project.owner.email,])


def write_completion_message(project):
    """
    This function has the text for your email message to the user.
    """
    message_html = """\
    <html>
      <head></head>
      <body>
          <p>
            Your RNA-Seq analysis (%s) is complete!  Log-in to the CCCB application site to view and download your results.
          </p>
      </body>
    </html>
    """ % project.name
    return message_html


def handle(project, request):
    """
    This is not called by any urls, but rather the request object is forwarded
    on from a central "distributor" method project is a Project object/model

    This where you can check to see if all the samples/processing is complete

    In my process, as the worker machines finish, they send a GET request to 
    a url which includes the project and sample primary keys.
    Then, I check the database to see if all the other samples are finished,
    or whether we have to wait for others to finish.
    """
    print('handling project %s' % project)
    sample_pk = int(request.GET.get('samplePK', '')) # exceptions can be caught in caller
    sample = Sample.objects.get(pk = sample_pk)
    sample.processed = True
    sample.save()

    print 'saved'
    # now check to see if everyone is done
    all_samples = project.sample_set.all()
    if all([s.processed for s in all_samples]):
        print 'All samples have completed!'
        project.in_progress = False
        project.completed = True
        project.finish_time = datetime.datetime.now()
        project.save()
        finish(project)
