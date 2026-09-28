terraform {
  required_version = ">= 1.10" # For OpenTofu compatibility
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
  }
}

provider "kubernetes" {
  config_path = abspath("${path.root}/../../kubeconfig")
}

locals {
  services = {
    api = {
      env = { ORDERS_URL = "http://orders:8080" }
    }
    orders = {
      env = { ERROR_RATE = "0.05" }
    }
  }
}

resource "kubernetes_namespace_v1" "apps" {
  metadata {
    name = "apps"
  }
}

resource "kubernetes_deployment_v1" "service" {
  for_each = local.services

  metadata {
    name      = each.key
    namespace = kubernetes_namespace_v1.apps.metadata[0].name
    labels    = { "app.kubernetes.io/name" = each.key }
  }

  spec {
    replicas = 2
    selector {
      match_labels = { "app.kubernetes.io/name" = each.key }
    }
    template {
      metadata {
        labels = { "app.kubernetes.io/name" = each.key }
      }
      spec {
        container {
          name              = each.key
          image             = "${each.key}:${var.image_tag}"
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = 8080
          }

          dynamic "env" {
            for_each = merge(each.value.env, {
              OTEL_EXPORTER_OTLP_ENDPOINT = "http://tempo.monitoring:4317"
            })
            content {
              name  = env.key
              value = env.value
            }
          }

          resources {
            requests = { cpu = "50m", memory = "32Mi" }
            limits   = { memory = "64Mi" }
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = "http"
            }
          }
          readiness_probe {
            http_get {
              path = "/healthz"
              port = "http"
            }
            period_seconds = 5
          }

          security_context {
            run_as_non_root            = true
            read_only_root_filesystem  = true
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "service" {
  for_each = local.services

  metadata {
    name      = each.key
    namespace = kubernetes_namespace_v1.apps.metadata[0].name
    labels    = { "app.kubernetes.io/name" = each.key }
  }
  spec {
    selector = { "app.kubernetes.io/name" = each.key }
    port {
      name        = "http"
      port        = 8080
      target_port = "http"
    }
  }
}

resource "kubernetes_manifest" "service_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "apps"
      namespace = kubernetes_namespace_v1.apps.metadata[0].name
    }
    spec = {
      selector = {
        matchExpressions = [{
          key      = "app.kubernetes.io/name"
          operator = "In"
          values   = keys(local.services)
        }]
      }
      endpoints = [{ port = "http", interval = "15s" }]
    }
  }
}

resource "kubernetes_deployment_v1" "loadgen" {
  metadata {
    name      = "loadgen"
    namespace = kubernetes_namespace_v1.apps.metadata[0].name
  }
  spec {
    selector {
      match_labels = { "app.kubernetes.io/name" = "loadgen" }
    }
    template {
      metadata {
        labels = { "app.kubernetes.io/name" = "loadgen" }
      }
      spec {
        container {
          name    = "loadgen"
          image   = "curlimages/curl:8.16.0"
          command = ["sh", "-c", "while true; do curl -s -o /dev/null http://api:8080/orders; sleep 0.2; done"]
          resources {
            requests = { cpu = "10m", memory = "16Mi" }
            limits   = { memory = "32Mi" }
          }
        }
      }
    }
  }
}
