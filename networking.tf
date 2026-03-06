resource "kubernetes_namespace" "linkerd" {
  metadata {
    name = "linkerd"
    labels = {
      "linkerd.io/is-control-plane"          = "true"
      "config.linkerd.io/admission-webhooks" = "disabled"
    }
  }
}

# 1. Install Linkerd CRDs
# 1. Install Linkerd CRDs
resource "helm_release" "linkerd_crds" {
  name       = "linkerd-crds"
  repository = "https://helm.linkerd.io/stable"
  chart      = "linkerd-crds"
  namespace  = kubernetes_namespace.linkerd.metadata[0].name
  version    = "1.8.0"

  # Skip CRDs that might conflict with existing Gateway API installations (like Traefik)
  # Linkerd 2.11+ uses Gateway API, and linkerd-crds might try to install them.
  # If they exist, we use force_update or handle it via chart values if possible.
  force_update = true
}

# 2. Install Linkerd Control Plane
# Certs are sourced from the Cert-Manager-managed secret (Zero secrets on disk).
# The 'linkerd-identity-issuer' Certificate resource in linkerd-certs.yaml
# populates the 'linkerd-identity-issuer-secret' K8s secret automatically.
data "kubernetes_secret" "linkerd_identity_issuer" {
  metadata {
    name      = "linkerd-identity-issuer-secret"
    namespace = kubernetes_namespace.linkerd.metadata[0].name
  }
  depends_on = [helm_release.linkerd_crds]
}

resource "helm_release" "linkerd_control_plane" {
  name       = "linkerd-control-plane"
  repository = "https://helm.linkerd.io/stable"
  chart      = "linkerd-control-plane"
  namespace  = kubernetes_namespace.linkerd.metadata[0].name
  version    = "1.16.10"

  depends_on = [helm_release.linkerd_crds, data.kubernetes_secret.linkerd_identity_issuer]

  set {
    name  = "identity.issuer.tls.crtPEM"
    value = lookup(data.kubernetes_secret.linkerd_identity_issuer.data, "tls.crt", "")
  }
  set {
    name  = "identity.issuer.tls.keyPEM"
    value = lookup(data.kubernetes_secret.linkerd_identity_issuer.data, "tls.key", "")
  }
  set {
    name  = "identityTrustAnchorsPEM"
    value = lookup(data.kubernetes_secret.linkerd_identity_issuer.data, "ca.crt", "")
  }

  set {
    name  = "proxyInjector.podLabels.sre-privileged-access"
    value = "true"
  }

  set {
    name  = "destination.podLabels.sre-privileged-access"
    value = "true"
  }
}

# 3. Distributed Zero-Trust Policy (Server & ServerAuthorization)
# Only allow frontend to talk to productcatalogservice
resource "kubernetes_manifest" "productcatalog_server" {
  manifest = {
    apiVersion = "policy.linkerd.io/v1beta1"
    kind       = "Server"
    metadata = {
      name      = "productcatalog-grpc"
      namespace = "online-boutique"
    }
    spec = {
      podSelector = {
        matchLabels = { "app" = "productcatalogservice" }
      }
      port          = 3550
      proxyProtocol = "gRPC"
    }
  }
  depends_on = [helm_release.linkerd_crds]
}

resource "kubernetes_manifest" "authz_frontend_to_productcatalog" {
  manifest = {
    apiVersion = "policy.linkerd.io/v1alpha1"
    kind       = "ServerAuthorization"
    metadata = {
      name      = "frontend-to-productcatalog"
      namespace = "online-boutique"
    }
    spec = {
      server = { name = "productcatalog-grpc" }
      client = {
        meshTLS = {
          serviceAccounts = [{ name = "frontend" }]
        }
      }
    }
  }
  depends_on = [helm_release.linkerd_crds]
}

# Only allow loadgenerator to talk to frontend
resource "kubernetes_manifest" "frontend_server" {
  manifest = {
    apiVersion = "policy.linkerd.io/v1beta1"
    kind       = "Server"
    metadata = {
      name      = "frontend-http"
      namespace = "online-boutique"
    }
    spec = {
      podSelector = {
        matchLabels = { "app" = "frontend" }
      }
      port          = 8080
      proxyProtocol = "HTTP/1"
    }
  }
  depends_on = [helm_release.linkerd_crds]
}

resource "kubernetes_manifest" "authz_loadgen_to_frontend" {
  manifest = {
    apiVersion = "policy.linkerd.io/v1alpha1"
    kind       = "ServerAuthorization"
    metadata = {
      name      = "loadgen-to-frontend"
      namespace = "online-boutique"
    }
    spec = {
      server = { name = "frontend-server" }
      client = {
        unauthenticated = true # Frontend is external facing via LB/Ingress
      }
    }
  }
  depends_on = [helm_release.linkerd_crds]
}
