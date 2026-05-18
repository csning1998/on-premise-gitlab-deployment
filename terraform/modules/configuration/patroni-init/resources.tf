
locals {
  # Create a flat list of (database, extension) tuples for for_each
  db_extensions = flatten([
    for db_name, config in var.databases : [
      for ext in config.extensions : {
        database  = db_name
        extension = ext
      }
    ]
  ])
}

resource "postgresql_role" "users" {
  for_each = var.users

  name            = each.key
  password        = each.value.password
  login           = each.value.login
  superuser       = each.value.superuser
  create_database = each.value.create_database
  roles           = each.value.roles
}

resource "postgresql_database" "dbs" {
  depends_on = [postgresql_role.users]

  for_each = var.databases

  name     = each.key
  owner    = each.value.owner
  encoding = each.value.encoding
}

resource "postgresql_extension" "extensions" {
  for_each = {
    for pair in local.db_extensions : "${pair.database}.${pair.extension}" => pair
  }

  name         = each.value.extension
  database     = postgresql_database.dbs[each.value.database].name
  drop_cascade = true
}
