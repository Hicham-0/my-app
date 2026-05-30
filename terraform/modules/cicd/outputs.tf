output "pipeline_name" {
  value = aws_codepipeline.main.name
}

output "codedeploy_app_name" {
  value = aws_codedeploy_app.main.name
}

output "github_connection_arn" {
  value = aws_codestarconnections_connection.github.arn
}

output "artifacts_bucket" {
  value = aws_s3_bucket.artifacts.bucket
}