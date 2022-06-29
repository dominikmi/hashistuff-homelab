# Access mongodb username & pass

path "database/mongodb/static-creds/*" {
  capabilities = ["read"]
}

# Access other app's secrets

path "secret/kv/data/my-fs-app/*" {
  capabilities = ["read"]
}
