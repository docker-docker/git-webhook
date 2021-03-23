#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# File: push-myrepo-main
import json
import os
import subprocess

import sys

sourcecode_root_location = "/opt/workspace"
# Parse the git event parameter
current_file_name = sys.argv[0]
tmp_payload_file = sys.argv[1]
branch_name = sys.argv[2]
event = sys.argv[3]
# Parse the git event payload
with open(tmp_payload_file, 'r') as jsf:
    payload = json.loads(jsf.read())
name = payload['repository']['name']
git_url = payload['repository']['ssh_url']
pusher_name = payload['pusher']['name']
pusher_email = payload['pusher']['email']
print(f'file_name: {current_file_name}, branch: {branch_name}, event: {event}')
# Git pull the latest code repository
code_location = os.path.join(sourcecode_root_location, name)
if os.path.exists(code_location):
    os.chdir(code_location)
    subprocess.run(['git', 'fetch', '--all'], capture_output=True)
    subprocess.run(['git', 'reset', '--hard', f'origin/{branch_name}'], capture_output=True)
else:
    os.makedirs(sourcecode_root_location, exist_ok=True)
    os.chdir(sourcecode_root_location)
    subprocess.run(['git', 'clone', '-b', branch_name, git_url], capture_output=True)
# send the email notification
