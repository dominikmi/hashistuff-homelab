i# Access apps secrets

path "kv/data/my-fs-app" {
  capabilities = ["read"]
}

path "secret/kv/data/my-fs-app" {
  capabilities = ["read"]
}

