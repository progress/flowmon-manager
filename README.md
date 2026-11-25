# Flowmon Device Manager 1.0.3

Flowmon Device Manager is a standalone web application for managing multiple
Flowmon appliances through SSH and REST API. It includes device status,
performance monitoring, package updates, configuration backups, logs, alerts,
and credential management.

## Purpose and support

This package is provided **as is** for validating the Flowmon Device Manager
concept in real environments. **Progress does not provide official support
for this package.** Evaluate it in a controlled environment and keep backups
of your configuration and data.

## Requirements

- **amd64** (Intel/AMD 64-bit).
- **Debian 13** or **Ubuntu 24.04** with systemd.
- Alternatively, **RHEL / Rocky Linux / AlmaLinux 9.4+ or 10** with systemd
  and Python **3.12**. Use the RPM matching the OS major version.
- A dedicated host or virtual machine/container with TCP **443** and local
  port **8000** available.
- Network access from the manager to your appliances' HTTPS and SSH ports
  (normally **443** and **22**, configurable per device).
- Access to the operating system's apt or dnf repositories for system dependencies.

Python application dependencies and the compiled web interface are bundled.
Node.js and internet access to PyPI are not required on the customer host.
Newer Debian/Ubuntu versions are intended targets, but require validation;
this package includes dependencies for Python **3.12 and 3.13** only.

## Download and verify

Download these files from the GitHub release:

- `flowmon-device-manager_1.0.3_amd64.deb` for Debian/Ubuntu, or
  `flowmon-device-manager-1.0.3.el9.x86_64.rpm` /
  `flowmon-device-manager-1.0.3.el10.x86_64.rpm` for Enterprise Linux
- The matching `.sha256` file
- `README.md` (this guide)

In the download directory:

```bash
sha256sum --check flowmon-device-manager_1.0.3_amd64.deb.sha256
# Or, for example, on Enterprise Linux 9:
sha256sum --check flowmon-device-manager-1.0.3.el9.x86_64.rpm.sha256
```

The result should be `OK`. A checksum detects file corruption; it is not a
cryptographic signature proving the publisher's identity.

## Install

Use a fresh, dedicated host. The installer does not disable existing nginx
sites; resolve any existing HTTPS service or virtual-host conflicts first.

```bash
sudo install -m 0644 flowmon-device-manager_1.0.3_amd64.deb /tmp/
sudo apt install /tmp/flowmon-device-manager_1.0.3_amd64.deb
sudo systemctl status fdm.service --no-pager
```

If apt warns that `_apt` cannot access a package and operates unsandboxed as
root, move it to `/tmp` as shown above. That warning alone does not mean the
installation failed.

On Enterprise Linux, use the matching RPM instead:

```bash
# Required on SELinux-enabled hosts; this permits nginx reverse-proxy connections.
# Review this host-wide SELinux boolean before enabling it.
sudo setsebool -P httpd_can_network_connect 1
# EL 9 (requires 9.4+ repositories with Python 3.12):
sudo dnf install ./flowmon-device-manager-1.0.3.el9.x86_64.rpm
# EL 10:
sudo dnf install ./flowmon-device-manager-1.0.3.el10.x86_64.rpm
sudo systemctl status fdm.service --no-pager
```

Run only the install command matching your OS. On hosts without SELinux, omit
`setsebool`. The RPM refuses an incompatible OS major version or a
SELinux-enabled host without the reverse-proxy permission. It does not disable
SELinux or change that host-wide permission automatically. Packages are unsigned;
verify the checksum and obtain them through a trusted channel.

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

Debian/Ubuntu:

```bash
sudo install -o root -g root -m 0644 fullchain.pem /etc/fdm/tls/fdm.crt
sudo install -o root -g root -m 0600 private-key.pem /etc/fdm/tls/fdm.key
sudo nginx -t
sudo systemctl reload nginx.service
```

Enterprise Linux uses the standard SELinux-labelled certificate locations:

```bash
sudo install -o root -g root -m 0644 fullchain.pem /etc/pki/tls/certs/fdm.crt
sudo install -o root -g root -m 0600 private-key.pem /etc/pki/tls/private/fdm.key
sudo restorecon /etc/pki/tls/certs/fdm.crt /etc/pki/tls/private/fdm.key
sudo nginx -t
sudo systemctl reload nginx.service
```

Do not share private keys or include them in support requests.

## Configuration and storage

| Location | Purpose |
|---|---|
| `/etc/fdm/fdm.env` | Application configuration and `SECRET_KEY` |
| `/etc/fdm/tls/` | DEB: HTTPS certificate and private key |
| `/etc/pki/tls/certs/fdm.crt`, `/etc/pki/tls/private/fdm.key` | RPM: HTTPS certificate and private key |
| `/var/lib/fdm/data/` | Database, encrypted credentials, packages, license packs, logs and support bundles |
| `/var/lib/fdm/venv/` | Generated Python runtime |
| `/usr/lib/flowmon-device-manager/` | Package-managed application files |
| `/etc/nginx/sites-available/fdm` (DEB), `/etc/nginx/conf.d/fdm.conf` (RPM) | nginx configuration |

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
Optional `COMMUNITY_PROXY_URL=http://proxy.example.com:3128` routes community
discovery and package downloads through a proxy. Store authenticated proxy URLs
only in the private configuration file.

For optional OpenID Connect SSO, register an HTTPS confidential client with
authorization code flow and PKCE S256 (for example with Authentik). Set
`OIDC_ENABLED=true`, `OIDC_ISSUER`, `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`,
and `OIDC_REDIRECT_URI=https://<fdm-host>/api/auth/oidc/callback`; register
the exact same callback with the provider. Keep `PRODUCTION=true`. The issuer
must match the provider's discovery document exactly, including any trailing
slash. The server must trust and reach the provider over HTTPS.
Authorization codes appear in callback URLs. Ensure existing nginx sites and
other reverse proxies do not log the callback query string; the supplied nginx
configuration disables access logging for `/api/auth/oidc/callback`.

The default `OIDC_AUTO_PROVISION=false` requires an admin to link an existing
FDM account to the provider's exact `sub` via **Settings → Users → SSO
identities**. With `OIDC_AUTO_PROVISION=true`, SSO-only users are created
without administrator rights. Grant admin access locally only. Local login
remains available; retain a protected local admin account for recovery. Logout
ends the FDM session only. Provider-side disablement takes effect at the next
sign-in or when the FDM session expires; disable the user locally to end active
FDM sessions immediately.

Community Downloads now offers **Stable** (default) and **Beta** release channels.
Beta releases are pre-release software and should be evaluated with caution.

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
For RPM installations, also back up `/etc/pki/tls/certs/fdm.crt` and
`/etc/pki/tls/private/fdm.key`.

## Upgrade

Back up first, then install the new `.deb` with apt:

```bash
sudo apt install ./flowmon-device-manager_<new-version>_amd64.deb
sudo systemctl status fdm.service --no-pager
```

For Enterprise Linux, use `sudo dnf upgrade ./flowmon-device-manager-<version>.el9.x86_64.rpm`
(or the `el10` RPM). Reconfigure a failed RPM installation with
`sudo dnf reinstall ./<package-file>.rpm` after fixing the reported problem.
Do not change between EL 9 and EL 10 RPMs on the same OS.

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
# Enterprise Linux:
sudo dnf remove flowmon-device-manager
```

DEB removal/purge stops the application and removes its nginx enabled-site link.
RPM removal stops the application and removes its package-managed nginx config
(modified configuration may be retained by RPM as `.rpmsave`).
**Both deliberately retain customer data, `/etc/fdm` secrets and TLS keys,
the generated runtime, and the `fdm` user.** This allows reinstallation to
retain existing logins and decrypt credentials. Other nginx sites and the
nginx package remain untouched.
RPM-generated TLS files in `/etc/pki/tls` are retained as well.

Permanent data erasure is a separate administrator action. Back up first and
follow your organization's retention policy; never retain an encrypted
database while discarding its required `SECRET_KEY`.

## Troubleshooting and support

```bash
sudo systemctl status fdm.service nginx.service --no-pager
sudo journalctl -u fdm.service -n 100 --no-pager
sudo nginx -t
sudo dpkg-query -W flowmon-device-manager
# Enterprise Linux:
rpm -q flowmon-device-manager
```

An administrator can download **Manager Diagnostics** from **Logs → Activity
Log**. Include the package version, operating system, incident time/timezone,
steps to reproduce, and request ID when reporting an issue. Issue reporting
does not imply official support from Progress.
Review diagnostics before sharing: logs can contain internal device names,
addresses and package filenames. Never attach databases, credential files,
configuration secrets, or private keys.

Device update batches launch in parallel, not one device at a time. An equal
or newer installed version is not eligible for the selected package.

## Release validation

Version 1.0.3 passed fresh installation on Debian 13.7 and upgrades from 1.0.1
on Rocky Linux 9.8 and 10.2. All three passed same-version reinstallation,
systemd/nginx/HTTPS and unprivileged local authentication/API smoke checks,
served frontend feature checks, configuration/TLS/registry preservation,
and decryption of temporary REST/SSH credentials after reinstallation.
Community refresh returned all six components, including through the existing
Squid proxy on the Rocky hosts. The proxy configuration/service was preserved.
Test accounts and credentials were removed afterward.

SSO provider sign-in was not tested; OIDC remained disabled. SELinux was
disabled on both Rocky hosts. Ubuntu installation, SELinux-enforcing behavior,
reboot, removal and purge remain unverified for 1.0.3.

Historical validation:

Version 1.0.1 was installed on Rocky Linux 9 with systemd/nginx, HTTPS access,
the real unprivileged service user, preserved configuration, and a successful
bootstrap-login/password-change smoke test. SELinux was disabled on that test host.
EL 10 dependency installation and application/authentication runtime checks
passed in an isolated userspace, but full post-install/service startup could
not be certified there because of rootless privilege restrictions.

Earlier DEB installer validation passed on Debian 13, with application runtime
checks in Debian 13 and Ubuntu 24.04 userspaces. Version 1.0.1 DEB metadata and
payload checks passed. These earlier userspace checks did not certify full
systemd/SELinux or lifecycle behavior; newer OS releases are not certified.

No additional license is granted by this guide.
