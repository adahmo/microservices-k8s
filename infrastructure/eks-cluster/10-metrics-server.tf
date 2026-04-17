resource "helm_release" "metrics_server" {
  name = "metrics-server"

  chart      = "https://github.com/kubernetes-sigs/metrics-server/releases/download/metrics-server-helm-chart-3.12.1/metrics-server-3.12.1.tgz"
  namespace  = "kube-system"
  version    = "3.12.1"

  values = [file("${path.module}/values/metrics-server.yaml")]

  depends_on = [aws_eks_node_group.general]
}
