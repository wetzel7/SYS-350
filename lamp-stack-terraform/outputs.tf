# outputs.tf - Displays URLs and container names after deployment

output "web_urls" {
  description = "URLs for all web containers"
  value       = [for i in range(var.web_count) : "http://localhost:${var.web_port + i}"]
}

output "web_container_names" {
  description = "Names of all web containers"
  value       = [for c in docker_container.web : c.name]
}

output "db_container_name" {
  description = "Name of the database container"
  value       = docker_container.db.name
}

output "network_name" {
  description = "Name of the Docker network"
  value       = docker_network.lamp_network.name
}

output "volume_name" {
  description = "Name of the persistent database volume"
  value       = docker_volume.db_data.name
}
