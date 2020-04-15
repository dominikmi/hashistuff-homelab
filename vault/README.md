
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

First, follow the steps described in the [there](README-transit.md) to set up a Master Transit Vault instance. Then come back and continue here.

#### 6. Update vault config file

On all Vault cluster nodes extend the the config file (_/etc/vault.d/vault.hcl_), so the file looks like this:

```
listener "tcp" {
  address          = "0.0.0.0:8200"
  cluster_name	   = "vault.nukelab.local"
  cluster_address  = "192.168.100.1:8201"
  tls_disable      = 0
  tls_cert_file = "/etc/vault.d/certs/nuke-peer-fullchain.pem"
  tls_key_file  = "/etc/vault.d/certs/nuke-peer-key.pem"
}

storage "consul" {
  address = "192.168.100.1:8500"
  path = "vault/"
  token = "2ca570cd-a15e-2548-d974-d144561243a9"
}

seal "transit" {
  address            = "https://192.168.100.1:8280"
  token              = "s.gnXTrgVomni7kaIoB01fprAH"
  disable_renewal    = "true"
  tls_skip_verify    = "false"
  # Key configuration
  key_name           = "autounseal"
  mount_path         = "transit/"

  # TLS Configuration
  tls_ca_cert        = "/etc/vault.d/certs/intermediate_ca.pem"
  tls_client_cert    = "/etc/vault.d/certs/nuke-peer.pem"
  tls_client_key     = "/etc/vault.d/certs/nuke-peer-key.pem"
  tls_server_name    = "master-vault.nukelab.local"
  tls_skip_verify    = "false"
}

api_addr         = "https://192.168.100.1:8200"
cluster_addr     = "https://192.168.100.1:8201"
ui               = "true"
disable_mlock	 = "true"
```

The TLS which secures the vault cluster communication between the nodes is set within the `listener "tcp"` stanza, remember how the fullchain certificate is built. Next, we've got the `storage` stanza where you can see the token that will let the vault in to the consul cluster for storage. That token in Consul is associated with specific storage access policy ([ACL](../consul/README.md)). Then it comes to our `seal "transit"` stanza where we define the following: the URL of the Master Transit Vault, transit policy token, renewal is disabled, TLS is verified (we've got good certs, right?), and then lastly - the whole TLS config, so the auto-unseal policy is perfomed securily over the network. 

#### 7. Test the transit auto-unseal

First restart the vault.service (on all 3 vaults in nuke, worker01 and worker02). Run `vault operator unseal -migrate` - put the three keys, so the vault can migrate from shamir to transit. Now, check:

(first - the master transit vault):
```
$ export VAULT_ADDR=https://192.168.100.1:8280
$ vault status
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    5
Threshold       3
Version         1.3.4
Cluster Name    vault-cluster-dc1aaa8d
Cluster ID      dc7087ef-d24e-062a-5c0e-acffef171fbe
HA Enabled      false
```

(next, go to open ssh sessions to vault nodes and  check vault cluster agents (nuke, worker01, worker02):

```
$ export VAULT_ADDR=https://192.168.100.1:8200
$ vault status
Key                      Value
---                      -----
Recovery Seal Type       shamir
Initialized              true
Sealed                   false
Total Recovery Shares    5
Threshold                3
Version                  1.3.4
Cluster Name             vault-cluster-b238dd96
Cluster ID               f047ff31-214b-27f9-b047-2338d784206a
HA Enabled               true
HA Cluster               https://192.168.100.1:8201
HA Mode                  active
```

Now, if you restart any of the three vault agents and run `sudo systemctl status vault` you should get the following information:
```
● vault.service - "HashiCorp Vault - A tool for managing secrets"
   Loaded: loaded (/etc/systemd/system/vault.service; enabled; vendor preset: disabled)
   Active: active (running) since Wed 2020-04-15 22:23:46 CEST; 2s ago
     Docs: https://www.vaultproject.io/docs/
 Main PID: 26875 (vault)
    Tasks: 13 (limit: 26213)
   Memory: 21.2M
   CGroup: /system.slice/vault.service
           └─26875 /usr/bin/vault server -config=/etc/vault.d/vault.hcl

Apr 15 22:23:46 nuke.nukelab.local vault[26875]:                  Storage: consul (HA available)
Apr 15 22:23:46 nuke.nukelab.local vault[26875]:                  Version: Vault v1.3.4
Apr 15 22:23:46 nuke.nukelab.local vault[26875]: ==> Vault server started! Log data will stream in below:
Apr 15 22:23:46 nuke.nukelab.local vault[26875]: 2020-04-15T22:23:46.258+0200 [INFO]  proxy environment: http_proxy= https_proxy= no_proxy=
Apr 15 22:23:46 nuke.nukelab.local vault[26875]: 2020-04-15T22:23:46.308+0200 [INFO]  core: stored unseal keys supported, attempting fetch
Apr 15 22:23:46 nuke.nukelab.local vault[26875]: 2020-04-15T22:23:46.345+0200 [INFO]  core.cluster-listener: starting listener: listener_address=192.168.100.1:8201
Apr 15 22:23:46 nuke.nukelab.local vault[26875]: 2020-04-15T22:23:46.345+0200 [INFO]  core.cluster-listener: serving cluster requests: cluster_listen_address=192.168.100.1:8201
Apr 15 22:23:46 nuke.nukelab.local vault[26875]: 2020-04-15T22:23:46.346+0200 [INFO]  core: entering standby mode
Apr 15 22:23:46 nuke.nukelab.local vault[26875]: 2020-04-15T22:23:46.347+0200 [INFO]  core: vault is unsealed
Apr 15 22:23:46 nuke.nukelab.local vault[26875]: 2020-04-15T22:23:46.347+0200 [INFO]  core: unsealed with stored keys: stored_keys_used=1
```

This restarted instance becomes a **standby** instance, got itself unsealed using the key in the config, using Consul storage. That's it.

