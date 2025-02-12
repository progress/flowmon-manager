# Flowmon Manager

Ansible playbook to help with update management of Flowmon appliances.

## Purpose
This set of scripts is prepared to help you with updating multiple Flowmon appliances. It should be run from a Flowmon Collector, but it can be started from any Linux operating system where Python 3 installed (at least version 3.6) with a pip tool.

There is an installation bash script which is used to install ansible into Virtual Environment on the collector. But it can be used without this once you know how to use Ansible.

>**This is intentded only for appliances that aren't part of the DA architecture, which has its own distribution of packages.**
## Prerequisites
This system is using Ansible with SSH access with a key. For everything to work properly you would need to generate SSH keys if you haven’t done so yet. It can be done by running
```
ssh-keygen
```
Then you need to copy the key to the machines to make sure it will be accessible. You can simply do this by using ssh-copy-id utility. For example:
```
ssh-copy-id flowmon@10.100.24.55
```
It is also required that all appliances have enabled Automatic package download (in the User interface: Configuration Center > Available packages section).
## Installation
Use your favorite SCP program to copy the content of the package to Flowmon Collector to the flowmon user home directory. On Windows you can use for example WinSCP - <https://winscp.net/eng/download.php>

Unpack the folder in /home/flowmon by using command 
```
tar -xvzf fmanager.tgz
```
Go to the folder fmanager and run the installation script
```
cd fmanager/
./fmanager-install.sh
```
Modify the file hosts with list of your Flowmon appliances, you can list only their IP at a line (i.e. 10.100.24.55) or for easier reading in a format which is in the file now. That is a hostname followed by ansible\_host=\<IP here\> (i.e. testprobe ansible\_host=10.100.24.55)

You can modify the file somewhere else or use vi on the Flowmon appliance.
## Usage
Every time you would like to run this playbook you will need to activate the Python Virtual Environment, that can be done by
```
source fmanager/bin/activate
```
Then it’s just simply running the playbook
```
ansible-playbook fmanager/update-flowmon.yaml
```
You might need to run this playbook several times in case you are using some older version, and the end device would get restarted during the update.
