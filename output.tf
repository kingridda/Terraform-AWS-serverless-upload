output "get_upload_url_api" {
  description = "api url to request the upload url from"
  value = aws_apigatewayv2_stage.https3api.invoke_url
}