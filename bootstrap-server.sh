#!/bin/bash
LOG_FILE="/var/log/server-bootstrap.log"

exec > >(tee -a "$LOG_FILE") 2>&1

if [ "$EUID" -ne 0 ]; then
  echo "Run this as Root" >&2
  exit 1
fi

if [ ! -f ".env" ]; then
   echo "No .env file detected" >&2
   exit 1
fi

print_log(){
      echo ""
      echo "==> $1 <=="
      echo "x============x"
}

set -o allexport
source .env
set +o allexport

print_log "Changing Hostname to ${new_hostname}"
hostnamectl set-hostname "${new_hostname}"

print_log "Making a new user ==> ${username}"
useradd -m -s /bin/bash "$username"
echo "${username}:${password}" | chpasswd

print_log "Installing public key into authorized_keys"
sudo -u "$username" mkdir -p /home/"$username"/.ssh
sudo -u "$username" chmod 700 /home/"$username"/.ssh
echo "$pub_key" | sudo -u "$username" tee -a /home/"$username"/.ssh/authorized_keys > /dev/null
sudo -u "$username" chmod 600 /home/$username/.ssh/authorized_keys

print_log "User + Hostname + SSH key done!"

print_log "Disabling Root Login"
sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
print_log "Root login Disabled"

print_log "Changing SSH Port to ${new_ssh_port}"
ufw allow ${new_ssh_port}/tcp
sed -i "s/^#\?Port .*/Port ${new_ssh_port}/" /etc/ssh/sshd_config
if [ ! -d "/run/sshd" ]; then
   echo "/run/sshd not found! making it then updating it"
   mkdir -p /run/sshd
   chmod 0755 /run/sshd
fi
sshd -t
systemctl disable --now ssh.socket 2>/dev/null || true
systemctl enable ssh.service
systemctl restart ssh.service

echo "======================"
ss -tlnp | grep ":${new_ssh_port}"
echo "======================"

print_log "Done Changed SSH PORT!"

print_log "Configuring UFW"
ufw default deny incoming
ufw default allow outgoing
ufw --force enable

print_log "Done, here is the UFW table"
ufw status verbose

print_log "Installing Packages"
export DEBIAN_FRONTEND=noninteractive
for i in $packages; do
    echo "installing : ${i}"
    apt-get install -y "${i}"
done

print_log "Changing Timezone"
timedatectl set-timezone ${timezone}
timedatectl status

print_log "Bootstrap Completed Successfully! Log saved to ${LOG_FILE}"
