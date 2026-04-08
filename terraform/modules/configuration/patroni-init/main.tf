
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
