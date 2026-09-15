# main.tf - First terraform configuration

terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

variable "student_name" {
  type = string
  description = "Your student identifier (e.g., lsavage, ebailey)"

  validation {
  condition = can(regex("^[a-z]{2,10}$", var.student_name))
  error_message = "student name must be 2-10 lowercase characters."
  }
}

variable "host_port" { 
  description = "Port on the host"
  type = number
  default = 8080
}

# Pull nginx image
resource "docker_image" "nginx" {
  name = "nginx:latest"
}

# create a custon docker network
resource "docker_network" "lan" {
  name = "${var.student_name}-sys350-lan"
}

# creating container
resource "docker_container" "web_server" {
  name = "${var.student_name}-web-server"
  image = docker_image.nginx.image_id

  # port mapping
  ports {
    internal = 80
    external = var.host_port
  }

  # attach to custom network
  networks_advanced {
    name = docker_network.lan.name
  }

  volumes {
    volume_name = docker_volume.web_data.name
    container_path = "/usr/share/nginx/html"
    read_only = false
  }
}

# create volume named for persistent data
resource "docker_volume" "web_data" {
  name = "${var.student_name}-nginx-html"
}

output "container_ip" {
  value = docker_container.web_server.network_data[0].ip_address
}
