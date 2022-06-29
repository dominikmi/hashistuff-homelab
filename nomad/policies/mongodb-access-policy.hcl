# Allow to read database mongo dynamic secrets
path "database/mongodb/creds/*" {
  capabilities = ["read", "list"]
}

# Allow to read database mongo static secrets
path "database/mongodb/static-creds/*" {
  capabilities = ["read", "list"]
}

# List all dynamic and static roles
path "database/mongodb/roles" {
  capabilities = [ "list" ]
}
 
path "database/mongodb/static-roles" {
  capabilities = [ "list" ]
}

# Access initial mongodb secrets
path "secret/kv/data/mongo" {
  capabilities = [ "read" ]
}

# Access initial mongodb secrets
path "kv/data/mongo" {
  capabilities = [ "read" ]
}

# Access mongodb username & pass
path "database/mongodb/static-creds" {
  capabilities = ["read"]
}
