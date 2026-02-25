data "http" "online_boutique_manifest" {
  url = "https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/main/release/kubernetes-manifests.yaml"
}

resource "kubernetes_namespace" "boutique" {
  metadata {
    name = "online-boutique"
  }
}

resource "null_resource" "apply_manifest" {
  triggers = {
    manifest_sha = sha256(data.http.online_boutique_manifest.response_body)
  }

  provisioner "local-exec" {
    command = "kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/main/release/kubernetes-manifests.yaml -n online-boutique"
    environment = {
      KUBECONFIG = pathexpand("~/.kube/config")
    }
  }

  depends_on = [kubernetes_namespace.boutique]
}
