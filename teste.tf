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
 
