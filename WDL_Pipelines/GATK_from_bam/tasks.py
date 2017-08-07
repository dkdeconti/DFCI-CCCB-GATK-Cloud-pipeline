# Create your tasks here
from __future__ import absolute_import, unicode_literals
from celery.decorators import task
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
def check_completion(project, code_map, bucket_name):
    storage_client = storage.Client()
    bucket = storage_client.get_bucket(bucket_name)
    while code_map:
        for code, samplename in code_map.items():
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
            if done_status == True:
                public_link = LINK_ROOT % (bucket.name, samplename)
                r = Resource(project=project,
                             basename=samplename,
                             public_link=public_link,
                             resource_type='VCF files')
                r.save()
                del code_map[code]
    message_html = """
    <html>
    <body>
    Your variant calling analysis has finished. Log-in to download your results.
    </body>
    </html>
    """
    email_utils.send_email(message_html, [project_owner,], \
                           '[CCCB] Variant calling analysis completed')



@task(name='deseq_call')
def check_analysis_complete(deseq_cmd, results_dir, cloud_dge_dir, contrast_name, bucket_name, project_pk):
    pass
    # Example delivery file setup
    #r = Resource(project=project, basename = os.path.basename(zipfile), public_link = public_link, resource_type = 'Compressed results')