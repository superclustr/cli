# Generated by pykickstart v3.32
#version=DEVEL
# X Window System configuration information
xconfig  --startxonboot
# Keyboard layouts
keyboard 'us'
# Root password
rootpw --iscrypted --lock locked
# System language
lang en_US.UTF-8
# Shutdown after installation
shutdown
# Network information
network --bootproto=dhcp --device=link --activate
# Firewall configuration
firewall --enabled --service=mdns
# Use network installation
url --url https://download.rockylinux.org/stg/rocky/8/BaseOS/$basearch/os/
repo --name="BaseOS" --baseurl=http://dl.rockylinux.org/pub/rocky/8/BaseOS/$basearch/os/ --cost=200
repo --name="AppStream" --baseurl=http://dl.rockylinux.org/pub/rocky/8/AppStream/$basearch/os/ --cost=200
repo --name="PowerTools" --baseurl=http://dl.rockylinux.org/pub/rocky/8/PowerTools/$basearch/os/ --cost=200
repo --name="extras" --baseurl=http://dl.rockylinux.org/pub/rocky/8/extras/$basearch/os --cost=200
repo --name="epel" --baseurl=https://dl.fedoraproject.org/pub/epel/8/Everything/$basearch/ --cost=200
repo --name="epel-modular" --baseurl=https://dl.fedoraproject.org/pub/epel/8/Modular/$basearch/ --cost=200
# System timezone
timezone US/Eastern
# SELinux configuration
selinux --permissive
# System services
services --disabled="sshd" --enabled="NetworkManager"
# System bootloader configuration
bootloader --location=none
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all
# Disk partitioning information
part / --fstype="ext4" --size=10240
part / --size=7300

%post
# FIXME: it'd be better to get this installed from a package
cat > /etc/rc.d/init.d/livesys << EOF
#!/bin/bash
#
# live: Init script for live image
#
# chkconfig: 345 00 99
# description: Init script for live image.
### BEGIN INIT INFO
# X-Start-Before: display-manager chronyd
### END INIT INFO

. /etc/init.d/functions

if ! strstr "\`cat /proc/cmdline\`" rd.live.image || [ "\$1" != "start" ]; then
    exit 0
fi

if [ -e /.liveimg-configured ] ; then
    configdone=1
fi

exists() {
    which \$1 >/dev/null 2>&1 || return
    \$*
}

livedir="LiveOS"
for arg in \`cat /proc/cmdline\` ; do
  if [ "\${arg##rd.live.dir=}" != "\${arg}" ]; then
    livedir=\${arg##rd.live.dir=}
    continue
  fi
  if [ "\${arg##live_dir=}" != "\${arg}" ]; then
    livedir=\${arg##live_dir=}
  fi
done

# Enable swap unless requested otherwise
swaps=\`blkid -t TYPE=swap -o device\`
if ! strstr "\`cat /proc/cmdline\`" noswap && [ -n "\$swaps" ] ; then
  for s in \$swaps ; do
    action "Enabling swap partition \$s" swapon \$s
  done
fi
if ! strstr "\`cat /proc/cmdline\`" noswap && [ -f /run/initramfs/live/\${livedir}/swap.img ] ; then
  action "Enabling swap file" swapon /run/initramfs/live/\${livedir}/swap.img
fi

# Support for persistent homes
mountPersistentHome() {
  # support label/uuid
  if [ "\${homedev##LABEL=}" != "\${homedev}" -o "\${homedev##UUID=}" != "\${homedev}" ]; then
    homedev=\`/sbin/blkid -o device -t "\$homedev"\`
  fi

  # if we're given a file rather than a blockdev, loopback it
  if [ "\${homedev##mtd}" != "\${homedev}" ]; then
    # mtd devs don't have a block device but get magic-mounted with -t jffs2
    mountopts="-t jffs2"
  elif [ ! -b "\$homedev" ]; then
    loopdev=\`losetup -f\`
    if [ "\${homedev##/run/initramfs/live}" != "\${homedev}" ]; then
      action "Remounting live store r/w" mount -o remount,rw /run/initramfs/live
    fi
    losetup \$loopdev \$homedev
    homedev=\$loopdev
  fi

  # if it's encrypted, we need to unlock it
  if [ "\$(/sbin/blkid -s TYPE -o value \$homedev 2>/dev/null)" = "crypto_LUKS" ]; then
    echo
    echo "Setting up encrypted /home device"
    plymouth ask-for-password --command="cryptsetup luksOpen \$homedev EncHome"
    homedev=/dev/mapper/EncHome
  fi

  # and finally do the mount
  mount \$mountopts \$homedev /home
  # if we have /home under what's passed for persistent home, then
  # we should make that the real /home.  useful for mtd device on olpc
  if [ -d /home/home ]; then mount --bind /home/home /home ; fi
  [ -x /sbin/restorecon ] && /sbin/restorecon /home
  if [ -d /home/liveuser ]; then USERADDARGS="-M" ; fi
}

# Help locate persistent homes
findPersistentHome() {
  for arg in \`cat /proc/cmdline\` ; do
    if [ "\${arg##persistenthome=}" != "\${arg}" ]; then
      homedev=\${arg##persistenthome=}
    fi
  done
}

if strstr "\`cat /proc/cmdline\`" persistenthome= ; then
  findPersistentHome
elif [ -e /run/initramfs/live/\${livedir}/home.img ]; then
  homedev=/run/initramfs/live/\${livedir}/home.img
fi

# Mount the persistent home if it's available
if ! strstr "\`cat /proc/cmdline\`" nopersistenthome && [ -n "\$homedev" ] ; then
  action "Mounting persistent /home" mountPersistentHome
fi

if [ -n "\$configdone" ]; then
  exit 0
fi

# Create the liveuser (no password) so automatic logins and sudo works
action "Adding live user" useradd \$USERADDARGS -c "Live System User" liveuser
passwd -d liveuser > /dev/null
usermod -aG wheel liveuser > /dev/null

# Same for root
passwd -d root > /dev/null

# Turn off firstboot (similar to a DVD/minimal install, where it asks
# for the user to accept the EULA before bringing up a TTY)
systemctl --no-reload disable firstboot-text.service 2> /dev/null || :
systemctl --no-reload disable firstboot-graphical.service 2> /dev/null || :
systemctl stop firstboot-text.service 2> /dev/null || :
systemctl stop firstboot-graphical.service 2> /dev/null || :

# Prelinking damages the images
sed -i 's/PRELINKING=yes/PRELINKING=no/' /etc/sysconfig/prelink &>/dev/null || :

# Turn off mdmonitor by default
systemctl --no-reload disable mdmonitor.service 2> /dev/null || :
systemctl --no-reload disable mdmonitor-takeover.service 2> /dev/null || :
systemctl stop mdmonitor.service 2> /dev/null || :
systemctl stop mdmonitor-takeover.service 2> /dev/null || :

# Disable cron
systemctl --no-reload disable crond.service 2> /dev/null || :
systemctl --no-reload disable atd.service 2> /dev/null || :
systemctl stop crond.service 2> /dev/null || :
systemctl stop atd.service 2> /dev/null || :

# Disable abrt
systemctl --no-reload disable abrtd.service 2> /dev/null || :
systemctl stop abrtd.service 2> /dev/null || :

# Don't sync the system clock when running live (RHBZ #1018162)
sed -i 's/rtcsync//' /etc/chrony.conf

# Mark things as configured
touch /.liveimg-configured

# add static hostname to work around xauth bug
# https://bugzilla.redhat.com/show_bug.cgi?id=679486
# the hostname must be something else than 'localhost'
# https://bugzilla.redhat.com/show_bug.cgi?id=1370222
echo "localhost-live" > /etc/hostname

EOF

# HAL likes to start late.
cat > /etc/rc.d/init.d/livesys-late << EOF
#!/bin/bash
#
# live: Late init script for live image
#
# chkconfig: 345 99 01
# description: Late init script for live image.

. /etc/init.d/functions

if ! strstr "\`cat /proc/cmdline\`" rd.live.image || [ "\$1" != "start" ] || [ -e /.liveimg-late-configured ] ; then
    exit 0
fi

exists() {
    which \$1 >/dev/null 2>&1 || return
    \$*
}

touch /.liveimg-late-configured

# Read some stuff out of the kernel cmdline
for o in \`cat /proc/cmdline\` ; do
    case \$o in
    ks=*)
        ks="--kickstart=\${o#ks=}"
        ;;
    xdriver=*)
        xdriver="\${o#xdriver=}"
        ;;
    esac
done

# If liveinst or textinst is given, start installer
if strstr "\`cat /proc/cmdline\`" liveinst ; then
   plymouth --quit
   /usr/sbin/liveinst \$ks
fi
if strstr "\`cat /proc/cmdline\`" textinst ; then
   plymouth --quit
   /usr/sbin/liveinst --text \$ks
fi

EOF

chmod 755 /etc/rc.d/init.d/livesys
/sbin/restorecon /etc/rc.d/init.d/livesys
/sbin/chkconfig --add livesys

chmod 755 /etc/rc.d/init.d/livesys-late
/sbin/restorecon /etc/rc.d/init.d/livesys-late
/sbin/chkconfig --add livesys-late

# Enable tmpfs for /tmp - this is a good idea
systemctl enable tmp.mount

# make it so that we don't do writing to the overlay for things which
# are just tmpdirs/caches
# note https://bugzilla.redhat.com/show_bug.cgi?id=1135475
cat >> /etc/fstab << EOF
vartmp   /var/tmp    tmpfs   defaults   0  0
EOF

# PackageKit likes to play games. Let's fix that.
rm -f /var/lib/rpm/__db*
releasever=$(rpm -q --qf '%{version}\n' --whatprovides system-release)
basearch=$(uname -i)
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-rockyofficial
echo "Packages within this LiveCD"
rpm -qa
# Note that running rpm recreates the rpm db files which aren't needed or wanted
rm -f /var/lib/rpm/__db*

# go ahead and pre-make the man -k cache (#455968)
/usr/bin/mandb

# make sure there aren't core files lying around
rm -f /core*

# remove random seed, the newly installed instance should make it's own
rm -f /var/lib/systemd/random-seed

# convince readahead not to collect
# FIXME: for systemd

echo 'File created by kickstart. See systemd-update-done.service(8).' \
    | tee /etc/.updated >/var/.updated

# Drop the rescue kernel and initramfs, we don't need them on the live media itself.
# See bug 1317709
rm -f /boot/*-rescue*

# Disable network service here, as doing it in the services line
# fails due to RHBZ #1369794 - the error is expected
/sbin/chkconfig network off

# Remove machine-id on generated images
rm -f /etc/machine-id
touch /etc/machine-id

# add initscript
cat >> /etc/rc.d/init.d/livesys << EOF

if [ -f /usr/share/anaconda/gnome/rhel-welcome.desktop  ]; then
  mkdir -p ~liveuser/.config/autostart
  cp /usr/share/anaconda/gnome/rhel-welcome.desktop /usr/share/applications/
  cp /usr/share/anaconda/gnome/rhel-welcome.desktop ~liveuser/.config/autostart/
fi

# Set akonadi backend
mkdir -p /home/liveuser/.config/akonadi
cat > /home/liveuser/.config/akonadi/akonadiserverrc << AKONADI_EOF
[%General]
Driver=QSQLITE3
AKONADI_EOF

# Disable baloo
cat > /home/liveuser/.config/baloofilerc << BALOO_EOF
[Basic Settings]
Indexing-Enabled=false
BALOO_EOF

# make sure to set the right permissions and selinux contexts
chown -R liveuser:liveuser /home/liveuser/
restorecon -R /home/liveuser/
restorecon -R /

EOF
dnf config-manager --set-enabled powertools

# Define Nameservers explicitly
cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

%end

%post --erroronfail
# Attempt to ping google.com 10 times, and exit if it's unsuccessful
ATTEMPTS=10
for i in $(seq 1 $ATTEMPTS); do
    if ping -c1 google.com &>/dev/null; then
        # Success, break the loop and move on
        break
    elif [ $i -eq $ATTEMPTS ]; then
        # If this was the last attempt, exit with an error
        echo "Network is not up, exiting"
        exit 1
    else
        # Sleep for a second before the next attempt
        sleep 1
    fi
done
%end

%post --nochroot
cp $INSTALL_ROOT/usr/share/licenses/*-release/* $LIVE_ROOT/

# only works on x86_64
if [ "$(uname -i)" = "i386" -o "$(uname -i)" = "x86_64" ]; then
    # For livecd-creator builds
    if [ ! -d $LIVE_ROOT/LiveOS ]; then mkdir -p $LIVE_ROOT/LiveOS ; fi
    cp /usr/bin/livecd-iso-to-disk $LIVE_ROOT/LiveOS

    # For lorax/livemedia-creator builds
    sed -i '
    /## make boot.iso/ i\
    # Add livecd-iso-to-disk script to .iso filesystem at /LiveOS/\
    <% f = "usr/bin/livecd-iso-to-disk" %>\
    %if exists(f):\
        install ${f} ${LIVEDIR}/${f|basename}\
    %endif\
    ' /usr/share/lorax/templates.d/99-generic/live/x86.tmpl
fi

%end

%post
# Configure custom MOTD
cat > /etc/custom-motd.sh << 'EOF'
#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Display Legal Warning
echo -e "\nWARNING: Unauthorized access to this system is forbidden and will be prosecuted by law."
echo -e "By accessing this system, you agree that your actions may be monitored if unauthorized usage is suspected.\n"

# Display OS & Host details
echo -e "Hostname: $(hostname)"
echo -e "Operating System: $(cat /etc/redhat-release)"

# Display IP addresses
echo -e "\nIPv4 Addresses:"
ip -o -4 addr list | awk -F '[ /]+' '/global/ {print $4}' | while read -r line; do
    echo "- $line"
done

IPV6_ADDRS=$(ip -o -6 addr list | awk -F '[ /]+' '/global/ {print $4}')
if [[ ! -z $IPV6_ADDRS ]]; then
    echo -e "IPv6 Addresses:"
    echo "$IPV6_ADDRS" | while read -r line; do
        echo "- $line"
    done
fi

# Netdata Monitoring Notification
echo -e "\nThis system is attached to Netdata Cloud monitoring system.\nhttps://www.netdata.cloud/\n"

# Failed SSH Login Attempts
echo -e "=== Failed SSH Login Attempts ==="
FAILED_ATTEMPTS=$(journalctl _SYSTEMD_UNIT=sshd.service | grep 'Failed password' | tail -n 5)
if [[ ! -z $FAILED_ATTEMPTS ]]; then
    echo "$FAILED_ATTEMPTS"
    echo -e "${YELLOW}Please review any suspicious activity.${NC}"
else
    echo "No recent failed SSH attempts."
fi

# Recent sudo executions without permission
echo -e "\n=== Recent sudo executions without permission ==="
SUDO_DENIED=$(journalctl _SYSTEMD_UNIT=sudo.service | grep 'permission denied' | tail -n 5)
if [[ ! -z $SUDO_DENIED ]]; then
    echo "$SUDO_DENIED"
    echo -e "${YELLOW}Ensure user permissions are correctly configured.${NC}"
else
    echo "No recent sudo permission denials."
fi

# Other custom checks can be added below

echo
EOF
chmod +x /etc/custom-motd.sh

cat >> /etc/profile <<EOF

# Log motd
/etc/custom-motd.sh
EOF
%end

%post
# Setup automatic updates
cat > /etc/dnf/automatic.conf << 'EOF'
[commands]
#  What kind of upgrade to perform:
# default                            = all available upgrades
# security                           = only the security upgrades
upgrade_type = default
random_sleep = 0

# Maximum time in seconds to wait until the system is on-line and able to
# connect to remote repositories.
network_online_timeout = 60

# To just receive updates use dnf-automatic-notifyonly.timer

# Whether updates should be downloaded when they are available, by
# dnf-automatic.timer. notifyonly.timer, download.timer and
# install.timer override this setting.
download_updates = yes

# Whether updates should be applied when they are available, by
# dnf-automatic.timer. notifyonly.timer, download.timer and
# install.timer override this setting.
apply_updates = yes


[emitters]
# Name to use for this system in messages that are emitted.  Default is the
# hostname.
# system_name = my-host

# How to send messages.  Valid options are stdio, email and motd.  If
# emit_via includes stdio, messages will be sent to stdout; this is useful
# to have cron send the messages.  If emit_via includes email, this
# program will send email itself according to the configured options.
# If emit_via includes motd, /etc/motd file will have the messages. if
# emit_via includes command_email, then messages will be send via a shell
# command compatible with sendmail.
# Default is email,stdio.
# If emit_via is None or left blank, no messages will be sent.
emit_via = stdio


[email]
# The address to send email messages from.
email_from = root@example.com

# List of addresses to send messages to.
email_to = root

# Name of the host to connect to to send email messages.
email_host = localhost


[command]
# The shell command to execute. This is a Python format string, as used in
# str.format(). The format function will pass a shell-quoted argument called
# `body`.
# command_format = "cat"

# The contents of stdin to pass to the command. It is a format string with the
# same arguments as `command_format`.
# stdin_format = "{body}"


[command_email]
# The shell command to use to send email. This is a Python format string,
# as used in str.format(). The format function will pass shell-quoted arguments
# called body, subject, email_from, email_to.
# command_format = "mail -Ssendwait -s {subject} -r {email_from} {email_to}"

# The contents of stdin to pass to the command. It is a format string with the
# same arguments as `command_format`.
# stdin_format = "{body}"

# The address to send email messages from.
email_from = root@example.com

# List of addresses to send messages to.
email_to = root


[base]
# This section overrides dnf.conf

# Use this to filter DNF core messages
debuglevel = 1
EOF

sudo systemctl enable --now dnf-automatic.timer
%end

%post
cat > /etc/ssh/sshd_config << 'EOF'
#	$OpenBSD: sshd_config,v 1.104 2021/07/02 05:11:21 dtucker Exp $

# This is the sshd server system-wide configuration file.  See
# sshd_config(5) for more information.

# This sshd was compiled with PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin

# The strategy used for options in the default sshd_config shipped with
# OpenSSH is to specify options with their default value where
# possible, but leave them commented.  Uncommented options override the
# default value.

# To modify the system-wide sshd configuration, create a  *.conf  file under
#  /etc/ssh/sshd_config.d/  which will be automatically included below
Include /etc/ssh/sshd_config.d/*.conf

# If you want to change the port on a SELinux system, you have to tell
# SELinux about this change.
# semanage port -a -t ssh_port_t -p tcp #PORTNUMBER
#
#Port 22
#AddressFamily any
#ListenAddress 0.0.0.0
#ListenAddress ::

#HostKey /etc/ssh/ssh_host_rsa_key
#HostKey /etc/ssh/ssh_host_ecdsa_key
#HostKey /etc/ssh/ssh_host_ed25519_key

# Ciphers and keying
#RekeyLimit default none

# Logging
#SyslogFacility AUTH
#LogLevel INFO

# Authentication:

LoginGraceTime 2m
PermitRootLogin without-password
#StrictModes yes
MaxAuthTries 6
MaxSessions 10

PubkeyAuthentication yes

# The default is to check both .ssh/authorized_keys and .ssh/authorized_keys2
# but this is overridden so installations will only check .ssh/authorized_keys
AuthorizedKeysFile	.ssh/authorized_keys

#AuthorizedPrincipalsFile none

#AuthorizedKeysCommand none
#AuthorizedKeysCommandUser nobody

# For this to work you will also need host keys in /etc/ssh/ssh_known_hosts
#HostbasedAuthentication no
# Change to yes if you don't trust ~/.ssh/known_hosts for
# HostbasedAuthentication
#IgnoreUserKnownHosts no
# Don't read the user's ~/.rhosts and ~/.shosts files
#IgnoreRhosts yes

# To disable tunneled clear text passwords, change to no here!
PasswordAuthentication no
PermitEmptyPasswords no

# Change to no to disable s/key passwords
#KbdInteractiveAuthentication yes

# Kerberos options
#KerberosAuthentication no
#KerberosOrLocalPasswd yes
#KerberosTicketCleanup yes
#KerberosGetAFSToken no
#KerberosUseKuserok yes

# GSSAPI options
#GSSAPIAuthentication no
#GSSAPICleanupCredentials yes
#GSSAPIStrictAcceptorCheck yes
#GSSAPIKeyExchange no
#GSSAPIEnablek5users no

# Set this to 'yes' to enable PAM authentication, account processing,
# and session processing. If this is enabled, PAM authentication will
# be allowed through the KbdInteractiveAuthentication and
# PasswordAuthentication.  Depending on your PAM configuration,
# PAM authentication via KbdInteractiveAuthentication may bypass
# the setting of "PermitRootLogin without-password".
# If you just want the PAM account and session checks to run without
# PAM authentication, then enable this but set PasswordAuthentication
# and KbdInteractiveAuthentication to 'no'.
# WARNING: 'UsePAM no' is not supported in RHEL and may cause several
# problems.
#UsePAM no

#AllowAgentForwarding yes
#AllowTcpForwarding yes
#GatewayPorts no
#X11Forwarding no
#X11DisplayOffset 10
#X11UseLocalhost yes
#PermitTTY yes
#PrintMotd yes
#PrintLastLog yes
#TCPKeepAlive yes
#PermitUserEnvironment no
#Compression delayed
#ClientAliveInterval 0
#ClientAliveCountMax 3
#UseDNS no
#PidFile /var/run/sshd.pid
#MaxStartups 10:30:100
#PermitTunnel no
#ChrootDirectory none
#VersionAddendum none

# no default banner path
#Banner none

# override default of no subsystems
Subsystem	sftp	/usr/libexec/openssh/sftp-server

# Example of overriding settings on a per-user basis
#Match User anoncvs
#	X11Forwarding no
#	AllowTcpForwarding no
#	PermitTTY no
#	ForceCommand cvs server
EOF
%end

%post
# Nvidia DeepOps
git clone --branch release-22.04 --depth 1 https://github.com/NVIDIA/deepops.git /root/deepops
%end

%post --nochroot
# Copying Nvidia DeepOps Patch
cp ../../assets/deepops-release-22.04-rocky-support.patch $INSTALL_ROOT/root/deepops/deepops-release-22.04-rocky-support.patch
%end

%post
# Patch Rocky Linux Support
(
cd /root/deepops
git apply deepops-release-22.04-rocky-support.patch
)

# Setup DeepOps
/root/deepops/scripts/setup.sh

# Install Kubernetes
ansible-playbook /root/deepops/playbooks/k8s-cluster.yml

# Ensure that NFS is used as a backend for dynamic provisioning of PVCs
ansible-playbook /root/deepops/playbooks/k8s-cluster/nfs-client-provisioner.yml

# Install Prometheus and Grafana
/root/deepops/scripts/k8s/deploy_monitoring.sh

# Install Kubeflow
/root/deepops/scripts/k8s/deploy_kubeflow.sh
%end

%post --erroronfail
# Install Netdata but don't start it immediately
curl https://my-netdata.io/kickstart.sh > /tmp/netdata-kickstart.sh && sh /tmp/netdata-kickstart.sh --prepare-offline-install-source /root/netdata-offline
/root/netdata-offline/install.sh --nightly-channel --dont-start-it --non-interactive
systemctl disable --force netdata
%end

%packages
@anaconda-tools
@base-x
@core
@fonts
@hardware-support
@standard
anaconda
anaconda-install-env-deps
anaconda-live
chkconfig
dracut-live
epel-release
initscripts
kernel
kernel-modules
kernel-modules-extra
memtest86+
syslinux
openssh-clients
python3.11
python3.11-pip
ansible
git
chrony
dnf-automatic
-@admin-tools
-@input-methods
-desktop-backgrounds-basic
-digikam
-gnome-disk-utility
-hplip
-iok
-isdn4k-utils
-k3b
-kdeaccessibility*
-kipi-plugins
-krusader
-ktorrent
-mpage
-scim*
-system-config-printer
-system-config-services
-system-config-users
-xsane
-xsane-gimp

%end

%post
# Remove obstructive files for initrd
rm -f /usr/lib/systemd/system/local-fs.target
rm -f /usr/lib/systemd/system/swap.target
rm -rf /run/*
#rm -rf /tmp/*
find /var/log/ -type f -exec rm -f {} +
%end

%include lazy-umount.ks