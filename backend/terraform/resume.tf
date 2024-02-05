provider "aws" {
  region = "us-east-1" # Set your desired AWS region
}

resource "aws_api_gateway_rest_api" "resume_aws_api" {
  name = "resume_aws_api"
}

resource "aws_api_gateway_rest_api_policy" "resume_aws_api_policy" {
  rest_api_id = aws_api_gateway_rest_api.resume_aws_api.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [

      {
        "Effect" : "Allow",
        "Principal" : "*",
        "Action" : "execute-api:Invoke",
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "LambdaExecutionRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "lambda_execution_policy" {
  name = "LambdaExecutionPolicy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "dynamodb:*",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_execution_attachment" {
  policy_arn = aws_iam_policy.lambda_execution_policy.arn
  role       = aws_iam_role.lambda_execution_role.name
}

resource "aws_lambda_function" "resume_lambda" {
  function_name = "resume-visitor-counter-function"
  handler       = "index.lambda_handler"
  runtime       = "python3.9" # Change the runtime based on your Lambda function
  # s3_bucket     = "robudexdevopsbucket" # Change this to your S3 bucket name
  # s3_key        = "resumeaws/index.zip"  # Change this to the actual path
  filename = "../../backend/lambda_code/${var.lambda_code_file}"


  role       = aws_iam_role.lambda_execution_role.arn
  depends_on = [aws_dynamodb_table.resume_table]
}

resource "aws_dynamodb_table" "resume_table" {
  name         = "resume_visitor"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ip" # Change this to your desired primary key
  attribute {
    name = "ip"
    type = "S"
  }
}

resource "aws_lambda_permission" "lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.resume_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.resume_aws_api.execution_arn}/*/*"

  depends_on = [aws_lambda_function.resume_lambda]
}

resource "aws_api_gateway_resource" "resume_aws_api_resource" {
  parent_id   = aws_api_gateway_rest_api.resume_aws_api.root_resource_id
  path_part   = "resumeaws"
  rest_api_id = aws_api_gateway_rest_api.resume_aws_api.id
}

resource "aws_api_gateway_method" "resume_get_method" {
  authorization = "NONE"
  http_method   = "GET"
  resource_id   = aws_api_gateway_resource.resume_aws_api_resource.id
  rest_api_id   = aws_api_gateway_rest_api.resume_aws_api.id
}

resource "aws_api_gateway_method" "resume_options_method" {
  authorization = "NONE"
  http_method   = "OPTIONS"
  resource_id   = aws_api_gateway_resource.resume_aws_api_resource.id
  rest_api_id   = aws_api_gateway_rest_api.resume_aws_api.id


}

# Define a data source for the existing Lambda function
# data "aws_lambda_function" "existing_lambda_function" {
#   function_name = "visitor-counter-function"
# Add other identifying attributes if needed (e.g., role, runtime, etc.)
# }

resource "aws_api_gateway_integration" "resume_aws_api_integration" {
  http_method             = aws_api_gateway_method.resume_get_method.http_method
  resource_id             = aws_api_gateway_resource.resume_aws_api_resource.id
  rest_api_id             = aws_api_gateway_rest_api.resume_aws_api.id
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.resume_lambda.invoke_arn
  integration_http_method = "POST"

  depends_on = [aws_api_gateway_method.resume_get_method]
}

resource "aws_api_gateway_integration" "resume_options_api_integration" {
  http_method = aws_api_gateway_method.resume_options_method.http_method
  resource_id = aws_api_gateway_resource.resume_aws_api_resource.id
  rest_api_id = aws_api_gateway_rest_api.resume_aws_api.id
  type        = "MOCK"


  depends_on = [aws_api_gateway_method.resume_options_method]
}

resource "aws_api_gateway_method_response" "resume_get_method_response" {
  rest_api_id = aws_api_gateway_rest_api.resume_aws_api.id
  resource_id = aws_api_gateway_resource.resume_aws_api_resource.id
  http_method = aws_api_gateway_method.resume_get_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "resume_aws_api_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.resume_aws_api.id
  resource_id = aws_api_gateway_resource.resume_aws_api_resource.id
  http_method = aws_api_gateway_method.resume_get_method.http_method
  status_code = aws_api_gateway_method_response.resume_get_method_response.status_code



  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.resume_aws_api_integration]
}

resource "aws_api_gateway_method_response" "resume_options_method_response" {
  rest_api_id = aws_api_gateway_rest_api.resume_aws_api.id
  resource_id = aws_api_gateway_resource.resume_aws_api_resource.id
  http_method = aws_api_gateway_method.resume_options_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "resume_options_api_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.resume_aws_api.id
  resource_id = aws_api_gateway_resource.resume_aws_api_resource.id
  http_method = aws_api_gateway_method.resume_options_method.http_method
  status_code = aws_api_gateway_method_response.resume_options_method_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,get,PUT'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_deployment" "resume_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.resume_aws_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.resume_aws_api_resource.id,
      aws_api_gateway_method.resume_get_method.id,
      aws_api_gateway_method.resume_options_method.id,
      aws_api_gateway_integration.resume_aws_api_integration.id,
      aws_api_gateway_integration.resume_options_api_integration.id,
      aws_api_gateway_method_response.resume_get_method_response.id,
      aws_api_gateway_integration_response.resume_aws_api_integration_response.id,
      aws_api_gateway_method_response.resume_options_method_response.id,
      aws_api_gateway_integration_response.resume_options_api_integration_response.id,
    ]))
  }

  depends_on = [aws_api_gateway_integration.resume_aws_api_integration]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "resume_staging" {
  deployment_id = aws_api_gateway_deployment.resume_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.resume_aws_api.id
  stage_name    = "staging"
}

output "api_gateway_url" {
  value = aws_api_gateway_stage.resume_staging.invoke_url
}
