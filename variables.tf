variable "project_id" {
  description = <<-EOF
  The Elestio project ID that will contain your nodes.
  Create a new Elestio project using the [terraform ressource](https://registry.terraform.io/providers/elestio/elestio/latest/docs/resources/project) `elestio_project` and get the ID from the output.
  EOF

  type     = string
  nullable = false
}

variable "postgresql_version" {
  description = <<-EOF
  The tag version of PostgreSQL image to install on the nodes.
  The default value is the recommended version.
  The docker image used is `elestio/postgresql:<version>`.
  List of available versions on the [Docker Hub page](https://hub.docker.com/r/elestio/postgres/tags).
  EOF

  type     = string
  nullable = true
  default  = null
}

variable "postgresql_password" {
  description = <<-EOF
  The password for the root **postgres** user.

  You can change this password after the first deployment, but you must manually execute this SQL command on the primary node before:
  ```
  ALTER USER "postgres" WITH ENCRYPTED PASSWORD "new_password";
  ```
  Then you can run the `terraform apply` command so the configuration will be updated with the new password.
  EOF

  sensitive = true
  type      = string
  nullable  = false

  validation {
    condition     = length(var.postgresql_password) >= 10 && can(regex("^[a-zA-Z0-9-]+$", var.postgresql_password)) && can(regex("[A-Z]", var.postgresql_password)) && can(regex("[a-z]", var.postgresql_password)) && can(regex("[0-9]", var.postgresql_password))
    error_message = "The password must be at least 10 characters long, contain only alphanumeric characters or hyphens, include at least one uppercase letter, one lowercase letter, and one number."
  }
}

variable "postgresql_replication_user" {
  description = <<-EOF
  The username for the replication user.
  Default value is `replicator`.

  You can change the username after the first deployment, but you must manually execute this SQL command on the primary node before:
  ```
  ALTER USER "replicator" RENAME TO "new_username";
  ```
  After executing this command, you can safely update this variable value and run the `terraform apply` command so the configuration will be updated with the new username.
  EOF

  type     = string
  nullable = true
  default  = "replicator"

  validation {
    condition     = length(var.postgresql_replication_user) <= 31 && can(regex("^[_a-zA-Z][_a-zA-Z0-9]*$", var.postgresql_replication_user))
    error_message = "Names in SQL must begin with a letter or underscore, followed by letters, digits, or underscores, and be no more than 31 characters long."
  }
}

variable "postgresql_replication_password" {
  description = <<-EOF
  The password of the replication user.

  You can change the replication password after the first deployment, but you must manually execute this SQL command on the primary node before:
  ```
  ALTER USER "replicator" WITH ENCRYPTED PASSWORD "new_password";
  ```
  After executing this command, you can safely update this variable value and run the `terraform apply` command so the configuration will be updated with the new password.
  EOF

  type      = string
  sensitive = true
  nullable  = false
  validation {
    condition     = length(var.postgresql_replication_password) >= 10 && can(regex("^[a-zA-Z0-9-]+$", var.postgresql_replication_password)) && can(regex("[A-Z]", var.postgresql_replication_password)) && can(regex("[a-z]", var.postgresql_replication_password)) && can(regex("[0-9]", var.postgresql_replication_password))
    error_message = "The password must be at least 10 characters long, contain only alphanumeric characters or hyphens, include at least one uppercase letter, one lowercase letter, and one number."
  }
}

variable "nodes" {
  description = <<-EOF
    The primary and replica nodes configuration. The primary node is mandatory, and you can configure as many replicas as you want. Be aware of your account resources limits.

    Check the `elestio_postgresql` [ressource documentation](https://registry.terraform.io/providers/elestio/elestio/latest/docs/resources/postgresql) for more information about available attributes.
  EOF

  type = object({
    primary = object({
      server_name                                       = string
      provider_name                                     = string
      datacenter                                        = string
      server_type                                       = string
      admin_email                                       = optional(string)
      alerts_enabled                                    = optional(bool)
      app_auto_update_enabled                           = optional(bool)
      backups_enabled                                   = optional(bool)
      firewall_enabled                                  = optional(bool)
      keep_backups_on_delete_enabled                    = optional(bool)
      remote_backups_enabled                            = optional(bool)
      support_level                                     = optional(string)
      system_auto_updates_security_patches_only_enabled = optional(bool)
      ssh_public_keys = optional(list(object({
        username = string
        key_data = string
        })
      ), [])
    })
    replicas = optional(list(object({
      server_name                                       = string
      provider_name                                     = string
      datacenter                                        = string
      server_type                                       = string
      admin_email                                       = optional(string)
      alerts_enabled                                    = optional(bool)
      app_auto_update_enabled                           = optional(bool)
      backups_enabled                                   = optional(bool)
      firewall_enabled                                  = optional(bool)
      keep_backups_on_delete_enabled                    = optional(bool)
      remote_backups_enabled                            = optional(bool)
      support_level                                     = optional(string)
      system_auto_updates_security_patches_only_enabled = optional(bool)
      ssh_public_keys = optional(list(object({
        username = string
        key_data = string
        })
      ), [])
    })), [])
  })
  nullable = false

  validation {
    error_message = "Each node must have a unique server_name."
    condition     = (length(var.nodes.replicas) + 1) == length(toset([for node in concat([var.nodes.primary], var.nodes.replicas) : node.server_name]))
  }
}

variable "configuration_ssh_key" {
  description = <<-EOF
  The module will use a local SSH key on your machine to connect to the nodes and configure the PostgreSQL cluster.
  Make sure to include the private key in your `.gitignore` file to avoid committing it to your repository.

  Generate a new SSH key using the following command:
  ```
  ssh-keygen -t rsa -f terraform_rsa"
  ```
  EOF

  sensitive = true
  type = object({
    username    = string
    public_key  = string
    private_key = string
  })
  nullable = false
}

variable "ssl_ca_key" {
  description = <<-EOF
  The ca.key is the private key for the Certificate Authority (CA) that will be used to sign the server certificates for your PostgreSQL cluster.
  Make sure to include it in your `.gitignore` file to avoid committing it to your repository.

  Generate a new private key using the following command:
  ```
  openssl genpkey -algorithm RSA -out ca.key
  ```
  EOF

  sensitive = true
  type      = string
  nullable  = false
}

variable "synchronous_standby_names" {
  description = <<-EOF
  Specifies the replicas running in synchronous mode.
  
  Check the [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-replication.html#GUC-SYNCHRONOUS-STANDBY-NAMES) for more information.
  EOF

  type     = string
  nullable = true
  default  = ""
}

variable "synchronous_commit" {
  description = <<-EOF
  Specifies how much WAL processing must complete before the database server returns a success indication to the client.
  Valid values are `on` (the default), `off`, `local`, `remote_apply`, and `remote_write`.
  
  Check the [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-wal.html#GUC-SYNCHRONOUS-COMMIT) for more information.
  EOF

  type     = string
  nullable = true
  default  = "on"

  validation {
    condition     = contains(["on", "off", "local", "remote_apply", "remote_write"], var.synchronous_commit)
    error_message = "Allowed values for synchronous_commit are \"on\", \"off\", \"local\", \"remote_apply\", or \"remote_write\"."
  }
}
