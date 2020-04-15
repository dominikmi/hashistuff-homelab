
### Create basic vault cluster. 
---

Once you installed vault binaries in the server and the client nodes, either using the [script](../bin/install_cluster.sh) or manually, you can start setting up basic vault cluster.

#### 1. Create libvirt zone services for vault

Add the following tcp/udp ports to the libvirt zone: 8200,8201; Then add tcp/8200 to the public zone (so we can access the Vault's web UI).

#### 2. Vault config 

We will use consul distributed storage for vault KV storesi\ using the encryption key we set [at step 2 of consul basic configuration](https://github.com/dominikmi/hashistuff/tree/master/consul#2-create-consul-encryption-key). The cluster communication is set within the libvirt network 192.168.100.0/24. Don't worry about TLS for now, we will set it up later.

(/etc/vault.d/vault.hcl)

```
listener "tcp" {
  address          = "0.0.0.0:8200"
  cluster_address  = "192.168.100.1:8201"
  # we will set the TLS for vault later
  tls_disable = "true"
#  tls_cert_file = "/path/to/fullchain.pem"
#  tls_key_file  = "/path/to/privkey.pem"
}

storage "consul" {
  address = "192.168.100.1:8500"
  path = "vault/"
  token = "3b6b2458-60d7-f2f6-b37b-87fa38aed3b9"
}

api_addr         = "http://192.168.100.1:8200"
cluster_addr     = "http://192.168.100.1:8201"
ui               = true
``` 

#### 2. Vault config on consul client (.101 & .102):

```
listener "tcp" {
  address          = "0.0.0.0:8200"
  cluster_address  = "192.168.100.101:8201"
  # we will set the TLS later
  tls_disable = "true"
#  tls_cert_file = "/path/to/fullchain.pem"
#  tls_key_file  = "/path/to/privkey.pem"
}

storage "consul" {
  address = "192.168.100.1:8500"
  path = "vault/"
  token = "3b6b2458-60d7-f2f6-b37b-87fa38aed3b9"
}

api_addr         = "http://192.168.100.101:8200"
cluster_addr     = "http://192.168.100.101:8201"
ui               = true
```

#### 3. Initialize vault 

First, start off the vault instance on the server node (.1) with `systemctl start vault`. Then, initialize vault  with the command of `vault operator init`. Save the below output the keys will be needed to unseal all vault instances and the Root Token will let you access vault cluster through CLI, webUI or API.

```
$ vault operator init
Unseal Key 1: w4yoo+p+5dZ9/9wOxB7SBRzuDprjdhX8gFPPUwONlGm7
Unseal Key 2: Hi2bIr34BbLvXp/Tove8Gp7IgOI1NNpv4oKR5hcZjfWz
Unseal Key 3: q2U2TO40ml1oGQJzNQh+ZStsLZhw45WVjUcNIg8PwRNK
Unseal Key 4: OPAJlTx4sySRCS9y9tuaqkj6aDA/3s7dLa5QK027sPqX
Unseal Key 5: H4Ac+fzSRAPw3l25o0AsrV1Dt2vc94r0oHRGHYCC/alL

Initial Root Token: s.xDSEC6uWw9N2EEqh2OodXSW7

Vault initialized with 5 key shares and a key threshold of 3. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 3 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated master key. Without at least 3 key to
reconstruct the master key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
```

#### 4. Unseal the vault cluster.

Set the VAULT_ADDR variable to the local vault API address as set in the config on each node.
Use `vault operator unseal` and supply one of the five unseal keys, you gotta supply three of them, repeatedly.
Repeat the procedure on each node.

Now, we can go back to [consul setup](../consul/README.md) to set up TLS and ACL. When that is accomplished, we will come back to vault LTS, and follow the remaining steps of this document.

#### 5. Set TLS and transit auto-unseal for vault

