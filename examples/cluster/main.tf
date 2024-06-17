variable "elestio_email" {
  type      = string
  sensitive = true
}

variable "elestio_api_token" {
  type      = string
  sensitive = true
}

variable "postgresql_password" {
  type      = string
  sensitive = true
}

variable "postgresql_replication_password" {
  type      = string
  sensitive = true
}

terraform {
  required_providers {
    elestio = {
      source  = "elestio/elestio"
      version = ">= 0.18.0"
    }
  }
}

provider "elestio" {
  email     = var.elestio_email
  api_token = var.elestio_api_token
}

resource "elestio_project" "project" {
  name = "pg-primary-replicas"
}

module "cluster" {
  source = "../.."

  project_id = elestio_project.project.id

  configuration_ssh_key = {
    username = "terraform"
    # Generate command: "ssh-keygen -t rsa -f terraform_rsa"
    public_key  = chomp(file("./terraform_rsa.pub"))
    private_key = file("./terraform_rsa")
  }

  postgresql_password             = var.postgresql_password
  postgresql_replication_password = var.postgresql_replication_password
  postgresql_replication_user     = "replicator" # optional
  synchronous_standby_names       = ""           # optional
  synchronous_commit              = "on"         # optional

  # Generate command: "openssl genrsa -out ca.key 4096"
  ssl_ca_key = file("./ca.key")

  nodes = {
    primary = {
      server_name   = "postgres-01"
      provider_name = "hetzner"
      datacenter    = "fsn1"
      server_type   = "SMALL-1C-2G"
    }
    replicas = [
      {
        server_name   = "postgres-02"
        provider_name = "hetzner"
        datacenter    = "hel1"
        server_type   = "SMALL-1C-2G"
      },
      {
        server_name   = "postgres-03"
        provider_name = "scaleway"
        datacenter    = "fr-par-1"
        server_type   = "SMALL-2C-2G"
      }
    ]
  }
}

output "nodes_admins" {
  sensitive = true
  value = {
    primary = {
      database = module.cluster.nodes.primary.database_admin
      pgadmin  = module.cluster.nodes.primary.admin
    }
    replicas = {
      for node in module.cluster.nodes.replicas : node.server_name => {
        database = node.database_admin
        pgadmin  = node.admin
      }
    }
  }
}
