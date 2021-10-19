################### BUCKET ######################


data "aws_iam_policy_document" "public_read" {
  statement {
    actions = [
      "s3:GetObject"
    ]
    principals {
      identifiers = ["*"]
      type = "AWS"
    }
    resources = [
      "arn:aws:s3:::${var.upload_bucket_name}/*"
    ]
  }
}


resource "aws_s3_bucket" "upload_bucket" {
  bucket = var.upload_bucket_name
  acl    = "public-read"
  policy = data.aws_iam_policy_document.public_read.json
  force_destroy = true #make it possible to delete s3 even is not empty


  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT","GET", "HEAD"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }

}

##############################################   API     ###################
resource "aws_apigatewayv2_api" "https3api" {
  name          = "test-https3api"
  protocol_type = "HTTP"

  #for this case I handled the cors inside the lambda function
  #otherwise u can handle them in api gateway but make sure to read the api :)
  # cors_configuration {
  #   allow_headers = ["*"]
  #   allow_methods = ["GET", "POST", "DELETE", "OPTIONS"]
  #   allow_origins = ["*"]
  # }
}



resource "aws_apigatewayv2_stage" "https3api" {
  api_id = aws_apigatewayv2_api.https3api.id

  name        = "v1"
  auto_deploy = true

access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }

}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.https3api.name}"

  retention_in_days = 30
}
resource "aws_cloudwatch_log_group" "hello_world" {
  name = "/aws/lambda/${aws_lambda_function.get_signed_url_lambda.function_name}"

  retention_in_days = 30
}

resource "aws_apigatewayv2_integration" "hello_world" {
  api_id = aws_apigatewayv2_api.https3api.id
  payload_format_version = "1.0"

  integration_uri    = aws_lambda_function.get_signed_url_lambda.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "hello_world" {
  api_id = aws_apigatewayv2_api.https3api.id

  route_key = "GET /upload"
  target    = "integrations/${aws_apigatewayv2_integration.hello_world.id}"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_signed_url_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.https3api.execution_arn}/*/*"
}

################### LAMBDA (needs permission to s3)###########


resource "aws_iam_role" "iam_role_for_lambda" {
  name = "iam_for_s3_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# policy for lambda role to manipulate S3
resource "aws_iam_policy" "iam_policy_for_lambda_s3" {
  name = "lambda_access_s3_policy"
  description = "lambda_access_s3_policy"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": "arn:aws:s3:::*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.iam_role_for_lambda.name
  policy_arn = aws_iam_policy.iam_policy_for_lambda_s3.arn
}

resource "aws_lambda_function" "get_signed_url_lambda" {
  function_name = "lambda_upload_s3_name"
  role          = aws_iam_role.iam_role_for_lambda.arn


  filename      = "lambda_function_payload.zip"
  handler       = "index.handler"
  timeout       = 3
  runtime       = "nodejs14.x"
  #memory_size  = 128

  source_code_hash = filebase64sha256("lambda_function_payload.zip")


  environment {
    variables = {
      UploadBucket = aws_s3_bucket.upload_bucket.id
    }
  }

  
}





############################ JUNK ########## 

# resource "aws_iam_role" "iam_for_lambda" {
#   name = "iam_for_s3_lambda"

#   assume_role_policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Action": "sts:AssumeRole",
#       "Principal": {
#         "Service": "lambda.amazonaws.com"
#       },
#       "Effect": "Allow",
#       "Sid": ""
#     }
#   ]
# }
# EOF
# }

# data "aws_iam_policy_document" "policy_for_lambda"{
#   statement {
#     actions   = ["s3:*"]
#     principals {
#       identifiers = ["*"]
#       type = "AWS"
#     }
#     resources = [
#       "arn:aws:s3:::${var.upload_bucket_name}/*"
#     ]
#     effect = "Allow"
#   }
# }