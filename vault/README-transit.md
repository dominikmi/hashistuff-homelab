
### How to get working vault in the transit auto-unseal scenario?
---

#### 1. Another vault service.

First, we need to set up another vault service. A single instance vault on the host for the whole lab.
We can use the vault part of that [script](../bin/install_cluster.sh).

Our transit vault instance service will be named "master-vault.service" and use ports 8280/tcp and 8281/tcp.

#### 2. Master Vault configuration

As you can see, it is configured already with TLS support. Once we finish with Master Vault settings, we'll get back to our initial Vault cluster settings to get the TLS done there as well. I am not going to get it too complex, therefore I went for `file` as a local storage for this vault instance.

```
listener "tcp" {
  address          = "0.0.0.0:8280"
  cluster_address  = "192.168.100.1:8281"
  cluster_name	   = "master-vault.nukelab.local"
  tls_disable      = 0
  tls_cert_file = "/etc/master-vault.d/certs/nuke-peer-fullchain.pem"
  tls_key_file  = "/etc/master-vault.d/certs/nuke-peer-key.pem"
}

storage "file" {
  path = "/var/devops/vault/data"
}

api_addr         = "https://192.168.100.1:8280"
cluster_addr     = "https://192.168.100.1:8281"
ui               = true
tls_skip_verify	 = false
disable_mlock	 = true
```

Next, this needs to be initiatied and unsealed. Without any AWS or GCP KMS instance this will have to stay like that. And no, I do not keep an HSM at home either. :)

```
$ export VAULT_ADDR=https://192.168.120.150:8280
$ vault operator init
Unseal Key 1: Q09+ux7A4e53cwIDlFekqL5/u19fT7dDcw3IomCF/pai
Unseal Key 2: 1bXZAL0ypg5NbhIUpTLu2Sma9d8AL3Ve85T4HCIekyaK
Unseal Key 3: RRe1kurXUpWhRd5+fq7NcCvO9DqVmX+INpfiYi9L6Gun
Unseal Key 4: 48nEDCPzDySgPeP44erG4nQ5QaLLgHZvRbEszAZcPLB+
Unseal Key 5: ruZAcbBDG6Ghw83fig9J5goki4ZVhxVDEyq8Tutc53OT

Initial Root Token: s.0JSGN8zTTp1TOzL3jsfynC80
[..]
```

#### 3. Transit policy

The following steps will get us ready for the transit auto-unseal scenario:

* `$ export VAULT_TOKEN=s.0JSGN8zTTp1TOzL3jsfynC80`
* `$ vault write -f transit/keys/autounseal`
*  Create autounseal policy:

```
$ tee /etc/master-vault.d/policies/autounseal.hcl <<EOF
path "transit/encrypt/autounseal" {
   capabilities = [ "update" ]
}

path "transit/decrypt/autounseal" {
   capabilities = [ "update" ]
}
EOF
```

* Apply the policy: 

```
$ vault policy write autounseal policies/autounseal.hcl
Success! Uploaded policy: autounseal
```

* Create token:

Log in to the Vault UI, virtual CLI, type: `vault write auth/token/create policies=autounseal`

```
Key            Value                     
client_token   s.gnXTrgVomni7kaIoB01fprAH
accessor       cNBdmT0RNEicFpz1FuxJAdIc  
policies       ["autounseal","default"]  
token_policies ["autounseal","default"]  
metadata       null                      
lease_duration 2764800                   
renewable      true                      
entity_id                                
token_type     service                   
orphan         false
```

The `client_token` is the encryption token that we have to use in all vault cluster nodes configuration. Let's get [there](README.md)


                   
