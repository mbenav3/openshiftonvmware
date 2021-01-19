# Deploying an OpenShift 4 cluster on VMWare ESXi - UPI method

The set of Ansible playbooks included in this library aim to accelerate the deployment of OpenShift clusters on VMWare.

**:exclamation: BEFORE MOVING FORWARD :exclamation:**

- **Disclaimer:** This repository is not officially supported by IBM or Red Hat
- **Security first approach:** As always, you should adhere to your enterprise networking policies and best practices. Please consult your network administrator before proceeding with this guide.

:ok_hand: &nbsp; **When to use this guide**

- **vCenter is not available** in your VMWare environment or you do not have access to the vCenter APIs.

- You are deploying the OpenShift cluster in a private network and want to use a bastion node as the single access point to your cluster from the public domain. (Please refer [architecture section](#architecture) for a more in-depth understanding of the target architecure.)

- You require assigning each node in the cluster a **static IP address**.

> **Note** Please refer to the official documentation for [installing a cluster on vSphere with user-provisioned infrastructure](https://docs.openshift.com/container-platform/4.5/installing/installing_vsphere/installing-vsphere.html#cli-installing-cli_installing-vsphere) for official guidance.

# Prerequisites

Before moving forward with this guide, confirm that:

- ESXi 6.7u3 has been configured with a private and a public network.
- You have a Red Hat account. If you do not, you may [register for a free account here](https://sso.redhat.com/auth/realms/redhat-external/login-actions/registration?client_id=cloud-services&tab_id=UT6HopI625I)

> **Note**: The playbooks in this repository address the requirements needed to begin the OpenShift deployment procedure. To deploy the cluster, the process described on the official OpenShift documentation relies on the existence of a vCenter appliance. The playbooks in this repository help you approximate a similar level of automation in environments where vCenter is not available.

# Environment overview

## Architecture

## :mag_right: &nbsp; Points to note

- The **bastion node** acts as a jump server and serves as the single access point to the cluster from the public domain

- The OpenShift cluster is deployed in a private network.

**Two options for deployment:**

Production environments can deny direct access to the Internet and instead have an HTTP or HTTPS proxy available. You can configure a new OpenShift Container Platform cluster to use a proxy by configuring the proxy settings

https://docs.openshift.com/container-platform/4.5/installing/installing_vsphere/installing-vsphere.html#installation-configure-proxy_installing-vsphere

1. **Air-gapped installation** In an air-gapped deployment, the nodes in the private network are not provided with access to the public network. To run the This requires creating a mirror
2. Add a NAT to allow the internal machines access to the public network

## About the Bastion Node

**OS:** CentOS 8 / RHEL 8
**NFS disk:** /dev/sdb  
**NFS path:** /dev/sdb/export/  
**System Disk:** /dev/sda1  

Services hosted by the Bastion node:

- DNS Server
- Load Balancer - HAProxy
- Web Server - Apache
- NTP Server (optional)
- NFS Server
- Mirror Registry (optional)

## Getting started: Static IPs

To help streamline the installation process, reserve the following IP addresses for your cluster and bastion node:

Bastion node:

- 1 IPv4 address in your public network
- 1 IPv4 address in your private network

Bootstrap node (this is a temporary node that is only needed during the installation process):

- 1 IPV4 address in your private network

Each Master node in the cluster:

- 1 IPV4 address in your private network

Each Worker node in the cluster:

- 1 IPV4 address in your private network

# Provisioning the Bastion node

Through the ESXi interface, create a new Centos8 virtual machine sized to meet the following minimum specs:

- **CPU:** 4 vCPU
- **Memmory:** 16GB RAM
- **Storage:** 2 Disks  
    - **Disk 1:** 100GB thin provision  
    - **Disk 2:** 1TB thin provision

# Configuring your OpenShift environment on the bastion node

## Preparing the Bastion node

This guide helps accelerate the deployment of your cluster through [Ansible Playbooks](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-ansible-on-rhel-centos-or-fedora) and [git](https://git-scm.com/book/it/v2/Per-Iniziare-Installing-Git). The following steps will take you through installing the required packages and setting up the bastion node's network configuration.

1. SSH into your new virtual machine

1. Create a workspace directory and navigate to it help you keep your space clean

```console
mkdir ~/ocp-install-wd

export OCP_INSTALL_WD=~/ocp-install-wd

cd $OCP_INSTALL_WD
```

1. Install [EPEL](https://fedoraproject.org/wiki/EPEL)  

```console
yum -y install epel-release
```

1. Install the latest git and Ansible packages

```console
yum -y install git ansible
```

1. Install the oc command line tools, kubectl, and openshift-install

```console
git clone https://github.com/cptmorgan-rh/install-oc-tools

cd install-oc-tools

./install-oc-tools.sh --version 4.5.6
```

1. Verify that that the correct versions of the tools where installed

```console
oc version; openshift-install version;
```

1. Download your Red Hat OpenShift pull secret from the [openshift vmware installer page](https://cloud.redhat.com/openshift/install/vsphere/user-provisioned)

1. Create a directory for your pull-secret file to that new directory.

```console
mkdir -p ~/.openshift

mv pull-secret /.openshift
```

1. Clone this repository to your working directory

```console
cd $OCP_INSTALL_WD

git clone [add_public_url]

cd mas-deployment-vmware-upi
```

2. Install the Ansible collections needed to run the playbooks in this project

```console
ansible-galaxy collection install -r requirements.yml
```

## Preparing the bastion node network interfaces

**Official OpenShift Guidance:**  [Networking requirements for user-provisioned infrastructure](https://docs.openshift.com/container-platform/4.5/installing/installing_vsphere/installing-vsphere.html#installation-network-user-infra_installing-vsphere)

1. Update the `vars/bastion-network-config.yml` configuration file with your network configuration.

```console
vim vars/bastion-network-config.yml
```

1. Run the playbook below to configure the bastion node's network interfaces

```console
yum install -y policycoreutils-python-utils platform-python

ansible-playbook tasks/bastion-network-setup.yml

firewall-cmd --set-default-zone=external
```

## DNS Configuration

**Official OpenShift Guidance:**  [User-provisioned DNS Requirements](https://docs.openshift.com/container-platform/4.5/installing/installing_vsphere/installing-vsphere.html#installation-dns-user-infra_installing-vsphere)

1. Update the `vars/cluster-network-config.yml` configuration file with the network configuration you've chosen for your cluster.  

```console
vim vars/cluster-network-config.yml
```

2. Run the playbook below to deploy a Bind DNS server in the bastion node

```console
ansible-playbook tasks/dns-setup-bind.yml
```

## Installing a Web Server

1. Run the playbook below to deploy an Apache server in the bastion node

```bash
ansible-playbook tasks/apache-setup.yml
```

1. To confirm that the web server was successfully deployed, submit a GET request to the server on port 8080

```console
curl localhost:8080
```

:white_check_mark: &nbsp; If the installation was successful, the server will respond with the default Apache webpage

## Installing a Load Balancer

1. Run the playbook below to deploy a HAProxy load balancer in the bastion node

```console
ansible-playbook tasks/haproxy-setup.yml
```

allow name_bind access

```console
setsebool -P haproxy_connect_any 1
```

## Installing an NFS server on the bastion node

> Note - use these instructions if mounting a separate drive on the bastion node for NFS storage

1. Add a new hard disk to your virtual machine through either the ESXi or vSphere interface

1. Confirm that the hard disk has been added by running

```console
fdisk -l
```

1. Update the `vars/nfs-config.yml` configuration file with your nfs configuration.

2. Run the playbook below to configure an NFS server in the bastion node

```console
ansible-playbook tasks/nfs-server-setup.yml
```

3. Set SElinux boolean roles

```console
setsebool -P nfs_export_all_rw 1

setsebool -P nfs_export_all_ro 1
```

## Create a directory to begin holding our installation configuration files

```console
mkdir ~/ocp-install-wd/cluster-configs
```

## Managing NTP with Chrony

You may already have your ESXi host clocks synced with an NTP server already.

Here I provide an example of how Chrony can be used to sync the cluster nodes with an NTP server.

To sync the clocks, we will need to generate machine configuration.  We will then use those machine configuration files to spin you you cluster nodes.

I've included a playbook to help you generate the chrony machine config files, should you need them.

```console
ansible-playbook tasks/chrony-gen-mc.yml
```

The playbook creates a new folder in your current working directory with two chrony configuration files, one for the master nodes and one for the worker nodes. Move the files to your install configs folder

```console
mv machineconfig ~/ocp-install-wd/cluster-configs
```

## Generating an SSH private key

Official Documentation: [Generating an SSH private key and adding it to the agent](https://docs.openshift.com/container-platform/4.5/installing/installing_vsphere/installing-vsphere.html#ssh-agent-using_installing-vsphere)

Generate your ssh key

```console
ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa
```

## Create the install-config file

**Official Documentation (requires vCenter):** [Manually creating the installation configuration file](https://docs.openshift.com/container-platform/4.5/installing/installing_vsphere/installing-vsphere.html#installation-initializing-manual_installing-vsphere)

**Official Documentation (generic approach):** [Manually creating the installation configuration file](https://docs.openshift.com/container-platform/4.5/installing/installing_bare_metal/installing-bare-metal.html#installation-initializing-manual_installing-bare-metal)

Your first option offical docs have a sample file you may use as a starting point.

If you choose to use the install-config file generated by the playbook included in this repository, it is still recommended that you review the official documentation (see above) for a description of each of the name-value pairs in this configuration file.

**To run the included playbook:**

```console
ansible-playbook tasks/install-config-setup.yml
```

Move install config file to the cluster config directory

```console
mv install-config.yaml ~/ocp-install-wd/cluster-configs
```

## Create the manifest files

> **Note** This process will replace your install-config file.  You should make a copy of that file if you intend on reusing the configuration file in future deployments

```console
openshift-install create manifests --dir ~/ocp-install-wd/cluster-configs
```

Prevent pods from being scheduled on the control plane nodes

```console
sed -i 's/mastersSchedulable: true/mastersSchedulable: false/g' ~/ocp-install-wd/cluster-configs/manifests/cluster-scheduler-02-config.yml
```

Download the 

## Create the ignition configs

```bash
openshift-install create ignition-configs --dir ~/ocp-install-wd/cluster-configs
```

Copy the ignition files to the ignition directory on our webserver
```console
cp ~/ocp-install-wd/cluster-configs/*.ign /var/www/html/ignition/
restorecon -vR /var/www/html/
chmod o+r /var/www/html/ignition/*.ign

```

## Add the coreos image to the web server

Download the coreos image
```
wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.5/4.5.6/rhcos-4.5.6-x86_64-metal.x86_64.raw.gz
```

Move it to the apache web server
```
mv rhcos-4.5.6-x86_64-metal.x86_64.raw.gz /var/www/html/install/bios.raw.gz
```

## Create a single iso to boot your cluster nodes from

**TODO: Automate**

```console
cd ~/
git clone -b OCP4.5 https://github.com/chuckersjp/coreos-iso-maker
cd coreos-iso-maker
```

update group_vars/all.yml
update inventory.yml

```console
cp /var/www/html/install/bios.raw.gz /var/www/html/
cp /var/www/html/ignition/*.ign /var/www/html/
ln -s /var/www/html/worker.ign /var/www/html/workers.ign
ln -s /var/www/html/master.ign /var/www/html/masters.ign
chmod o+r /var/www/html/*
restorecon -vR /var/www/html
```

```console
ansible-playbook playbook-single.yml
```
<!-- cp /tmp/rhcos-install-cluster.iso /var/www/html -->

This iso can now be used to create all of your cluster nodes.

First create and turn your boostrap VM on
As the bootstrap VM is building, create the control plane nodes.

When the control plan

---

## Monitoring the Deployment

You may monitor the installation process through the HAProxy 9000 port
> :warning: It is strongly recommended that you close port 9000 immediately after the installation following the installation if the bastion node is accessible form the public domain.

### Monitoring the bootstrap process

From the bation node, monitor the completion of the bootstrap node and control planes:

```console
openshift-install --dir ~/ocp-install-wd/cluster-configs/ wait-for bootstrap-complete --log-level=debug
```

### When the control planes have been fully created

1. You may shutdown the bootstrap node and delete the VM from your VMware console.

1. Remove all references to the bootstrap node from the HAProxy config

```console
vim /etc/haproxy/haproxy.cfg
```

1. Monitor the completion of the final stage of the installation process

```console
openshift-install --dir ~/ocp-install-wd/cluster-configs/ wait-for install-complete
```

1. Periodically check for any CSRs that require approval and approve

```console
oc get csr

oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs oc adm certificate approve
```

1. Make note of the OpenShift console URL and credentials from the output of the installation

# Post OpenShift Deployment Tasks

Once OpenShift has been deployed, the following optional tasks will help you prepare your cluster for application deployments

## Test 'oc' command

Copy your cluster authentication credentials to avoid having to continually export the configuration files

```console
cp ~/ocp-install-wd/cluster-configs/auth/kubeconfig ~/.kube/config
```

Test oc command

```console
oc whoami

oc get nodes
```

## NFS Config

The included playbook will configure your cluster to use the nfs volume we configured earlier - it concludes by creating an nfs client provisioner that is used to create a persistent volume for your cluster's registry.  

1. Deploy the nfs provisioner

    ```console
    ansible-playbook tasks/nfs-ocp-setup.yml
    ```

1. Test the nfs provisoner

    ```console
    ansible-playbook tasks/test-nfs-ocp-setup.yml
    ```

You should now able to see the persistent volume successfully bound in the Storage -> Persistent Volumes:

![p](ref/images/nfs-ocp-test-pv-success.png)

1. Delete the test pod and persistent volume

    ```console
    oc delete -f /usr/local/src/nfs-test-pod.yaml
    oc delete -f /usr/local/src/nfs-pvc-test.yaml
    ``

## Configuring the registry

Check that with "oc get pv" and "oc get pvc -n openshift-image-registry"
Check the status by watching "oc get pods -n openshift-image-registry"

This playbook creates a PVC for the image registry operator and updates the exsiting operator's configuration to this NFS volume

```console
ansible-playbook tasks/ocp-image-registry-setup.yml
```

(Optional) Enable the Image Registry default route

```console
oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{"spec":{"defaultRoute":true}}'
```

## Updating the cluster certificate




# Extras

## [Cockpit](https://cockpit-project.org/) - Integrated GNU/Linux Interface  

### Installing https://cockpit-project.org/running.html

> **Note for Centos 8 users**  
> The package is already included with Centos8. To enable it, use the following command:
> `sudo systemctl enable --now cockpit.socket'

## Working with the openshift-install command

```console
openshift-install explain installationconfig
openshift-install explain installationconfig.platform
openshift-install explain installconfig.platform.vsphere.clusterOSImage
```

## VIM configs

``` console
cat <<EOT >> ~/.vimrc
syntax on
set nu et ai sts=0 ts=2 sw=2 list hls
EOT
```

# Troubleshooting

View Ansible local configuration settings

```bash
ansible all -i localhost, -m setup -c local localhost
```

View failed systemd process logs

```console
journalctl -xe | grep SERVICE_NAME
```



## Ansible Playbooks

To view the output of each of the playbook's tasks, execute the playbook with the verbose options

```bash
ansible-playbook [playbook] -vvvvv
```

## test NFS shares

```console
sudo mkdir /test
mount -t nfs ocp-svc:/shares/registry /test
touch /test/it-works
rm /test/it-works
umount /test
```

# Redeploying the cluster

## Delete the Apache server

```console
yum list installed "httpd*"

yum remove "httpd*" -y

rm -rf /var/www

rm -rf /etc/httpd

rm -rf /usr/lib64/httpd

userdel -r apache

grep "apache" /etc/passwd

systemctl status httpd
```

# Delete the NFS auto provisioner from ocp

    ```console
    ansible-playbook tasks/nfs-ocp-remove.yml
    ```
