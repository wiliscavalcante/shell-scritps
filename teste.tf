resource "helm_release" "kube-prometheus" {
  depends_on = [
    helm_release.external-dns,
    helm_release.aws-efs-csi-driver
  ]
  name             = "kube-prometheus-stack"
  namespace        = "monitoring-system"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  create_namespace = true
  wait             = true
  timeout          = 1800
  version          = var.eks_charts_version[var.eks_cluster_version].prometheus

  set {
    name  = "grafana.adminPassword"
    value = random_password.password.result
  }
  set {
    name  = "grafana.additionalDataSources[0].name"
    value = "Loki"
  }
  set {
    name  = "grafana.additionalDataSources[0].type"
    value = "loki"
  }
  set {
    name  = "grafana.additionalDataSources[0].url"
    value = "http://loki-stack.monitoring-system:3100/"
  }
  set {
    name  = "grafana.initChownData.enabled"
    value = "false"
  }
  set {
    name  = "grafana.persistence.enabled"
    value = "true"
  }
  set {
    name  = "grafana.persistence.storageClassName"
    value = var.efs_enabled ? "efs-sc" : "gp2"
  }
  set {
    name  = "alertmanager.alertmanagerSpec.nodeSelector.Worker"
    value = "infra"
  }
  set {
    name  = "alertmanager.alertmanagerSpec.tolerations[0].key"
    value = "dedicated"
  }
  set {
    name  = "alertmanager.alertmanagerSpec.tolerations[0].operator"
    value = "Equal"
  }
  set {
    name  = "alertmanager.alertmanagerSpec.tolerations[0].value"
    value = "infra"
  }
  set {
    name  = "alertmanager.alertmanagerSpec.tolerations[0].effect"
    value = "NoSchedule"
  }
  set {
    name  = "grafana.nodeSelector.Worker"
    value = "infra"
  }
  set {
    name  = "grafana.tolerations[0].key"
    value = "dedicated"
  }
  set {
    name  = "grafana.tolerations[0].operator"
    value = "Equal"
  }
  set {
    name  = "grafana.tolerations[0].value"
    value = "infra"
  }
  set {
    name  = "grafana.tolerations[0].effect"
    value = "NoSchedule"
  }
  set {
    name  = "prometheusOperator.admissionWebhooks.patch.nodeSelector.Worker"
    value = "infra"
  }
  set {
    name  = "prometheusOperator.admissionWebhooks.patch.tolerations[0].key"
    value = "dedicated"
  }
  set {
    name  = "prometheusOperator.admissionWebhooks.patch.tolerations[0].operator"
    value = "Equal"
  }
  set {
    name  = "prometheusOperator.admissionWebhooks.patch.tolerations[0].value"
    value = "infra"
  }
  set {
    name  = "prometheusOperator.admissionWebhooks.patch.tolerations[0].effect"
    value = "NoSchedule"
  }
  set {
    name  = "prometheusOperator.nodeSelector.Worker"
    value = "infra"
  }
  set {
    name  = "prometheusOperator.tolerations[0].key"
    value = "dedicated"
  }
  set {
    name  = "prometheusOperator.tolerations[0].operator"
    value = "Equal"
  }
  set {
    name  = "prometheusOperator.tolerations[0].value"
    value = "infra"
  }
  set {
    name  = "prometheusOperator.tolerations[0].effect"
    value = "NoSchedule"
  }
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = var.efs_enabled ? "efs-sc" : "gp2"
  }
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]"
    value = "ReadWriteOnce"
  }
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "128Gi"
  }
  set {
    name  = "prometheus.prometheusSpec.nodeSelector.Worker"
    value = "infra"
  }
  set {
    name  = "prometheus.prometheusSpec.scrapeInterval"
    value = "30s"
  }
  set {
    name  = "prometheus.prometheusSpec.evaluationInterval"
    value = "30s"
  }
  set {
    name  = "prometheus.prometheusSpec.tolerations[0].key"
    value = "dedicated"
  }
  set {
    name  = "prometheus.prometheusSpec.tolerations[0].operator"
    value = "Equal"
  }
  set {
    name  = "prometheus.prometheusSpec.tolerations[0].value"
    value = "infra"
  }
  set {
    name  = "prometheus.prometheusSpec.tolerations[0].effect"
    value = "NoSchedule"
  }
  set {
    name  = "kubeStateMetrics.nodeSelector.Worker"
    value = "infra"
  }
  set {
    name  = "kubeStateMetrics.tolerations[0].key"
    value = "dedicated"
  }
  set {
    name  = "kubeStateMetrics.tolerations[0].operator"
    value = "Equal"
  }
  set {
    name  = "kubeStateMetrics.tolerations[0].value"
    value = "infra"
  }
  set {
    name  = "kubeStateMetrics.tolerations[0].effect"
    value = "NoSchedule"
  }
  set {
    name  = "alertmanager.alertmanagerSpec.resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "alertmanager.alertmanagerSpec.resources.requests.memory"
    value = "256Mi"
  }
  set {
    name  = "prometheusOperator.resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "prometheusOperator.resources.requests.memory"
    value = "256Mi"
  }
  set {
    name  = "prometheus.prometheusSpec.resources.requests.memory"
    value = "5Gi"
  }
  values = [
    yamlencode({
      kube-state-metrics = {
        collectors = [
          "certificatesigningrequests",
          "configmaps",
          "cronjobs",
          "daemonsets",
          "deployments",
          "endpoints",
          "horizontalpodautoscalers",
          "ingresses",
          "jobs",
          "leases",
          "limitranges",
          "mutatingwebhookconfigurations",
          "namespaces",
          "networkpolicies",
          "nodes",
          "persistentvolumeclaims",
          "persistentvolumes",
          "poddisruptionbudgets",
          "pods",
          "replicasets",
          "replicationcontrollers",
          "resourcequotas",
          "secrets",
          "services",
          "statefulsets",
          "storageclasses",
          "validatingwebhookconfigurations",
          "volumeattachments"

        ]
      }
    })
  ]
}
resource "helm_release" "loki-stack" {
  depends_on = [
    helm_release.kube-prometheus
  ]
  name       = "loki-stack"
  namespace  = "monitoring-system"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  timeout    = 600
  version    = var.eks_charts_version[var.eks_cluster_version].loki
  set {
    name  = "loki.config.schema_config.configs[0].from"
    value = "2022-04-03"
  }
  set {
    name  = "loki.image.tag"
    value = "2.9.8"
  }
  set {
    name  = "loki.config.schema_config.configs[0].store"
    value = "boltdb-shipper"
  }
  set {
    name  = "loki.config.schema_config.configs[0].object_store"
    value = "s3"
  }
  set {
    name  = "loki.config.schema_config.configs[0].schema"
    value = "v11"
  }
  set {
    name  = "loki.config.schema_config.configs[0].index.prefix"
    value = "index_"
  }
  set {
    name  = "loki.config.schema_config.configs[0].index.period"
    value = "24h"
  }
  set {
    name  = "loki.config.storage_config.boltdb_shipper.active_index_directory"
    value = "/data/loki/index"
  }
  set {
    name  = "loki.config.storage_config.boltdb_shipper.cache_location"
    value = "/data/loki/index_cache"
  }
  set {
    name  = "loki.config.storage_config.boltdb_shipper.shared_store"
    value = "s3"
  }
  set {
    name  = "loki.config.storage_config.aws.s3"
    value = aws_s3_bucket.eks_log_bucket.id
  }
  set {
    name  = "loki.config.storage_config.aws.s3forcepathstyle"
    value = "true"
  }
  set {
    name  = "loki.config.storage_config.aws.region"
    value = data.aws_region.current.name
  }
  set {
    name  = "loki.config.storage_config.aws.endpoint"
    value = "s3.${data.aws_region.current.name}.amazonaws.com"
  }
  set {
    name  = "loki.config.compactor.working_directory"
    value = "/data/compactor"
  }
  set {
    name  = "loki.config.compactor.compaction_interval"
    value = "5m"
  }
  set {
    name  = "loki.config.compactor.shared_store"
    value = "s3"
  }
  set {
    name  = "loki.resources.requests.cpu"
    value = "200m"
  }
  set {
    name  = "loki.resources.requests.memory"
    value = "2Gi"
  }
  set {
    name  = "loki.resources.limits.cpu"
    value = "300m"
  }
  set {
    name  = "loki.resources.limits.memory"
    value = "5Gi"
  }
  set {
    name  = "loki.nodeSelector.Worker"
    value = "infra"
  }
  set {
    name  = "loki.tolerations[0].key"
    value = "dedicated"
  }
  set {
    name  = "loki.tolerations[0].operator"
    value = "Equal"
  }
  set {
    name  = "loki.tolerations[0].value"
    value = "infra"
  }
  set {
    name  = "loki.tolerations[0].effect"
    value = "NoSchedule"
  }
  set {
    name  = "promtail.tolerations[0].operator"
    value = "Exists"
  }
}
resource "kubectl_manifest" "flagger-crd" {
  depends_on = [
    helm_release.loki-stack
  ]
  yaml_body = data.http.flagger_crd_manifest.response_body
}


###############################
#backend.tf

terraform {
  required_version = ">= 1.0"
  backend "s3" {}
}

#data.tf

data "aws_caller_identity" "current" {}

#main.tf

locals {
  cache_behaviors = merge([
    for mf in var.microfronts : {
      for path in mf.path_prefixes :
      "${mf.name}-${replace(path, "/", "-")}" => {
        origin_id    = mf.name
        path_pattern = path
      }
    } if mf.name != "default-origin"
  ]...)
}


resource "aws_cloudfront_origin_access_control" "oac" {
  for_each                          = { for mf in var.microfronts : mf.name => mf }
  name                              = each.key
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cloudfront" {
  aliases             = var.domain_name != "" ? [var.domain_name] : []
  comment             = "AgriFrontEnd Hub - ${title(var.environment)}"
  default_root_object = "index.html"
  enabled             = true
  http_version        = "http2"
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"
  retain_on_delete    = false
  wait_for_deployment = true

  # Origem padrão obrigatória
  origin {
    domain_name              = aws_s3_bucket.microfront["default-origin"].bucket_regional_domain_name
    origin_id                = "default-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac["default-origin"].id
  }

  # Demais origens
  dynamic "origin" {
    for_each = { for k, v in aws_s3_bucket.microfront : k => v if k != "default-origin" }
    content {
      domain_name              = origin.value.bucket_regional_domain_name
      origin_id                = origin.key
      origin_access_control_id = aws_cloudfront_origin_access_control.oac[origin.key].id
    }
  }

  # Comportamento default (aponta para o bucket neutro)
  default_cache_behavior {
    target_origin_id           = "default-origin"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    response_headers_policy_id = "eaab4381-ed33-4a86-88ca-d9558dc6cd63"
    min_ttl                    = 0
    default_ttl                = 3600
    max_ttl                    = 86400
  }

  # Comportamentos por path_pattern (protocols/*, dashboard/*, etc.)
  dynamic "ordered_cache_behavior" {
    for_each = local.cache_behaviors
    content {
      path_pattern               = ordered_cache_behavior.value.path_pattern
      target_origin_id           = ordered_cache_behavior.value.origin_id
      viewer_protocol_policy     = "redirect-to-https"
      allowed_methods            = ["GET", "HEAD"]
      cached_methods             = ["GET", "HEAD"]
      cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6"
      response_headers_policy_id = "eaab4381-ed33-4a86-88ca-d9558dc6cd63"
      min_ttl                    = 0
      default_ttl                = 3600
      max_ttl                    = 86400
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  #  viewer_certificate {
  #    acm_certificate_arn            = var.certificate_arn
  #    cloudfront_default_certificate = false
  #    minimum_protocol_version       = "TLSv1.2_2021"
  #    ssl_support_method             = "sni-only"
  #  }
  viewer_certificate {
    acm_certificate_arn            = var.certificate_arn != "" ? var.certificate_arn : null
    ssl_support_method             = var.certificate_arn != "" ? "sni-only" : null
    minimum_protocol_version       = var.certificate_arn != "" ? "TLSv1.2_2021" : null
    cloudfront_default_certificate = var.certificate_arn == "" ? true : false
  }

  tags = {
    Environment  = var.environment
    Project      = var.project_name
    BusinessUnit = var.business_unit
    ManagedBy    = "Terraform"
  }
}

#provider.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.0.0-beta2"
    }
  }
}

provider "aws" {
  region = "sa-east-1"
}

#s3.tf

locals {
  required_tags = {
    Data_Type      = "N/A"
    Data_Category  = "N/A"
    Asset_Category = "Embedded"
    Environment    = var.environment
    Project        = var.project_name
    BusinessUnit   = var.business_unit
    ManagedBy      = "Terraform"
  }
}

resource "aws_s3_bucket" "microfront" {
  for_each = { for mf in var.microfronts : mf.name => mf }

  bucket = lower("${each.key}-mfe-${var.environment}")

  force_destroy = true

  tags = merge(
    local.required_tags,
    {
      AppID      = var.app_gearr_id
      CostString = var.cost_center
    },
    lookup(var.microfront_tags, each.key, {})
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "microfront_encryption" {
  for_each = aws_s3_bucket.microfront

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "microfront_policy" {
  for_each = aws_s3_bucket.microfront

  bucket = each.value.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal",
        Effect    = "Allow",
        Principal = { Service = "cloudfront.amazonaws.com" },
        Action    = "s3:GetObject",
        Resource  = ["arn:aws:s3:::${each.value.id}/*"],
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${aws_cloudfront_distribution.cloudfront.id}"
          }
        }
      }
    ]
  })
}

#variables-dev.tfvars

project_name    = "AgriFrontEnd Hub"
environment     = "dev"
domain_name     = ""
certificate_arn = ""
business_unit   = "Agribusiness"
app_gearr_id    = "DEFAULT-APPID"
cost_center     = "DEFAULT-COST"

microfronts = [
  {
    name          = "default-origin"
    path_prefixes = ["/"]
  },
  {
    name          = "pb-protocols"
    path_prefixes = ["/protocols/*"]
  },
  {
    name          = "pb-mfe1"
    path_prefixes = ["/mfe1/*"]
  },
  {
    name          = "pb-mfe2"
    path_prefixes = ["/mfe2/*"]
  },
  {
    name          = "pb-mfe3"
    path_prefixes = ["/mfe3/*"]
  }
]

microfront_tags = {
  "default-origin" = {
    AppID        = "PLACEHOLDER"
    CostString   = "N/A"
    DataCategory = "General"
  },
  "pb-protocols" = {
    AppID        = "PB-PROTOCOLS"
    CostString   = "AGRO001"
    DataCategory = "Restricted"
  }
}
 #variables.tf

variable "environment" {
  type        = string
  description = "Ambiente (ex: dev, uat, prod)"
}

variable "project_name" {
  type        = string
  description = "Nome do projeto, usado nas tags e na descrição do CloudFront"
}

#variable "domain_name" {
#  type        = string
#  description = "Domínio do CloudFront (ex: dev.brain.app)"
#}
variable "domain_name" {
  type        = string
  description = "Domínio customizado (ex: hub.brain.app). Deixe vazio em dev"
  default     = ""
}

#variable "certificate_arn" {
#  type        = string
#  description = "ARN do certificado ACM (deve estar na região us-east-1)"
#}
variable "certificate_arn" {
  type        = string
  description = "ARN do certificado ACM em us-east-1 para uso em domínios customizados"
  default     = "" # Em dev, deixa em branco
}
variable "business_unit" {
  type        = string
  description = "Nome da unidade de negócio (ex: Agribusiness)"
}

variable "app_gearr_id" {
  type        = string
  description = "Valor default da tag AppID (pode ser sobrescrito por microfrontend)"
}

variable "cost_center" {
  type        = string
  description = "Valor default da tag CostString (pode ser sobrescrito por microfrontend)"
}

variable "microfronts" {
  type = list(object({
    name          = string
    path_prefixes = list(string)
  }))
  description = "Lista de micro frontends com seus nomes e path prefixes"
}

variable "microfront_tags" {
  type        = map(map(string))
  default     = {}
  description = "Mapeamento de sobrescrita de tags por microfrontend (por nome)"
}
 
