resource "elestio_postgresql" "cluster_nodes" {
  for_each = { for node in concat([var.primary], var.replicas) : node.server_name => node }

  project_id                                        = var.project_id
  version                                           = var.postgresql_version
  default_password                                  = var.postgresql_password
  server_name                                       = each.value.server_name
  provider_name                                     = each.value.provider_name
  datacenter                                        = each.value.datacenter
  server_type                                       = each.value.server_type
  admin_email                                       = each.value.admin_email                                       # optional
  alerts_enabled                                    = each.value.alerts_enabled                                    # optional
  app_auto_updates_enabled                          = each.value.app_auto_update_enabled                           # optional
  backups_enabled                                   = each.value.backups_enabled                                   # optional
  firewall_enabled                                  = each.value.firewall_enabled                                  # optional
  keep_backups_on_delete_enabled                    = each.value.keep_backups_on_delete_enabled                    # optional
  remote_backups_enabled                            = each.value.remote_backups_enabled                            # optional
  support_level                                     = each.value.support_level                                     # optional
  system_auto_updates_security_patches_only_enabled = each.value.system_auto_updates_security_patches_only_enabled # optional

  # Merge the configuration SSH key with the potential SSH public keys provided by the user for each node
  ssh_public_keys = concat(each.value.ssh_public_keys, [{
    username = var.configuration_ssh_key.username
    key_data = var.configuration_ssh_key.public_key
  }])

  connection {
    type        = "ssh"
    host        = self.ipv4
    private_key = var.configuration_ssh_key.private_key
  }

  # Stop and reset the default container started by Elestio
  provisioner "remote-exec" {
    inline = [
      "echo 'Removing the default container started by Elestio...'",
      "cd /opt/app",
      "docker-compose down",
      "echo 'Resetting the data directory...'",
      "rm -rf ./data",
      "rm -rf ./pgadmin",
      "mkdir -p ./data",
      "mkdir -p ./pgadmin",
      "chown -R 1001:1001 ./data",
      "chown -R 1001:1001 ./pgadmin",
      "echo 'Node ${self.server_name} is ready to be configured.'"
    ]
  }
}

locals {
  primary_node   = elestio_postgresql.cluster_nodes[var.primary.server_name]
  replicas_nodes = { for node in [for cluster_node in elestio_postgresql.cluster_nodes : cluster_node if cluster_node.server_name != var.primary.server_name] : node.server_name => node }
}

resource "null_resource" "primary_configuration" {
  triggers = {
    primary_server_id         = local.primary_node.id
    cluster_name              = replace(local.primary_node.server_name, "-", "_")
    synchronous_standby_names = replace(var.synchronous_standby_names, "-", "_")
    synchronous_commit        = var.synchronous_commit
  }

  connection {
    type        = "ssh"
    host        = local.primary_node.ipv4
    private_key = var.configuration_ssh_key.private_key
  }

  provisioner "local-exec" {
    command = "echo 'Configuring the primary node...'"
  }

  provisioner "file" {
    source      = "${path.module}/config/primary.docker-compose.yml"
    destination = "/opt/app/docker-compose.yml"
  }

  provisioner "file" {
    content = templatefile("${path.module}/config/primary.env.tftpl", {
      software_version_tag      = local.primary_node.version
      software_password         = local.primary_node.admin.password
      admin_email               = local.primary_node.admin_email
      admin_password            = local.primary_node.admin.password
      cname                     = local.primary_node.cname
      cluster_name              = self.triggers.cluster_name
      synchronous_standby_names = self.triggers.synchronous_standby_names
      synchronous_commit        = self.triggers.synchronous_commit
    })
    destination = "/opt/app/.env"
  }

  provisioner "file" {
    content     = templatefile("${path.module}/config/00_init.sql.tftpl", { replication_password = var.postgresql_replication_password })
    destination = "/opt/app/00_init.sql"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Starting the primary node...'",
      "cd /opt/app",
      "docker-compose up -d",
      "sleep 20",
      "echo 'Primary node is started.'",
    ]
  }
}

resource "null_resource" "replication_slots" {
  for_each = local.replicas_nodes

  triggers = {
    is_primary_ready      = null_resource.primary_configuration.id
    primary_ipv4          = local.primary_node.ipv4
    replication_slot_name = "${replace(each.value.server_name, "-", "_")}_slot"
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = self.triggers.primary_ipv4
      private_key = var.configuration_ssh_key.private_key
    }
    inline = [
      "echo 'Creating the replication slot for ${each.key}...'",
      "cd /opt/app",
      "docker-compose exec -T postgres psql -U postgres -c \"SELECT pg_create_physical_replication_slot('${self.triggers.replication_slot_name}');\""
    ]
  }
}

resource "null_resource" "replicas_configuration" {
  for_each = local.replicas_nodes

  triggers = {
    is_replication_slot_ready = null_resource.replication_slots[each.key].id
    cluster_name              = replace(each.value.server_name, "-", "_")
  }

  connection {
    type        = "ssh"
    host        = each.value.ipv4
    private_key = var.configuration_ssh_key.private_key
  }

  provisioner "file" {
    source      = "${path.module}/config/replica.docker-compose.yml"
    destination = "/opt/app/docker-compose.yml"
  }

  provisioner "file" {
    content = templatefile("${path.module}/config/replica.env.tftpl", {
      software_version_tag  = local.primary_node.version
      software_password     = local.primary_node.admin.password
      admin_email           = local.primary_node.admin_email
      admin_password        = local.primary_node.admin.password
      cname                 = local.primary_node.cname
      cluster_name          = self.triggers.cluster_name
      primary_host          = local.primary_node.global_ip
      replication_slot_name = null_resource.replication_slots[each.key].triggers.replication_slot_name
      replication_user      = var.postgresql_replication_user
      replication_password  = var.postgresql_replication_password
    })
    destination = "/opt/app/.env"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Starting the replica node ${each.key}...'",
      "cd /opt/app",
      "docker-compose up -d",
      "echo 'Replica node ${each.key} is started.'",
    ]
  }
}
