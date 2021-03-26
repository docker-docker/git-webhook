#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import hmac
import logging.config
import os
import smtplib
import ssl
import threading
from datetime import datetime
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from ipaddress import ip_address, ip_network
from json import loads, dumps
from os import access, X_OK, remove, fdopen
from os.path import isfile, abspath, normpath, dirname, join, basename
from subprocess import Popen, PIPE
from tempfile import mkstemp

import requests
from flask import Flask, request, abort
from sys import hexversion

LOGGER = logging.getLogger(__name__)
threading.stack_size(2 * 1024 * 1024)


def setup_logging(app: Flask):
    '''
    logging
    :param app:
    :return:
    '''
    try:
        logfile = os.path.join(os.path.dirname(__file__), 'logging.cfg')
        exist_file = os.path.exists(logfile)
        if exist_file:
            log_dir = app.config.get('LOGGING_FOLDER')
            if not os.path.exists(log_dir):
                os.makedirs(log_dir)
            today = datetime.now().strftime('%Y-%m-%d')
            log_path = log_dir + '/githook-' + '%s.log' % (today)

            logging.config.fileConfig(logfile, disable_existing_loggers=False, defaults={'logpath': log_path})
            logging.info('project logging setup already......')
    except Exception as e:
        LOGGER.error('cannot find config file logging.cfg')
        raise


app = Flask(__name__)
app.config['LOGGING_FOLDER'] = 'logs'
setup_logging(app)


@app.route('/', methods=['GET', 'POST'])
def index():
    """
    Main WSGI application entry.
    """

    path = normpath(abspath(dirname(__file__)))

    # Only POST is implemented
    if request.method != 'POST':
        LOGGER.warning(f"Incorrect request method {request.method}, expected method: POST")
        abort(501)

    # Load config
    with open(join(path, 'config.json'), 'r') as cfg:
        config = loads(cfg.read())

    hooks = config.get('hooks_path', join(path, 'hooks'))

    # Allow Github IPs only
    if config.get('github_ips_only', True):
        src_ip = ip_address(
            u'{}'.format(request.access_route[0])  # Fix stupid ipaddress issue
        )
        whitelist = requests.get('https://api.github.com/meta').json()['hooks']

        for valid_ip in whitelist:
            if src_ip in ip_network(valid_ip):
                break
        else:
            LOGGER.error('IP {} not allowed'.format(
                src_ip
            ))
            abort(403)

    # Enforce secret
    secret = config.get('enforce_secret', '')
    if secret:
        # Only SHA1 is supported
        header_signature = request.headers.get('X-Hub-Signature')
        if header_signature is None:
            LOGGER.error(f"header_signature: X-Hub-Signature is None")
            abort(403)

        sha_name, signature = header_signature.split('=')
        if sha_name != 'sha1':
            LOGGER.error(f"header_signature sha is not sha1")
            abort(501)

        # HMAC requires the key to be bytes, but data is string
        mac = hmac.new(str(secret), msg=request.data, digestmod='sha1')

        # Python prior to 2.7.7 does not have hmac.compare_digest
        if hexversion >= 0x020707F0:
            if not hmac.compare_digest(str(mac.hexdigest()), str(signature)):
                LOGGER.error(f"header_signature is incorrect")
                abort(403)
        else:
            # What compare_digest provides is protection against timing
            # attacks; we can live without this protection for a web-based
            # application
            if not str(mac.hexdigest()) == str(signature):
                LOGGER.error(f"header_signature is incorrect")
                abort(403)

    # Implement ping
    event = request.headers.get('X-GitHub-Event', 'ping')
    if event == 'ping':
        LOGGER.info(f"ping call!")
        return dumps({'msg': 'ping'})

    # Gather data
    try:
        payload = request.get_json()
    except Exception as e:
        LOGGER.warning('Request parsing failed')
        abort(400)

    # Determining the branch is tricky, as it only appears for certain event
    # types an at different levels
    branch = None
    try:
        # Case 1: a ref_type indicates the type of ref.
        # This true for create and delete events.
        if 'ref_type' in payload:
            if payload['ref_type'] == 'branch':
                branch = payload['ref']

        # Case 2: a pull_request object is involved. This is pull_request and
        # pull_request_review_comment events.
        elif 'pull_request' in payload:
            # This is the TARGET branch for the pull-request, not the source
            # branch
            branch = payload['pull_request']['base']['ref']

        elif event in ['push']:
            # Push events provide a full Git ref in 'ref' and not a 'ref_type'.
            branch = payload['ref'].split('/', 2)[2]

    except KeyError:
        # If the payload structure isn't what we expect, we'll live without
        # the branch name
        pass

    # All current events have a repository, but some legacy events do not,
    # so let's be safe
    name = payload['repository']['name'] if 'repository' in payload else None

    meta = {
        'name': name,
        'branch': branch,
        'event': event
    }
    LOGGER.info('Metadata:\n{}'.format(dumps(meta)))

    # Skip push-delete
    if event == 'push' and payload['deleted']:
        LOGGER.info('Skipping push-delete event for {}'.format(dumps(meta)))
        return dumps({'status': 'skipped', 'msg': 'Skipping push-delete event!'})

    # Possible hooks
    scripts = []
    if branch and name:
        scripts.append(
            join(hooks, '{event}-{name}-{branch}.py'.format(**meta)))
    if name:
        scripts.append(join(hooks, '{event}-{name}.py'.format(**meta)))
    scripts.append(join(hooks, '{event}.py'.format(**meta)))
    scripts.append(join(hooks, 'all.py'))

    # Check permissions
    scripts = [s for s in scripts if isfile(s) and access(s, X_OK)]
    if not scripts:
        msg=f"hook script {scripts} not found or have no access permission"
        LOGGER.warning(msg)
        return dumps({'status': 'nop', 'msg': msg})

    # Save payload to temporal file
    os_fd, tmp_file = mkstemp()
    with fdopen(os_fd, 'w') as pf:
        pf.write(dumps(payload))

    # Run scripts
    ran = {}
    for s in scripts:

        proc = Popen(
            [s, tmp_file, branch, event],
            stdout=PIPE, stderr=PIPE
        )
        stdout, stderr = proc.communicate()

        ran[basename(s)] = {
            'returncode': proc.returncode,
            'stdout': stdout.decode('utf-8'),
            'stderr': stderr.decode('utf-8'),
        }

        # Log errors if a hook failed
        if proc.returncode != 0:
            LOGGER.error('{} : {} \n{}'.format(
                s, proc.returncode, stderr
            ))

    # Remove temporal file
    remove(tmp_file)

    info = config.get('return_scripts_info', False)
    if not info:
        return dumps({'status': 'done'})

    output = dumps(ran, sort_keys=True, indent=4)
    LOGGER.info(output)
    return output


@app.route('/ping', methods=['GET'])
def ping():
    return {'msg': 'ok', 'timestamp': datetime.now().strftime('%m/%d/%Y, %H:%M:%S')}


def send_email(smtp_server="smtp.gmail.com",
               smtp_port=465,
               auth_user="alterhu2020@gmail.com",
               gmail_app_password="xxxx",
               sender="alterhu2020@gmail.com",
               recipients=['alterhu2020@gmail.com'],
               subject="Git Webhook triggerred",
               body="Hello World!"):
    try:
        port_list = (25, 587, 465)
        if smtp_port not in port_list:
            raise Exception("Port %s not one of %s" % (smtp_port, port_list))

        receiver = recipients if isinstance(
            recipients, (list, tuple)) else [recipients]
        message = MIMEMultipart("alternative")
        message["Subject"] = subject
        message["From"] = sender
        message["To"] = ",".join(receiver)

        message_part = MIMEText(body, "plain")
        message.attach(message_part)

        # creates SMTP session
        context = ssl.create_default_context()
        if smtp_port in (465,):
            smtp_server = smtplib.SMTP_SSL(
                smtp_server, smtp_port, context=context)
        else:
            smtp_server = smtplib.SMTP(smtp_server, smtp_port)
        with smtp_server as server:
            # start TLS for security, remove this line
            if smtp_port in (587,):
                server.starttls(context=context)
            # Authentication
            server.login(auth_user, gmail_app_password)
            # ing the mail
            server.sendmail(sender, receiver, message.as_string())
    except Exception as e:
        print("Error: %s!\n\n" % e)


if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0')
    # send_email(gmail_app_password='wqyyluzmozrktccr')
