#!/bin/bash
ocpns=NFS_NS

rbac=/usr/local/src/nfs-auto-provisioner-rbac.yaml
deploy=/usr/local/src/nfs-auto-provisioner-deployment.yaml
sc=/usr/local/src/nfs-auto-provisioner-sc.yaml
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
## Check to see if required files exist
for file in ${rbac} ${deploy} ${sc}
do
	[[ ! -f ${file} ]] && echo "FATAL: File ${file} does not exist" && exit 254
done

## Delete
oc delete -f ${rbac}
oc delete -f ${deploy}
oc delete -f ${sc}

 oc delete project ${ocpns}

#
cat <<EOF


Deployment started; monitor the status of your deployment using "oc get pods -n ${ocpns}"

EOF
##
##
