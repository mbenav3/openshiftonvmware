#!/bin/bash
nfssharedir=${nfssharedir:''} #The name of the nfs share folder in the nfs server's nfs shares directory
ocpns=${ocpns:''} # The name of the project where this nfs provisioning client should be deployed
nfsprovisionername=${nfsprovisionername:''} # The name of the nfs client provisioner

while [ $# -gt 0 ]; do

   if [[ $1 == *"--"* ]]; then
        param="${1/--/}"
        declare $param="$2"
        echo $1 $2 // Optional to see the parameter:value result
   fi

  shift
done

if [ -z "${nfssharedir}" ] || [ -z "${ocpns}" ] || [ -z "${nfsprovisionername}" ]; 
then 
	echo "Missing values: mising one of the required arguments nfssharedir | ocpns | nfsprovisionername"
	exit 254
fi

rbac=/usr/local/src/nfs-provisioner-rbac.yaml
deploy=/usr/local/src/nfs-provisioner-deployment.yaml
sc=/usr/local/src/nfs-provisioner-sc.yaml
#
export PATH=/usr/local/bin:$PATH
#
## Check openshift connection
if ! oc get project default -o jsonpath={.metadata.name} > /dev/null 2>&1 ; then
	echo "ERROR: Cannot connect to OpenShift. Are you sure you exported your KUBECONFIG path and are admin?"
	echo "" 
	exit 254
fi
#
## Check to see if the namespace exists
if [ "$(oc get project default -o jsonpath={.metadata.name})" = "${ocpns}" ]; then
	echo "ERROR: Seems like NFS provisioner is already deployed"
	exit 254
fi
#
## Check to see if required files exist
for file in ${rbac} ${deploy} ${sc}
do
	[[ ! -f ${file} ]] && echo "FATAL: File ${file} does not exist" && exit 254
done
#
## Check if the project is already there
if oc get project ${ocpns} -o jsonpath={.metadata.name} > /dev/null 2>&1 ; then
	echo "ERROR: Looks like you've already deployed the nfs-provisioner in this namespace"
	exit 254
fi
#
## Update the the deployment, storage class, and rbac manifest files before deploying to the cluster
sed -i "s/NFS_PROVISIONER_NAME/${nfsprovisionername}/" ${deploy} ${sc}
sed -i "s/NFS_PROVISIONER_NAMESPACE/${ocpns}/" ${deploy} ${rbac}

## Deploy
oc new-project ${ocpns}
oc project ${ocpns}
oc create -f ${rbac}
oc adm policy add-scc-to-user hostmount-anyuid system:serviceaccount:${ocpns}:nfs-client-provisioner
oc create -f ${deploy} -n ${ocpns}
oc create -f ${sc}
# oc annotate storageclass nfs-storage-provisioner storageclass.kubernetes.io/is-default-class="true"
# oc project default
oc rollout status deployment nfs-client-provisioner -n ${ocpns}
#
## Show some info
cat <<EOF


Deployment started; monitor the status of your deployment using "oc get pods -n ${ocpns}"

EOF
##
##
