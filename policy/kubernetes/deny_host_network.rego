# ──────────────────────────────────────────────────────────────────────────────
# OPA/Conftest Policy: Deny Host Network (Kubernetes)
# Prevents pods from using the host network namespace.
# ──────────────────────────────────────────────────────────────────────────────
package kubernetes.deny_host_network

import rego.v1

deny contains msg if {
	input.kind == "Pod"
	input.spec.hostNetwork == true
	msg := sprintf("Pod '%s' must not use hostNetwork", [input.metadata.name])
}

deny contains msg if {
	input.kind == "Deployment"
	input.spec.template.spec.hostNetwork == true
	msg := sprintf("Deployment '%s' must not use hostNetwork in pod template", [input.metadata.name])
}

deny contains msg if {
	input.kind == "DaemonSet"
	input.spec.template.spec.hostNetwork == true
	not is_system_namespace(input.metadata.namespace)
	msg := sprintf("DaemonSet '%s' must not use hostNetwork outside system namespaces", [input.metadata.name])
}

is_system_namespace(ns) if ns == "kube-system"
is_system_namespace(ns) if ns == "linkerd"
is_system_namespace(ns) if ns == "observability"
