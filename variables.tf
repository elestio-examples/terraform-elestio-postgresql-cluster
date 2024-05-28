variable "project_id" {
  type = string
}

variable "postgresql_version" {
  type        = string
  nullable    = true
  default     = null
  description = ""
}

variable "postgresql_password" {
  type        = string
  sensitive   = true
  description = ""
}

variable "postgresql_replication_user" {
  type        = string
  sensitive   = true
  description = ""
}

variable "postgresql_replication_password" {
  type        = string
  sensitive   = true
  description = ""
}

variable "primary" {
  type = object({
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
}

variable "replicas" {
  type = list(
    object({
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
  )
  default     = []
  description = ""

  # validation {
  #   error_message = "You must provide at least 1 replicas."
  #   condition     = length(var.replicas) >= 1
  # }

  # validation {
  #   error_message = "Each replica must have a unique replica_name."
  #   condition     = length(var.replicas) == length(toset([for replica in var.replicas : replica.replica_name]))
  # }
}

variable "configuration_ssh_key" {
  type = object({
    username    = string
    public_key  = string
    private_key = string
  })
  sensitive   = true
  description = ""
}

variable "synchronous_standby_names" {
  type        = string
  description = "Specifies the list of replicas that support synchronous replication."
  default     = ""
}

variable "synchronous_commit" {
  type        = string
  description = "Specifies how much WAL processing must complete before the database server returns a success indication to the client. Valid values are `on` (the default), `off`, `local`, `remote_apply`, and `remote_write`."
  default     = "on"

  validation {
    condition     = contains(["on", "off", "local", "remote_apply", "remote_write"], var.synchronous_commit)
    error_message = "Allowed values for synchronous_commit are \"on\", \"off\", \"local\", \"remote_apply\", or \"remote_write\"."
  }
}
