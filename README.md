# Flowmon Device Manager 1.0

Flowmon Device Manager is a standalone web application for managing multiple
Flowmon appliances through SSH and REST API. It includes device status,
performance monitoring, package updates, configuration backups, logs, alerts,
and credential management.
It has been presented at our [Customer Validation Program](https://community.progress.com/s/question/0D5Pb00004erjXlKAI/demo-of-flowmon-device-manager-prototype-share-your-feedback) where you can see also recording of it's capabilities.

## Purpose and support

This package is provided **as is** for validating the Flowmon Device Manager
concept in real environments. **Progress does not provide official support
for this package.** Evaluate it in a controlled environment and keep backups
of your configuration and data.

## Requirements

- **amd64** (Intel/AMD 64-bit).
- **Debian 13** or **Ubuntu 24.04** with systemd.
- A dedicated host or virtual machine/container with TCP **443** and local
  port **8000** available.
- Network access from the manager to your appliances' HTTPS and SSH ports
  (normally **443** and **22**, configurable per device).
- Access to the operating system's apt repositories for system dependencies.

Python application dependencies and the compiled web interface are bundled.
Node.js and internet access to PyPI are not required on the customer host.
Newer Debian/Ubuntu versions are intended targets, but require validation;
this package includes dependencies for Python **3.12 and 3.13** only.

## Download and verify

Download these files from the GitHub release:

- `flowmon-device-manager_1.0.0_amd64.deb`
- `flowmon-device-manager_1.0.0_amd64.deb.sha256`
- `README.md` (this guide)

In the download directory:

```bash
sha256sum --check flowmon-device-manager_1.0.0_amd64.deb.sha256
```

The result should be `OK`. A checksum detects file corruption; it is not a
cryptographic signature proving the publisher's identity.

## Install

Use a fresh, dedicated host. The installer does not disable existing nginx
sites; resolve any existing HTTPS service or virtual-host conflicts first.

```bash
sudo install -m 0644 flowmon-device-manager_1.0.0_amd64.deb /tmp/
sudo apt install /tmp/flowmon-device-manager_1.0.0_amd64.deb
sudo systemctl status fdm.service --no-pager
```

If apt warns that `_apt` cannot access a package and operates unsandboxed as
root, move it to `/tmp` as shown above. That warning alone does not mean the
installation failed.

The installer creates an unprivileged `fdm` service user, a private data
directory, a random application secret, and an initial self-signed HTTPS
certificate. The backend listens only on `127.0.0.1:8000`; nginx exposes the
web interface over HTTPS.

If the host has a firewall, allow inbound TCP **443** from your administration
network. Do not expose port 8000 or permit unrestricted public access.

## First login

Open **`https://<manager-host>/`** in your browser. The initial self-signed
certificate will produce a browser warning.

Read the initial password on the manager:

```bash
sudo cat /var/lib/fdm/data/logs/bootstrap-admin-password
```

Sign in as **`admin`**. You must change the password before accessing protected
features. The password file is deleted after the password change; it is not
included in application logs or downloadable diagnostics.

Under **Settings**, create reusable SSH and REST credential sets, then add
devices and assign those credentials. Optional device groups support bulk
update selection. Settings also provides connection tests.

## Production HTTPS certificate

The initial certificate names localhost only and is for initial setup.
Replace it with a certificate for the manager's actual DNS name or IP address
before production use. The certificate file should include any required
intermediate certificates.

```bash
sudo install -o root -g root -m 0644 fullchain.pem /etc/fdm/tls/fdm.crt
sudo install -o root -g root -m 0600 private-key.pem /etc/fdm/tls/fdm.key
sudo nginx -t
sudo systemctl reload nginx.service
```

Do not share private keys or include them in support requests.

## Configuration and storage

| Location | Purpose |
|---|---|
| `/etc/fdm/fdm.env` | Application configuration and `SECRET_KEY` |
| `/etc/fdm/tls/` | HTTPS certificate and private key |
| `/var/lib/fdm/data/` | Database, encrypted credentials, packages, license packs, logs and support bundles |
| `/var/lib/fdm/venv/` | Generated Python runtime |
| `/usr/lib/flowmon-device-manager/` | Package-managed application files |
| `/etc/nginx/sites-available/fdm` | nginx configuration |

Edit configuration with `sudoedit /etc/fdm/fdm.env`, then restart:

```bash
sudo systemctl restart fdm.service
```

**Keep `SECRET_KEY` unchanged.** It is needed to decrypt stored credentials.
Restoring a database without its original secret can make those credentials
unusable. Do not publish or share `fdm.env`, databases, or TLS private keys.

Common settings include `LOG_LEVEL` (`INFO`, `WARNING`, `ERROR`, or `DEBUG`),
`ACCESS_TOKEN_EXPIRE_HOURS`, `DEVICE_REFRESH_INTERVAL_HOURS`,
`PERF_COLLECT_INTERVAL_MINUTES`, and `COMMUNITY_REFRESH_INTERVAL_HOURS`.
Keep `PRODUCTION=true` for secure session cookies.

## Back up before upgrading

The database uses SQLite WAL mode. Do not copy only `fdm.db` while the service
is running. For a simple consistent backup, stop the service and archive the
entire data and configuration directories:

```bash
sudo systemctl stop fdm.service
backup="/root/fdm-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
sudo tar -czf "$backup" -C / etc/fdm var/lib/fdm/data
sudo chmod 600 "$backup"
sudo systemctl start fdm.service
```

Store backups securely: they contain application secrets, TLS keys and
customer data. Retain a copy outside the manager host.

## Upgrade

Back up first, then install the new `.deb` with apt:

```bash
sudo apt install ./flowmon-device-manager_<new-version>_amd64.deb
sudo systemctl status fdm.service --no-pager
```

The runtime is rebuilt from bundled dependencies. The database, credentials,
configuration secret and TLS keys are preserved. Refresh the browser after
the upgrade. Reinstalling the same version is possible with
`sudo apt install --reinstall ./<package-file>.deb`.

If package configuration fails, correct the reported problem and run:

```bash
sudo dpkg --configure flowmon-device-manager
```

Do not use a source-deployment script to update a package installation.
Existing source installations require a separate migration; the package
refuses recognized legacy deployments rather than overwriting their data.

## Remove or reinstall

```bash
sudo apt remove flowmon-device-manager
# Also remove package-managed configuration:
sudo apt purge flowmon-device-manager
```

Both actions stop the application and remove its nginx enabled-site link.
**Both deliberately retain customer data, `/etc/fdm` secrets and TLS keys,
the generated runtime, and the `fdm` user.** This allows reinstallation to
retain existing logins and decrypt credentials. Other nginx sites and the
nginx package remain untouched.

Permanent data erasure is a separate administrator action. Back up first and
follow your organization's retention policy; never retain an encrypted
database while discarding its required `SECRET_KEY`.

## Troubleshooting and support

```bash
sudo systemctl status fdm.service nginx.service --no-pager
sudo journalctl -u fdm.service -n 100 --no-pager
sudo nginx -t
sudo dpkg-query -W flowmon-device-manager
```

An administrator can download **Manager Diagnostics** from **Logs → Activity
Log**. Include the package version, operating system, incident time/timezone,
steps to reproduce, and request ID when reporting an [issue](https://github.com/progress/flowmon-manager/issues). Issue reporting
does not imply official support from Progress.
Review diagnostics before sharing: logs can contain internal device names,
addresses and package filenames. Never attach databases, credential files,
configuration secrets, or private keys.

Device update batches launch in parallel, not one device at a time. An equal
or newer installed version is not eligible for the selected package.

## Release validation

The installer was installed and started successfully with systemd/nginx on
Debian 13, including HTTPS access and the unprivileged service user.
Application runtime checks also passed in Debian 13 and Ubuntu 24.04
userspaces. Full Ubuntu installation and reboot/removal acceptance testing
have not yet been completed; newer OS releases are not certified.

No additional license is granted by this guide.
