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

LINK_ROOT = 'https://storage.cloud.google.com/%s/%s' #TODO put this in settings.py?  can a non-app access?

@task(name='deseq_call')
def deseq_call(deseq_cmd, results_dir, cloud_dge_dir, contrast_name, bucket_name, project_pk):
        p = subprocess.Popen(deseq_cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        stdout, stderr = p.communicate()
        if p.returncode != 0:
                with open(os.path.join(results_dir, 'deseq_error.log'), 'w') as fout:
                        fout.write('STDOUT:\n%s\n' % stdout)
                        fout.write('STDERR:\n%s' % stderr)
                #TODO send error email to CCCB
                email_utils.send_email("There was a problem with the deseq analysis.  Check the %s directory" % results_dir, settings.CCCB_EMAILS, '[CCCB] Problem with DGE script')
        else:

                project = Project.objects.get(pk=project_pk)

                storage_client = storage.Client()
                bucket = storage_client.get_bucket(bucket_name)

                project_owner = project.owner.email

                # make some plots
                #for f in glob.glob(os.path.join(results_dir, '*deseq.tsv')):
                #       output_figure_path = f.replace('deseq.tsv', 'volcano_plot.pdf')
                #       dge_df = pd.read_table(f, sep='\t')
                #       volcano_plot(dge_df, output_figure_path)


                # zip everything up
                zipfile = os.path.join(settings.TEMP_DIR, '%s-%s.zip' % (contrast_name, datetime.datetime.now().strftime('%H%M%S')))
                zip_cmd = 'zip -rj %s %s' % (zipfile, results_dir)
                print 'zip up using command: %s' % zip_cmd
                p = subprocess.Popen(zip_cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                stdout, sterr = p.communicate()
                if p.returncode != 0:
                        #TODO: send email to cccb?  Shouldn't happen and not a user error.
                        pass
                # the name relative to the bucket
                destination = os.path.join(cloud_dge_dir, os.path.basename(zipfile))
                zip_blob = bucket.blob(destination)
                zip_blob.upload_from_filename(zipfile)
                acl = zip_blob.acl
                entity = acl.user(project_owner)
                entity.grant_read()
                acl.save()

                # remove the file locally
                os.remove(zipfile)

                # change the metadata so the download does not append the path 
                set_meta_cmd = 'gsutil setmeta -h "Content-Disposition: attachment; filename=%s" gs://%s/%s' % (os.path.basename(zipfile), bucket.name, destination)
                process = subprocess.Popen(set_meta_cmd, shell = True, stderr=subprocess.STDOUT, stdout=subprocess.PIPE)
                stdout, stderr = process.communicate()
                if process.returncode != 0:
                        print 'There was an error while setting the metadata on the zipped archive with gsutil.  Check the logs.  STDERR was:%s' % stderr
                        raise Exception('Error during gsutil upload module.')
                shutil.rmtree(results_dir)

                # register the zip archive with the download app
                public_link = LINK_ROOT % (bucket.name, zip_blob.name)
                r = Resource(project=project, basename = os.path.basename(zipfile), public_link = public_link, resource_type = 'Compressed results')
                r.save()

                message_html = """
                <html>
                <body>
                Your differential analysis has finished.  Log-in to download your results
                </body>
                </html>
                """
                email_utils.send_email(message_html, [project_owner,], '[CCCB] Differential gene expression analysis completed')