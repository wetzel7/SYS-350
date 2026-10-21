
# SYS-350 Enterprise Build — Student A (lsavage)

Terraform-managed infrastructure on a shared KVM/Docker hypervisor: 3 isolated Docker
networks running 8 containerized services, plus 3 KVM virtual machines (Windows Server,
Windows 11, Ubuntu Server) on an isolated NAT network, all driven from a single
`main.tf` + `terraform.tfvars`.

## Repository Layout

enterprise-build/
├── main.tf                 # All providers, variables, and resources
├── cloud-init-server.yaml  # Cloud-init template for the Ubuntu VM
├── .gitignore               # Excludes state, tfvars, and local Terraform cache
└── README.md                 # This file


`terraform.tfvars` and all `.tfstate*` files are intentionally **not committed** —
they contain host-specific paths and secrets. A redacted example is below.

## Architecture

**Docker (3 networks, 8 services):**

| Network | Services |
| --- | --- |
| `lsavage-devops-net` | gitea, drawio, excalidraw |
| `lsavage-internal-net` | vaultwarden, stirlingpdf, privatebin |
| `lsavage-web-net` | mysql, wordpress, homepage |

**KVM (1 NAT network, 3 VMs):**

| VM | OS | Notes |
| --- | --- | --- |
| `lsavage-win-srv` | Windows Server (golden image, BIOS boot) | Listed in `bios_vms` — its golden image is MBR-partitioned, not UEFI/GPT |
| `lsavage-win11` | Windows 11 (golden image, UEFI boot) | |
| `lsavage-ubuntu-srv` | Ubuntu Server (cloud-init) | SSH key + password auth |

All three share `lsavage-corp-lan` (`192.168.50.0/24`, NAT, DHCP `.100`–`.254`).

## Redacted `terraform.tfvars` Example

```hcl
# terraform.tfvars: Student A (lsavage)

student_name = "lsavage"

networks   = ["devops", "internal", "web"]
corp_octet = 50

services = {
  gitea = {
    image   = "gitea/gitea:latest"
    network = "devops"
    ports   = [{ internal = 3000, external = 3000 }]
  }

  mysql = {
    image   = "mysql:8.0"
    network = "web"
    ports   = [{ internal = 3306, external = 3006 }]
    env = {
      MYSQL_ROOT_PASSWORD = "REDACTED"
      MYSQL_DATABASE      = "wordpress"
      MYSQL_USER          = "wpuser"
      MYSQL_PASSWORD      = "REDACTED"
    }
  }

  wordpress = {
    image   = "wordpress:latest"
    network = "web"
    ports   = [{ internal = 80, external = 3007 }]
    env = {
      WORDPRESS_DB_HOST     = "lsavage-mysql"
      WORDPRESS_DB_USER     = "wpuser"
      WORDPRESS_DB_PASSWORD = "REDACTED"
      WORDPRESS_DB_NAME     = "wordpress"
    }
  }

  drawio = {
    image   = "jgraph/drawio:latest"
    network = "devops"
    ports   = [{ internal = 8080, external = 3001 }]
  }

  vaultwarden = {
    image   = "vaultwarden/server:latest"
    network = "internal"
    ports   = [{ internal = 80, external = 3002 }]
    env = {
      ADMIN_TOKEN                    = "REDACTED"
      I_REALLY_WANT_VOLATILE_STORAGE = "true"
    }
  }

  stirlingpdf = {
    image   = "frooodle/s-pdf:latest"
    network = "internal"
    ports   = [{ internal = 8080, external = 3003 }]
  }

  privatebin = {
    image   = "privatebin/nginx-fpm-alpine:latest"
    network = "internal"
    ports   = [{ internal = 8080, external = 3004 }]
  }

  # Self-hosted picks (selfh.st/apps)
  excalidraw = {
    image   = "excalidraw/excalidraw:latest"
    network = "devops"
    ports   = [{ internal = 80, external = 3008 }]
  }

  homepage = {
    image   = "ghcr.io/gethomepage/homepage:latest"
    network = "web"
    ports   = [{ internal = 3000, external = 3009 }]
  }
}

vms = {
  "lsavage-win-srv" = {
    os = "win-server"
  }
  "lsavage-win11" = {
    os = "win11"
  }
  "lsavage-ubuntu-srv" = {
    os        = "ubuntu-server"
    memory_mb = 2048
    vcpu      = 1
  }
}

# Overrides — host-specific, do not commit real paths/secrets
win_server_image_path = "REDACTED_PATH"
hashed_passwd          = "REDACTED_SHA512_HASH"

# Windows VMs whose golden image is MBR/Legacy BIOS, not UEFI/GPT
bios_vms = ["lsavage-win-srv"]
```

## Setup

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

See the project wiki for the full step-by-step build log, verification commands,
and screenshots for every rubric category.

## Verification Summary

| Area | How it was verified |
| --- | --- |
| Docker networks/containers | `docker ps`, `docker network ls --filter name=lsavage` |
| Network isolation | `docker run --rm --network lsavage-devops-net curlimages/curl curl -m 3 http://<web-segment-ip>:<port>` — blocked |
| Container functionality | Browser screenshot per required service (Gitea wizard, WordPress wizard, etc.) |
| KVM VMs | `virsh list --all`, `virsh domifaddr <vm>` |
| VM-to-VM connectivity | `ping` between all three VMs on `lsavage-corp-lan` |
| VM access | SSH/console (Ubuntu) + RDP (both Windows VMs) |
| State inventory | `terraform state list` |
| Add/remove workflow | Comment out a `services`/`vms` entry → `terraform plan`/`apply` → confirm only that resource changed |

## Known Issues / Notes

- `lsavage-win-srv`'s golden image (`win2k25.qcow2`) is Legacy BIOS/MBR-partitioned,
  not UEFI/GPT — it's listed in `bios_vms` so `main.tf` boots it without OVMF/UEFI.
- Both Windows VMs require `cpu = { mode = "host-passthrough" }` in `main.tf` — the
  default QEMU CPU model lacks SSE4.2/POPCNT, which Windows 11 24H2 and Server 2025
  require to boot at all.
- `cloud-init-server.yaml` must start with a literal `#cloud-config` first line, or
  cloud-init silently discards the entire user-data file (no user, password, or
  packages get applied).
