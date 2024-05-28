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
      source = "elestio/elestio"
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
    username    = "terraform"
    public_key  = chomp(file("./terraform_rsa.pub"))
    private_key = file("./terraform_rsa")
  }

  postgresql_password             = var.postgresql_password
  postgresql_replication_password = var.postgresql_replication_password
  postgresql_replication_user     = "replicator"    # optional
  synchronous_standby_names       = "pg-replica-01" # optional
  synchronous_commit              = "on"            # optional

  primary = {
    server_name   = "pg-primary"
    provider_name = "hetzner"
    datacenter    = "fsn1"
    server_type   = "SMALL-1C-2G"
  }

  replicas = [
    {
      server_name   = "pg-replica-02"
      provider_name = "hetzner"
      datacenter    = "fsn1"
      server_type   = "SMALL-1C-2G"
    },
    {
      server_name   = "pg-replica-01"
      provider_name = "hetzner"
      datacenter    = "fsn1"
      server_type   = "SMALL-1C-2G"
    }
  ]
}