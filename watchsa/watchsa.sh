#!/bin/bash

# The NAMESPACE variable should be set in the environent using
# the downward api [1] in the deployment manifest.
#
# [1]: https://kubernetes.io/docs/tasks/inject-data-application/environment-variable-expose-pod-information/
if [[ -z $NAMESPACE ]]; then
	echo "ERROR: \$NAMESPACE is not set" >&2
	exit 1
fi

_oc() {
	oc -n "${NAMESPACE}" "$@"
}

while :; do
	# watch for service account changes (but this command can fail, which is why we have the outer loop
	# with a sleep at the end)
	_oc get sa -o name --watch | while read qualname; do
		# The `-o name` format returns `<type>/<name>`. Here we extract just the
		# name component.
		name="${qualname##*/}"

		# Ignore serviceaccounts that don't match our expected pattern. This would need
		# to be updated for your actual use case.
		[[ $name = example-app* ]] || continue

		echo "sa: $name"

		# Check if the serviceaccount exists. If it does, we grant it the necessary role. If
		# it does not, it was deleted to we revoke the permission.
		if _oc get sa "${name}" > /dev/null 2>&1; then
			# serviceaccount created
			echo "  add role"
			_oc policy add-role-to-user allow-personality-scc -z "$name" --rolebinding-name allow-personality-scc
		else
			# serviceaccount deleted
			echo "  remove role"
			if _oc get rolebinding allow-personality-scc > /dev/null 2>&1; then
				_oc policy remove-role-from-user allow-personality-scc -z "$name" --rolebinding-name allow-personality-scc
			fi
		fi
	done

	sleep 5
done
