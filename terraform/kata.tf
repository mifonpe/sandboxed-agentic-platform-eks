# Kata system namespace
resource "kubernetes_namespace_v1" "kata_system" {
  metadata {
    name = local.kata_namespace
    labels = {
      name = local.kata_namespace
    }
  }

  depends_on = [module.eks]
}

# Namespace for agent sandbox pods (opencode)
resource "kubernetes_namespace_v1" "agents" {
  metadata {
    name = local.agents_namespace
    labels = {
      name = local.agents_namespace
    }
  }

  depends_on = [module.eks]
}
