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
resource "helm_release" "linkerd_control_plane" {
  name       = "linkerd-control-plane"
  repository = "https://helm.linkerd.io/stable"
  chart      = "linkerd-control-plane"
  namespace  = kubernetes_namespace.linkerd.metadata[0].name
  version    = "1.16.10"

  depends_on = [helm_release.linkerd_crds]

  set {
    name  = "identity.issuer.tls.crtPEM"
    value = file("${path.module}/issuer.crt")
  }
  set {
    name  = "identity.issuer.tls.keyPEM"
    value = file("${path.module}/issuer.key")
  }
  set {
    name  = "identityTrustAnchorsPEM"
    value = file("${path.module}/trust-anchor.crt")
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

# 3. Inject Linkerd into the Online Boutique namespace
# We do this by adding an annotation to the namespace.
# However, for already running pods, we might need to restart them.
resource "kubernetes_annotations" "boutique_linkerd_injection" {
  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = "online-boutique"
  }
  annotations = {
    "linkerd.io/inject" = "enabled"
  }
  force = true
}

