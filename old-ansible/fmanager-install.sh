#! /bin/bash
python3 -m venv /home/flowmon/fmanager/
cd /home/flowmon/fmanager/
source /home/flowmon/fmanager/bin/activate
pip3 install --upgrade pip
pip3 install ansible-core