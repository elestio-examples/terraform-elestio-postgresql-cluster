module "cluster" {
  source = "elestio-examples/postgresql-cluster/elestio"

  project_id = "12345"

  configuration_ssh_key = {
    username    = "terraform"
    public_key  = chomp(file("./terraform_rsa.pub"))
    private_key = file("./terraform_rsa")
  }

  postgresql_password             = "*****"
  postgresql_replication_password = "*****"
  postgresql_replication_user     = "replicator" # optional
  synchronous_standby_names       = ""           # optional
  synchronous_commit              = "on"         # optional

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
