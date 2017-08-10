# Create your tasks here
from __future__ import absolute_import, unicode_literals
from celery.decorators import task
import time
import subprocess
import os
import shutil
import glob
import datetime
import email_utils
from rnaseq.plot_methods import volcano_plot
from google.cloud import storage
from django.conf import settings
from download.models import Resource
from client_setup.models import Project
import pandas as pd
import yaml

LINK_ROOT = 'https://storage.cloud.google.com/%s/%s'
#TODO put this in settings.py?  can a non-app access?

@task(name='check_completion')
def check_completion(project_pk, code_map, bucket_name):
    '''

    params
    project_pk: 
    code_map:
    bucket_name: bucket name
    '''
    while code_map:
        for key, code_info_map in code_map.items():
            code = code_info_map["code"]
            script = ' '.join(["gcloud alpha genomics operations describe",
                               code,
                               "--format='yaml(done, error, metadata.events)'"])
            proc = subprocess.Popen(script, shell=True,
                                    stdout=subprocess.PIPE,
                                    stderr=subprocess.PIPE)
            stdout, _ = proc.communicate()
            out_map = yaml.safe_load(stdout)
            done_status = out_map["done"]
            #errors[code] = out_map["error"]
            # setting up file locations
            if done_status == True:
                # data format may be altered:
                samplename = code_info_map["samplename"]
                vcffilename = code_info_map["vcffilename"]
                cloud_dge_dir = code_info_map["bucket_path"]
                #samplename, vcffilename, cloud_dge_dir = code_info_map # fix this!!!
                project = Project.objects.get(pk=project_pk)
                storage_client = storage.Client()
                bucket = storage_client.get_bucket(bucket_name)
                # ToDo fix the path to file (must be sent to app)
                destination = os.path.join(cloud_dge_dir,
                                           os.path.basename(vcffilename))
                vcf_blob = bucket.blob(destination)
                public_link = LINK_ROOT % (bucket.name, vcf_blob.name)
                r = Resource(project=project,
                             basename=samplename,
                             public_link=public_link,
                             resource_type='VCF files')
                r.save()
                del code_map[code]
        time.sleep(900)
    message_html = """
    <html>
    <body>
    Your variant calling analysis has finished. Log-in to download your results.
    </body>
    </html>
    """
    email_utils.send_email(message_html, [project.owner.email,], \
                           '[CCCB] Variant calling analysis completed')
