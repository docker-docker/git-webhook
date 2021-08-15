#!/bin/bash
set -e
PROJECT_FOLDER=$(dirname $PWD)
#================================================
# 2. setup the git webhook in current manager machine
wget -O get-pip.py https://github.com/pypa/get-pip/raw/b60e2320d9e8d02348525bd74e871e466afdf77c/get-pip.py
python3 get-pip.py \
  --disable-pip-version-check \
  --no-cache-dir
pip --version
find /usr/local -depth \
  \( \
  \( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
  -o \
  \( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
  \) -exec rm -rf '{}' +
rm -f get-pip.py

cd "Project folder is: ${PROJECT_FOLDER}"
pip install -r requirements.txt
# nohup python3 webhooks.py >>app.log 2>&1 &
echo "git webhook setup completed!"
cat >/lib/systemd/system/githook.service <<EOF
[Unit]
Description=A Git webhook to integration git pull event
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
# Our service will notify systemd once it is up and running
Type=simple
ExecStart=/usr/bin/python3 /opt/workspace/git-webhook/webhooks.py
StandardInput=tty-force
# Disable Python's buffering of STDOUT and STDERR, so that output from the
# service shows up immediately in systemd's logs
Environment=PYTHONUNBUFFERED=1
# Automatically restart the service if it crashes
Restart=on-failure

[Install]
# Tell systemd to automatically start this service when the system boots
# (assuming the service is enabled)
WantedBy=multi-user.target

EOF

sudo systemctl daemon-reload && sudo systemctl enable githook.service && sudo systemctl start githook.service
sudo chmod +x hooks/*