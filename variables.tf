variable "project_id" {
  description = <<-EOF
  The Elestio project ID that will contain your nodes.
  You can create a new Elestio project using the terraform ressource `elestio_project`.
  EOF
  type        = string
  nullable    = false
}

variable "postgresql_version" {
  description = <<-EOF
  The tag version of PostgreSQL image to install on the nodes.
  The docker image used is `elestio/postgresql:<version>`.
  The default value is the recommended version.
  You can find the available versions on the Docker Hub page: https://hub.docker.com/r/elestio/postgres/tags
  EOF
  type        = string
  nullable    = true
  default     = null
}

variable "postgresql_password" {
  description = <<-EOF
  The password for the default `postgres` superuser.
  You can change this password after the first deployment, but you must manually execute this SQL command on the primary node before:
  ```sql
  ALTER USER postgres WITH ENCRYPTED PASSWORD 'new_password';
  ```
  Then you can run the `terraform apply` command so the configuration will be updated with the new password.
  EOF
  sensitive   = true
  type        = string
  nullable    = false
}

variable "postgresql_replication_user" {
  description = <<-EOF
    The username for the replication user (default is `replicator`).
    You can change the username after the first deployment, but you must manually execute this SQL command on the primary node before:
    ```sql
    ALTER USER replicator RENAME TO new_username;
    ```
    After executing this command, you can safely update this variable value and run the `terraform apply` command so the configuration will be updated with the new username.
  EOF
  type        = string
  nullable    = true
  default     = "replicator"
}

variable "postgresql_replication_password" {
  description = <<-EOF
    The password for the replication user.
    You can change the replication password after the first deployment, but you must manually execute this SQL command on the primary node before:
    ```sql
    ALTER USER replicator WITH ENCRYPTED PASSWORD 'new_password';
    ```
    After executing this command, you can safely update this variable value and run the `terraform apply` command so the configuration will be updated with the new password.
  EOF
  type        = string
  sensitive   = true
  nullable    = false
}

variable "nodes" {
  description = "Primary and replicas nodes configuration."
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
  description = ""
  sensitive   = true
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
  ```sh
  openssl genpkey -algorithm RSA -out ca.key
  ```
  EOF
  sensitive   = true
  type        = string
  nullable    = false
}

variable "synchronous_standby_names" {
  description = "Specifies the list of replicas that support synchronous replication."
  type        = string
  nullable    = true
  default     = ""
}

variable "synchronous_commit" {
  description = "Specifies how much WAL processing must complete before the database server returns a success indication to the client. Valid values are `on` (the default), `off`, `local`, `remote_apply`, and `remote_write`."
  type        = string
  nullable    = true
  default     = "on"

  validation {
    condition     = contains(["on", "off", "local", "remote_apply", "remote_write"], var.synchronous_commit)
    error_message = "Allowed values for synchronous_commit are \"on\", \"off\", \"local\", \"remote_apply\", or \"remote_write\"."
  }
}
