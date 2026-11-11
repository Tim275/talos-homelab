output "gitlab_ip" {
  value       = var.gitlab_config.ip
  description = "GitLab VM IP address"
}

output "gitlab_url" {
  value       = "http://${var.gitlab_config.external_url}"
  description = "GitLab web UI URL"
}

output "gitlab_ssh" {
  value       = "ssh gitlab-admin@${var.gitlab_config.ip}"
  description = "SSH command to reach GitLab VM"
}
