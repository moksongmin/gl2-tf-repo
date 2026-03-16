terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
    archive = {
      source = "hashicorp/archive"
    }
  }
}

data "archive_file" "authorizer" {
  type        = "zip"
  source_file = "${path.module}/lambda/authorizer.mjs"
  output_path = "${path.module}/lambda/authorizer.zip"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

locals {
  api_domain_name = replace(aws_apigatewayv2_api.this.api_endpoint, "https://", "")
  service_routes = merge(
    {
      for name, service in var.services : "${name}-root" => {
        route_key = "ANY ${service.path}"
      }
    },
    {
      for name, service in var.services : "${name}-proxy" => {
        route_key = "ANY ${service.path}/{proxy+}"
      }
    }
  )
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/apigateway/${var.name}"
  retention_in_days = 30

  tags = var.tags
}

resource "aws_security_group" "vpc_link" {
  name        = "${var.name}-vpc-link-sg"
  description = "API Gateway VPC link access to internal ALB"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr_block]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-vpc-link-sg"
  })
}

resource "aws_iam_role" "lambda" {
  name               = "${var.name}-authorizer-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "authorizer" {
  function_name    = "${var.name}-jwt-authorizer"
  filename         = data.archive_file.authorizer.output_path
  source_code_hash = data.archive_file.authorizer.output_base64sha256
  role             = aws_iam_role.lambda.arn
  runtime          = "nodejs20.x"
  handler          = "authorizer.handler"
  timeout          = 10

  environment {
    variables = {
      JWT_ISSUER         = var.jwt_issuer
      JWT_AUDIENCE       = jsonencode(var.jwt_audience)
      JWKS_URI           = var.jwks_uri
      ROUTE_ROLE_RULES   = jsonencode(var.authorization_rules)
      ROLE_CLAIM_NAMES   = jsonencode(["roles", "role", "cognito:groups"])
      PRINCIPAL_ID_CLAIM = "sub"
    }
  }

  tags = var.tags
}

resource "aws_apigatewayv2_vpc_link" "this" {
  name               = "${var.name}-vpc-link"
  security_group_ids = [aws_security_group.vpc_link.id]
  subnet_ids         = var.private_subnet_ids

  tags = var.tags
}

resource "aws_apigatewayv2_api" "this" {
  name          = "${var.name}-http-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_headers  = ["authorization", "content-type", "x-trace-id"]
    allow_methods  = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allow_origins  = ["*"]
    expose_headers = ["x-trace-id"]
  }

  tags = var.tags
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/authorizers/*"
}

resource "aws_apigatewayv2_authorizer" "this" {
  api_id                            = aws_apigatewayv2_api.this.id
  authorizer_type                   = "REQUEST"
  authorizer_uri                    = aws_lambda_function.authorizer.invoke_arn
  authorizer_payload_format_version = "2.0"
  enable_simple_responses           = true
  identity_sources                  = ["$request.header.Authorization"]
  name                              = "${var.name}-request-authorizer"
}

resource "aws_apigatewayv2_integration" "alb" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = var.alb_listener_arn
  payload_format_version = "1.0"
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.this.id

  request_parameters = {
    "overwrite:header.x-trace-id"     = "$context.requestId"
    "overwrite:header.x-user-role"    = "$context.authorizer.role"
    "overwrite:header.x-principal-id" = "$context.authorizer.principalId"
  }
}

resource "aws_apigatewayv2_route" "service" {
  for_each = local.service_routes

  api_id             = aws_apigatewayv2_api.this.id
  route_key          = each.value.route_key
  target             = "integrations/${aws_apigatewayv2_integration.alb.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.this.id
}

resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = var.stage_name
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      authorizerRole = "$context.authorizer.role"
      integration    = "$context.integration.status"
      sourceIp       = "$context.identity.sourceIp"
    })
  }

  default_route_settings {
    throttling_burst_limit   = var.burst_limit
    throttling_rate_limit    = var.rate_limit
    detailed_metrics_enabled = true
  }

  tags = var.tags
}

resource "aws_wafv2_web_acl" "this" {
  provider = aws.us_east_1
  name     = "${var.name}-edge-waf"
  scope    = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-edge-waf"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  tags = var.tags
}

resource "aws_cloudfront_distribution" "this" {
  enabled    = true
  comment    = "${var.name} API distribution"
  aliases    = var.cloudfront_aliases
  web_acl_id = aws_wafv2_web_acl.this.arn

  origin {
    domain_name = local.api_domain_name
    origin_id   = "api-gateway"
    origin_path = "/${var.stage_name}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = "api-gateway"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = true

      headers = [
        "Authorization",
        "Content-Type",
        "X-Trace-Id",
      ]

      cookies {
        forward = "all"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.cloudfront_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = var.tags
}
