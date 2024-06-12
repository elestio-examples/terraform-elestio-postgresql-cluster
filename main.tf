resource "elestio_postgresql" "cluster_nodes" {
  for_each = { for config in concat([var.nodes.primary], var.nodes.replicas) : config.server_name => config }

  project_id       = var.project_id
  version          = var.postgresql_version
  default_password = var.postgresql_password
  server_name      = each.value.server_name
  provider_name    = each.value.provider_name
  datacenter       = each.value.datacenter
  server_type      = each.value.server_type
  ssh_public_keys = concat(each.value.ssh_public_keys, [{
    username = var.configuration_ssh_key.username
    key_data = var.configuration_ssh_key.public_key
  }])
  admin_email                                       = each.value.admin_email                                       # optional
  alerts_enabled                                    = each.value.alerts_enabled                                    # optional
  app_auto_updates_enabled                          = each.value.app_auto_update_enabled                           # optional
  backups_enabled                                   = each.value.backups_enabled                                   # optional
  firewall_enabled                                  = each.value.firewall_enabled                                  # optional
  keep_backups_on_delete_enabled                    = each.value.keep_backups_on_delete_enabled                    # optional
  remote_backups_enabled                            = each.value.remote_backups_enabled                            # optional
  support_level                                     = each.value.support_level                                     # optional
  system_auto_updates_security_patches_only_enabled = each.value.system_auto_updates_security_patches_only_enabled # optional


  connection {
    type        = "ssh"
    host        = self.ipv4
    private_key = var.configuration_ssh_key.private_key
  }

  # Upload a script helper to add or update environment variables.
  provisioner "file" {
    source      = "${path.module}/src/updateEnv.sh"
    destination = "/opt/app/scripts/updateEnv.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "cd /opt/app",
      # Grant permissions to the script.
      "chmod +x scripts/updateEnv.sh",
      # Stop the default container started by Elestio.
      "docker-compose down",
      # Reset the data directory used as a volume.
      "rm -rf data",
      "mkdir data",
      "chown -R 1001:1001 data",
    ]
  }
}

locals {
  primary_node   = elestio_postgresql.cluster_nodes[var.nodes.primary.server_name]
  replicas_nodes = { for node in [for cluster_node in elestio_postgresql.cluster_nodes : cluster_node if cluster_node.server_name != var.nodes.primary.server_name] : node.server_name => node }
}

# The primary can either be on a new node, or a replica to be promoted.
resource "terraform_data" "primary_configuration" {
  triggers_replace = {
    primary_node_id           = local.primary_node.id
    cluster_name              = replace(local.primary_node.server_name, "-", "_")
    synchronous_standby_names = replace(var.synchronous_standby_names, "-", "_")
    synchronous_commit        = var.synchronous_commit
    postgresql_password       = var.postgresql_password
  }

  connection {
    type        = "ssh"
    host        = local.primary_node.ipv4
    private_key = var.configuration_ssh_key.private_key
  }

  provisioner "remote-exec" {
    inline = [
      "cd /opt/app",
      # If the specified primary is a replica to be promoted, then promote it, and wait for the promotion to complete.
      "if grep -q 'pg_basebackup' docker-compose.yml; then echo 'Promoting the replica..' && docker-compose exec -T postgres psql -U postgres -c 'SELECT pg_promote();' && sleep 20; fi",
      # In any case, down the container to update the configuration.
      "docker-compose down",
    ]
  }

  # Update the environment variables in the .env file.
  provisioner "remote-exec" {
    inline = [
      "cd /opt/app",
      "scripts/updateEnv.sh SOFTWARE_PASSWORD ${self.triggers_replace.postgresql_password}",
      "scripts/updateEnv.sh CLUSTER_NAME ${self.triggers_replace.cluster_name}",
      "scripts/updateEnv.sh SYNCHRONOUS_STANDBY_NAMES '\"${self.triggers_replace.synchronous_standby_names}\"'",
      "scripts/updateEnv.sh SYNCHRONOUS_COMMIT ${self.triggers_replace.synchronous_commit}",
    ]
  }

  # Upload docker-compose file with the new configuration.
  provisioner "file" {
    source      = "${path.module}/src/docker-compose.primary.yml"
    destination = "/opt/app/docker-compose.yml"
  }

  # Upload the initialization sql script
  provisioner "file" {
    content = templatefile("${path.module}/src/00_init.sql.tftpl", {
      replication_user     = var.postgresql_replication_user,
      replication_password = var.postgresql_replication_password
    })
    destination = "/opt/app/00_init.sql"
  }

  # Start the primary node with the new configuration.
  provisioner "remote-exec" {
    inline = [
      "cd /opt/app",
      "docker-compose up -d",
      "sleep 20",
      "echo 'Primary node was started.'",
    ]
  }
}

resource "terraform_data" "replicas_configuration" {
  for_each = local.replicas_nodes

  triggers_replace = {
    postgresql_password   = var.postgresql_password
    primary_configuration = terraform_data.primary_configuration.id
    primary_host          = local.primary_node.global_ip
    cluster_name          = replace(each.value.server_name, "-", "_")
    replication_slot_name = "${replace(each.value.server_name, "-", "_")}_slot"
    replication_user      = var.postgresql_replication_user
    replication_password  = var.postgresql_replication_password
  }

  # Creates the replication slot if it does not exist yet.
  provisioner "remote-exec" {
    # The connection is made on the primary node.
    connection {
      type        = "ssh"
      host        = local.primary_node.ipv4
      private_key = var.configuration_ssh_key.private_key
    }
    inline = [
      "cd /opt/app",
      "docker-compose exec -T postgres psql -U postgres -c \"SELECT create_physical_replication_slot_if_not_exists('${self.triggers_replace.replication_slot_name}');\""
    ]
  }

  # Every following provisioner will be executed on the replica node.
  connection {
    type        = "ssh"
    host        = each.value.ipv4
    private_key = var.configuration_ssh_key.private_key
  }

  # Stop the container to update the configuration.
  provisioner "remote-exec" {
    inline = [
      "cd /opt/app",
      "docker-compose down",
    ]
  }

  # Update the environment variables in the .env file.
  provisioner "remote-exec" {
    inline = [
      "cd /opt/app",
      "scripts/updateEnv.sh SOFTWARE_PASSWORD ${self.triggers_replace.postgresql_password}",
      "scripts/updateEnv.sh CLUSTER_NAME ${self.triggers_replace.cluster_name}",
      "scripts/updateEnv.sh PRIMARY_HOST ${self.triggers_replace.primary_host}",
      "scripts/updateEnv.sh REPLICATION_SLOT_NAME ${self.triggers_replace.replication_slot_name}",
      "scripts/updateEnv.sh REPLICATION_USER ${self.triggers_replace.replication_user}",
      "scripts/updateEnv.sh REPLICATION_PASSWORD ${self.triggers_replace.replication_password}",
    ]
  }

  # Upload docker-compose file with the new configuration.
  provisioner "file" {
    source      = "${path.module}/src/docker-compose.replica.yml"
    destination = "/opt/app/docker-compose.yml"
  }

  # Start the replica node with the new configuration.
  provisioner "remote-exec" {
    inline = [
      "cd /opt/app",
      "docker-compose up -d",
      "echo 'Replica node ${each.key} was started.'",
    ]
  }
}
