provider "aws" {
  region = "us-east-1" # Set your desired AWS region
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
  handler       = "index.py"
  runtime       = "python3.9" # Change the runtime based on your Lambda function
  s3_bucket     = "robudexdevopsbucket" # Change this to your S3 bucket name
  s3_key        = "resume/index.py" # Change this to the actual path
  

  role = aws_iam_role.lambda_execution_role.arn
}

resource "aws_dynamodb_table" "resume_table" {
  name           = "resume_visitor"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "resume_id" # Change this to your desired primary key
  attribute {
    name = "resume_id"
    type = "S"
  }
}

resource "aws_api_gateway_rest_api" "resume_api" {
  name        = "ResumeAPI"
  description = "API for Resume"
}

resource "aws_api_gateway_resource" "resume_resource" {
  rest_api_id = aws_api_gateway_rest_api.resume_api.id
  parent_id   = aws_api_gateway_rest_api.resume_api.root_resource_id
  path_part   = "resume"
}

resource "aws_api_gateway_method" "get_method" {
  rest_api_id   = aws_api_gateway_rest_api.resume_api.id
  resource_id   = aws_api_gateway_resource.resume_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "resume_integration" {
  rest_api_id             = aws_api_gateway_rest_api.resume_api.id
  resource_id             = aws_api_gateway_resource.resume_resource.id
  http_method             = aws_api_gateway_method.get_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.resume_lambda.invoke_arn
}

resource "aws_api_gateway_method_response" "get_method_response" {
  rest_api_id = aws_api_gateway_rest_api.resume_api.id
  resource_id = aws_api_gateway_resource.resume_resource.id
  http_method = aws_api_gateway_method.get_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "get_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.resume_api.id
  resource_id = aws_api_gateway_resource.resume_resource.id
  http_method = aws_api_gateway_method.get_method.http_method
  status_code = aws_api_gateway_method_response.get_method_response.status_code
  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_method_settings" "cors_settings" {
  rest_api_id = aws_api_gateway_rest_api.resume_api.id
  stage_name  = "prod" # Change this to your desired stage name
  method_path = aws_api_gateway_method.get_method.resource_id

  settings {
    logging_level    = "INFO"
    data_trace_enabled = true
    metrics_enabled   = true
  }
}

resource "aws_api_gateway_integration_response" "cors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.resume_api.id
  resource_id = aws_api_gateway_resource.resume_resource.id
  http_method = aws_api_gateway_method.get_method.http_method
  status_code = "200"
  response_templates = {
    "application/json" = ""
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'",
    "method.response.header.Access-Control-Allow-Headers" = "'Authorization,Content-Type,Allow-Access-Origin'"
  }
}

resource "aws_api_gateway_method_response" "cors_method_response" {
  rest_api_id = aws_api_gateway_rest_api.resume_api.id
  resource_id = aws_api_gateway_resource.resume_resource.id
  http_method = aws_api_gateway_method.get_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true,
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

# Define dependencies
resource "aws_api_gateway_rest_api" "resume_api" {
  depends_on = [aws_lambda_function.resume_lambda]
}

resource "aws_lambda_function" "resume_lambda" {
  depends_on = [aws_dynamodb_table.resume_table, aws_iam_role.lambda_execution_role]
}

resource "aws_api_gateway_integration" "resume_integration" {
  depends_on = [aws_lambda_function.resume_lambda]
}
