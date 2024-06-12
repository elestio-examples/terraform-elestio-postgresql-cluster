# Terraform Module for Postgres Cluster by Elestio

- [x] primary/replicas config
- [x] replica can be async or sync
- [x] failover
- [x] able to update postgresql_password, replication_user and replication_password
- [ ] ssl
- [ ] documentation

## Postgres root password

1. Connect with psql, pgadmin or any other client to the primary node

2. Run the following SQL command to update the password:

   ```sql
   ALTER USER postgres WITH ENCRYPTED PASSWORD 'new_password';
   ```

   The change will be dynamically applied to running nodes.

3. Update the `postgresql_password` module variable in the `main.tf` file

4. Run `terraform apply` to apply the changes to the cluster

   The password will be upated also in the configuration files so that the new password will be used in case of restarts.
