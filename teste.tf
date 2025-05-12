# Lambda.tf

### Lambda@Edge function for CloudFront public access restriction
resource "aws_lambda_function" "incapsula_whitelist" {
  depends_on = [aws_cloudwatch_log_group.incapsula_whitelist_log_group]
  provider   = aws.us1

  function_name = local.lambda_name
  filename      = "${path.module}/resources/experian-incapsula-whitelist.zip"
  role          = aws_iam_role.lambda_invoke.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  publish       = true

  tags = {
    Environment  = local.env
    AppID        = var.app_gearr_id
    CostString   = var.cost_center
    Project      = var.project_name
    BusinessUnit = var.business_unit
    ManagedBy    = "Terraform"
  }
}

resource "aws_cloudwatch_log_group" "incapsula_whitelist_log_group" {
  name              = "/aws/lambda/${local.lambda_name}"
  retention_in_days = 14
  lifecycle {
    prevent_destroy = false
  }
}

# main.tf

### CloudFront Provisioning

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = aws_s3_bucket.s3_bucket.bucket_regional_domain_name
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_control" "oac_data" {
  count                             = var.app_type == "WEB" ? 1 : 0
  name                              = aws_s3_bucket.s3_data_bucket[count.index].bucket_regional_domain_name
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cloudfront" {
  depends_on = [aws_lambda_function.incapsula_whitelist]

  aliases             = [local.domain]
  comment             = "[${upper(var.environment)}] ${local.domain}"
  default_root_object = "index.html"
  enabled             = true
  http_version        = "http2"
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"
  retain_on_delete    = false
  wait_for_deployment = true

  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = aws_s3_bucket.s3_bucket.id
    cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    response_headers_policy_id = "eaab4381-ed33-4a86-88ca-d9558dc6cd63"
    viewer_protocol_policy     = "redirect-to-https"
    min_ttl                    = 0
    default_ttl                = 3600
    max_ttl                    = 86400

    lambda_function_association {
      event_type   = "origin-request"
      lambda_arn   = aws_lambda_function.incapsula_whitelist.qualified_arn
      include_body = true
    }

  }

  dynamic "ordered_cache_behavior" {
    for_each = aws_s3_bucket.s3_data_bucket
    content {
      allowed_methods            = ["GET", "HEAD"]
      cached_methods             = ["GET", "HEAD"]
      path_pattern               = "/data/*"
      target_origin_id           = aws_s3_bucket.s3_data_bucket[0].id
      cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6"
      response_headers_policy_id = "eaab4381-ed33-4a86-88ca-d9558dc6cd63"
      viewer_protocol_policy     = "redirect-to-https"
      min_ttl                    = 0
      default_ttl                = 3600
      max_ttl                    = 86400

      lambda_function_association {
        event_type   = "origin-request"
        lambda_arn   = aws_lambda_function.incapsula_whitelist.qualified_arn
        include_body = true
      }

    }
  }

  origin {
    domain_name              = aws_s3_bucket.s3_bucket.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.s3_bucket.id
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  dynamic "origin" {
    for_each = aws_s3_bucket.s3_data_bucket
    content {
      domain_name              = aws_s3_bucket.s3_data_bucket[0].bucket_regional_domain_name
      origin_access_control_id = aws_cloudfront_origin_access_control.oac_data[0].id
      origin_id                = aws_s3_bucket.s3_data_bucket[0].id
    }
  }

  restrictions {
    geo_restriction {
      locations        = []
      restriction_type = "none"
    }
  }

  custom_error_response {
    error_caching_min_ttl = 0
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
  }

  custom_error_response {
    error_caching_min_ttl = 0
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
  }

  custom_error_response {
    error_caching_min_ttl = 0
    error_code            = 500
    response_code         = 200
    response_page_path    = "/index.html"
  }

  viewer_certificate {
    acm_certificate_arn            = var.certificate_arn
    cloudfront_default_certificate = false
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }

  tags = {
    Environment  = local.env
    AppID        = var.app_gearr_id
    CostString   = var.cost_center
    Project      = var.project_name
    BusinessUnit = var.business_unit
    ManagedBy    = "Terraform"
  }

}

# output.tf

output "app_bucket_name" {
    description = "Bucket name"
    value       = aws_s3_bucket.s3_bucket.id
  }
  
  output "cloudfront_id" {
    value = aws_cloudfront_distribution.cloudfront.id
  }

  # provider.tf

  provider "aws" {
    region = "@@AWS_REGION@@"
  
    endpoints {
      sts = "https://sts.@@AWS_REGION@@.amazonaws.com"
    }
  
    assume_role {
      role_arn = "arn:aws:iam::@@AWS_ACCOUNT_ID@@:role/BURoleForDevSecOpsCockpitService"
    }
  }
  
  ### Used in Lambda@Edge function
  provider "aws" {
    alias  = "us1"
    region = "us-east-1"
  
    assume_role {
      role_arn = "arn:aws:iam::@@AWS_ACCOUNT_ID@@:role/BURoleForDevSecOpsCockpitService"
    }
  }
  
  terraform {
    backend "s3" {
      encrypt  = true
      bucket   = "cockpit-devsecops-states-@@AWS_ACCOUNT_ID@@"
      region   = "sa-east-1"
      key      = "aws-external-frontend/@@APP_NAME@@-@@ENVIRONMENT@@.tfstate"
      role_arn = "arn:aws:iam::@@AWS_ACCOUNT_ID@@:role/BURoleForDevSecOpsCockpitService"
    }
  }

# s3.tf
### Bucket Provisioning

## Web App Bucket
resource "aws_s3_bucket" "s3_bucket" {
  bucket        = lower("${var.app_name}-${var.environment}")
  force_destroy = true
  tags = {
    Data_Type      = "N/A"
    Data_Category  = "N/A"
    Asset_Category = "Embbeded"
    Environment    = local.env,
    AppID          = "${var.app_gearr_id}"
    CostString     = "${var.cost_center}"
    Project        = "${var.project_name}"
    BusinessUnit   = "${var.business_unit}"
    ManagedBy      = "Terraform"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_bucket_encryption" {
  bucket = aws_s3_bucket.s3_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "s3_bucket_policy" {
  bucket = aws_s3_bucket.s3_bucket.id
  policy = <<EOF
  {
   "Version":"2012-10-17",
   "Id":"PolicyForCloudFrontPrivateContent",
   "Statement":[
      {
         "Sid": "AllowCloudFrontServicePrincipal",
         "Effect":"Allow",
         "Principal":{
            "Service":"cloudfront.amazonaws.com"
         },
         "Action":"s3:GetObject",
         "Resource":[
            "arn:aws:s3:::${aws_s3_bucket.s3_bucket.id}/*"
         ],
         "Condition":{
            "StringEquals":{
               "AWS:SourceArn":"arn:aws:cloudfront::${var.aws_account_id}:distribution/${aws_cloudfront_distribution.cloudfront.id}"
            }
         }
      }
   ]
  }
  EOF
}

## Web App Data Bucket
resource "aws_s3_bucket" "s3_data_bucket" {
  count         = var.app_type == "WEB" ? 1 : 0
  bucket        = lower("${var.app_name}-data-${var.environment}")
  force_destroy = true
  tags = {
    Data_Type      = "N/A"
    Data_Category  = "N/A"
    Asset_Category = "Embbeded"
    Environment    = local.env,
    Project        = "${var.project_name}"
    AppID          = "${var.app_gearr_id}"
    CostString     = "${var.cost_center}"
    Project        = "${var.project_name}"
    BusinessUnit   = "${var.business_unit}"
    ManagedBy      = "Terraform"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_data_bucket_encryption" {
  count  = var.app_type == "WEB" ? 1 : 0
  bucket = aws_s3_bucket.s3_data_bucket[count.index].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "s3_data_bucket_policy" {
  count  = var.app_type == "WEB" ? 1 : 0
  bucket = aws_s3_bucket.s3_data_bucket[count.index].id
  policy = <<EOF
  {
    "Version": "2012-10-17",
    "Id":"PolicyForCloudFrontPrivateContent",
    "Statement": [
        {
            "Sid": "AllowCloudFrontServicePrincipal",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudfront.amazonaws.com"
            },
            "Action": "s3:GetObject",
            "Resource": [
                "arn:aws:s3:::${aws_s3_bucket.s3_data_bucket[count.index].id}/*"
            ],
            "Condition": {
                "StringEquals": {
                    "AWS:SourceArn": "arn:aws:cloudfront::${var.aws_account_id}:distribution/${aws_cloudfront_distribution.cloudfront.id}"
                }
            }
        }
    ]
  }
  EOF
}

# security.tf

### Roles and Policies for Lambda@Edge

resource "aws_iam_role" "lambda_invoke" {
  depends_on = [aws_cloudwatch_log_group.incapsula_whitelist_log_group]

  name               = "BURoleForLambda_${var.app_name}-${var.environment}"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": [
                    "lambda.amazonaws.com",
                    "edgelambda.amazonaws.com"
                ]
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
  tags = {
    Environment  = local.env
    AppID        = var.app_gearr_id
    CostString   = var.cost_center
    Project      = var.project_name
    BusinessUnit = var.business_unit
    ManagedBy    = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_invoke.name
}

# variables.tf

locals {
    env = var.environment == "prod" ? "prd" : var.environment
    domain = var.domain_name != "" ? var.domain_name : "${var.app_name}-${var.environment}${var.certificate_domain}"
    lambda_name = "incapsula-whitelist-${var.app_name}${var.environment != "prod" ? "-${var.environment}" : ""}"
  }
  
  variable "aws_account_id" {
    type    = string
    default = "@@AWS_ACCOUNT_ID@@"
  }
  
  variable "environment" {
    type    = string
    default = "@@ENVIRONMENT@@"
  }
  
  variable "business_unit" {
    type    = string
    default = "@@BUSINESS_UNIT@@"
  }
  
  variable "app_gearr_id" {
    type    = string
    default = "@@APP_GEARR_ID@@"
  }
  
  variable "app_name" {
    type    = string
    default = "@@APP_NAME@@"
  }
  
  variable "app_type" {
    type    = string
    default = "@@APP_TYPE@@"
  }
  
  variable "certificate_domain" {
    type    = string
    default = "@@CERTIFICATE_DOMAIN@@"
  }
  
  variable "certificate_arn" {
    type    = string
    default = "@@CERTIFICATE_ARN@@"
  }
  
  variable "domain_name" {
    type    = string
    default = "@@DOMAIN_NAME@@"
  }
  
  variable "cost_center" {
    type    = string
    default = "@@COST_CENTER@@"
  }
  
  variable "project_name" {
    type    = string
    default = "@@PROJECT_NAME@@"
  }
  
