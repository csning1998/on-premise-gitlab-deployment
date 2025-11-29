
provider "postgresql" {
  host            = var.pg_host
  port            = var.pg_port
  username        = var.pg_superuser
  password        = var.pg_superuser_password
  sslmode         = "disable" # Should be modified to 'require'
  connect_timeout = 15
  superuser       = false
}

resource "postgresql_database" "dbs" {

  depends_on = [postgresql_role.users]

  for_each = var.databases
  name     = each.key
  owner    = each.value.owner
}

resource "postgresql_role" "users" {
  for_each = var.users

  name     = each.key
  password = each.value.password
  login    = true
  roles    = each.value.roles
}
