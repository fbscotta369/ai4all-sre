# Fix 7: NetworkPolicy — default-deny + explicit allow for online-boutique
# Implements true Zero-Trust network isolation alongside Linkerd mTLS.
resource "kubernetes_network_policy" "online_boutique_default_deny" {
  metadata {
    name      = "default-deny-all"
    namespace = kubernetes_namespace.online_boutique.metadata[0].name
  }
  spec {
    pod_selector {} # applies to ALL pods
    policy_types = ["Ingress", "Egress"]
  }
}

# Allow DNS egress from all boutique pods (required for service discovery)
resource "kubernetes_network_policy" "online_boutique_allow_dns" {
  metadata {
    name      = "allow-dns-egress"
    namespace = kubernetes_namespace.online_boutique.metadata[0].name
  }
  spec {
    pod_selector {}
    policy_types = ["Egress"]
    egress {
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
    }
  }
}

# Allow frontend to receive traffic from loadgen and ingress
resource "kubernetes_network_policy" "allow_frontend_ingress" {
  metadata {
    name      = "allow-frontend-ingress"
    namespace = kubernetes_namespace.online_boutique.metadata[0].name
  }
  spec {
    pod_selector {
      match_labels = { app = "frontend" }
    }
    policy_types = ["Ingress"]
    ingress {
      from {
        pod_selector {
          match_labels = { app = "behavioral-loadgen" }
        }
      }
    }
    ingress {
      from {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = "kube-system" }
        }
      }
    }
  }
}

# Allow intra-boutique microservice communication
resource "kubernetes_network_policy" "allow_boutique_internal" {
  metadata {
    name      = "allow-boutique-internal"
    namespace = kubernetes_namespace.online_boutique.metadata[0].name
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
    ingress {
      from {
        pod_selector {} # Any pod in the same namespace
      }
    }
    egress {
      to {
        pod_selector {} # Any pod in the same namespace
      }
    }
  }
}

# Allow boutique pods to reach Vault for secret injection
resource "kubernetes_network_policy" "allow_vault_egress" {
  metadata {
    name      = "allow-vault-egress"
    namespace = kubernetes_namespace.online_boutique.metadata[0].name
  }
  spec {
    pod_selector {}
    policy_types = ["Egress"]
    egress {
      to {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = "vault" }
        }
      }
      ports {
        port     = "8200"
        protocol = "TCP"
      }
    }
  }
}
