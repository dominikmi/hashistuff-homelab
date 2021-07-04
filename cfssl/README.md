### Important note

The below description is still valid, although requires some refresh. The steps #1 through #8 are already automated through [cfssl-pki ansible role](https://github.com/dominikmi/ansible-homelab/tree/main/playbooks/roles/cfssl-pki).  

#### 1. Install cfssl & cfssljson from the github repo 

The official v1.2 binaries contain bug. You can install and perform the whole procesure anywhere, but at the end you will have to manually distribute the certs. I am installing it on my Fedora 31 laptop, and later on I am going to distribute the certs manually to the NUC host and the virtual machines.

* `$ sudo yum install go` (this will install 1.16 on Fedora 34 or CentOS 8)
* `$ go get -u github.com/cloudflare/cfssl/cmd/cfssl`
* `$ sudo cp ~/go/bin/cfssl /usr/local/bin/cfssl`
* `$ go get -u github.com/cloudflare/cfssl/cmd/cfssljson`
* `$ sudo cp ~/go/bin/cfssljson /usr/local/bin/cfssljson`

#### 2. Check installed wersion 
```
$ cfssl version
Version: dev
Runtime: go1.13.6
```

#### 3. Create configs for ca & intermediate certs

The root of all certificates is a certificate authority - the CA. It signs all other certificates. Usually, a Root CA cert is used to create intermediate CAs. These intermediates ones are used to sign certificates for clients, servers and peers (hosts that can offer both client and a server TLS secured services). The intermediate certificates provide additional layer of security, as the CAs are not needed to be used to issue host/client/peer certificates and it's always safer to store them at some trusted and secure place.

##### 2.1 Create a __ca.json__ config for CA CSR, 
```
{
  "CN": "Nukelab CA",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
  {
    "C": "PL",
    "L": "Warsaw",
    "O": "Nukelab",
    "OU": "Nukelab Root CA",
    "ST": "Maz"
  }
 ]
}
```

##### 2.2 Create profile config with intermediate ca, server, client, peer profiles - (__cfssl.json__)

These profiles will be used to create appropriate certificates.

```
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "intermediate_ca": {
        "usages": [
            "signing",
            "digital signature",
            "key encipherment",
            "cert sign",
            "crl sign",
            "server auth",
            "client auth"
        ],
        "expiry": "8760h",
        "ca_constraint": {
            "is_ca": true,
            "max_path_len": 0, 
            "max_path_len_zero": true
        }
      },
      "peer": {
        "usages": [
            "signing",
            "digital signature",
            "key encipherment", 
            "client auth",
            "server auth"
        ],
        "expiry": "8760h"
      },
      "server": {
        "usages": [
          "signing",
          "digital signing",
          "key encipherment",
          "server auth"
        ],
        "expiry": "8760h"
      },
      "client": {
        "usages": [
          "signing",
          "digital signature",
          "key encipherment", 
          "client auth"
        ],
        "expiry": "8760h"
      }
    }
  }
}
```

##### 2.3 Create Intermediate cert config file intermediate-ca.json
```
{
  "CN": "Nukelab Intermediate CA",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C":  "PL",
      "L":  "Warsaw",
      "O":  "Nukelab",
      "OU": "Nukelab Intermediate CA",
      "ST": "Maz"
    }
  ],
  "ca": {
    "expiry": "42720h"
  }
}
```

#### 3. Put the __\*.json__ files into the "config" folder.

#### 4. Generate the CA certificate

Command:  `$ cfssl gencert -initca config/ca.json | cfssljson -bare ca`

You get three files:

	* ca.csr - signing request,
	* ca.pem - certificate,
	* ca-key.pem - private key to the certificate.

#### 5. Create Intermediate CA

Command: `$ cfssl gencert -initca intermediate-ca.json | cfssljson -bare intermediate_ca`

You get another three files:

	* intermediate_ca.csr
	* intermediate_ca.pem
	* intermediate_ca-key.pem

Now, sign the Intermediate CA with the CA cert and the CA private key, to authorize it, and specifying intermediate_ca profile from the cfssl.json file I set before: 

`$ cfssl sign -ca ca.pem -ca-key ca-key.pem -config cfssl.json -profile intermediate_ca intermediate_ca.csr | cfssljson -bare intermediate_ca`

Output:
`2020/04/07 21:32:21 [INFO] signed certificate with serial number 128342806306350742550817444069814883502879308978`

#### 7. Now, we need to specify the config for our host/peer certificate. 

Our NUC host has two interfaces: 

* wlan - 192.168.120.150 (facing LAN)
* libvirt - 192.168.100.1 (facing virtual stuff)

The host has also DNS names configured:

* nuke.nukelab.local resolves to 192.168.120.150
* nukeint.nukelab.local resolves to 192.168.100.1
* localhost of course, resolves back to 127.0.0.1 (required if you do some nomad operations from within the host),

Also there are DNS aliases pointing to the CNAME of nuke.nukelab.local:
consul, nomad, vault, master-vault.

There's one more thing - Nomad and Consul themselves create those fancy "dns" names like server.nukelab.nomad server.nukelab.consul.
Plus, vault requires fully chained host pem file (host, intermediate, ca - in that order!) + the key.

Here's the config for the NUC host:

```
{
  "CN": "nuke.nukelab.local",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
  {
    "C": "PL",
    "L": "Warsaw",
    "O": "Nukelab",
    "OU": "Nukelab Hosts",
    "ST": "Maz"
  }
  ],
  "hosts": [
    "nuke.nukelab.local",
    "localhost",
    "192.168.100.1",
    "192.168.120.150",
    "127.0.0.1",
    "nukeint.nukelab.local",
    "nomad.nukelab.local",
    "consul.nukelab.local",
    "vault.nukelab.local",
    "master-vault.nukelab.local",
    "server.nukelab.nomad",
    "server.nukelab.consul"
  ]
}
```

#### 8. Generate the host cert for nuke.nukelab.local 

I need to apply the profile "peer" from _cfssl.json_ because the nomad agent reports back to itself as local client as well:

```
$ cfssl gencert -ca intermediate_ca.pem -ca-key intermediate_ca-key.pem -config config/cfssl.json -profile=peer config/nuke.json | cfssljson -bare nuke-peer
2020/04/07 22:08:27 [INFO] generate received request
2020/04/07 22:08:27 [INFO] received CSR
2020/04/07 22:08:27 [INFO] generating key: rsa-2048
2020/04/07 22:08:27 [INFO] encoded CSR
2020/04/07 22:08:27 [INFO] signed certificate with serial number 558685408516880036014304522581786694302670973084
```

We should have another three files now:

	* nuke-peer.csr
	* nuke-peer.pem
	* nuke-peer-key.pem

#### 9. Let's verify the cert and its key
```
$ openssl verify nuke-server.pem
C = PL, ST = Maz, L = Warsaw, O = Nukelab, OU = Nukelab Hosts, CN = nuke.nukelab.local
error 20 at 0 depth lookup: unable to get local issuer certificate
error nuke-server.pem: verification failed
```

#### 10. Add CA and intermediate CA to the host trusted store (on the NUC host)

	* `sudo cp -rp ca.pem /etc/pki/ca-trust/source/anchors/ca.pem`
	* `sudo cp -rp intermediate_ca.pem /etc/pki/ca-trust/source/anchors/intermediate_ca.pem`
	* `sudo update-ca-trust extract`

#### 11. Re-run verification

```
$ openssl verify nuke-peer.pem 
nuke-server.pem: OK
```

#### 12. Do the same (steps 7-9, the 9th step will work) for both nomad client nodes - generate and verify the cert:

	* worker01.nukelab.local
	* worker02.nukelab.local

```
$ cfssl gencert -ca intermediate_ca.pem -ca-key intermediate_ca-key.pem -config config/cfssl.json -profile=client config/worker01.json | cfssljson -bare worker01-client
2020/04/07 22:22:17 [INFO] generate received request
2020/04/07 22:22:17 [INFO] received CSR
2020/04/07 22:22:17 [INFO] generating key: rsa-2048
2020/04/07 22:22:17 [INFO] encoded CSR
2020/04/07 22:22:17 [INFO] signed certificate with serial number 598288729477799301567979947187497312899893724313
$ cfssl gencert -ca intermediate_ca.pem -ca-key intermediate_ca-key.pem -config config/cfssl.json -profile=client config/worker02.json | cfssljson -bare worker02-client
2020/04/07 22:22:27 [INFO] generate received request
2020/04/07 22:22:27 [INFO] received CSR
2020/04/07 22:22:27 [INFO] generating key: rsa-2048
2020/04/07 22:22:27 [INFO] encoded CSR
2020/04/07 22:22:27 [INFO] signed certificate with serial number 658624310197958763086567018155196969147016639420
```

The workers config file looks like this (for the .101):
```
{  
  "CN": "worker01.nukelab.local",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
  {
    "C": "PL",
    "L": "Warsaw",
    "O": "Nukelab",
    "OU": "Nukelab Hosts",
    "ST": "Maz"
  }
  ],
  "hosts": [
    "worker01.nukelab.local",
    "localhost",
    "127.0.0.1",
    "192.168.100.101",
    "client.nukelab.nomad",
    "client.nukelab.consul"
  ]
}
```

The config file work the second worker will look almost the same - you just need to replace worker01 with worker02 and change the IP last octet to 102.

#### 13. Load the CA certs to the virtual machines

On Ubuntu 16.04 (both workers), add the ca and intermediate ca to the trusted ca store with the following commands:

```
root@worker01:~# cp ca.pem /usr/local/share/ca-certificates/ca.crt
root@worker01:~# cp intermediate_ca.pem /usr/local/share/ca-certificates/intermediate_ca.crt
root@worker01:~# update-ca-certificates 
Updating certificates in /etc/ssl/certs...
2 added, 0 removed; done.
Running hooks in /etc/ca-certificates/update.d...
done.
```

We are now set, to utilize host (server, peer, client) certificates required for any TLS secured operations in Nomad, Consul and Vault.
The signing intermediate CA along with the host cert and host key should be placed (and eventually chown-ed to right user) in the /etc/nomad.d/certs , /etc/consul.d/certs and /etc/vault.d/certs .
Remember that Vault requires also a fullchained host certificate (from top-down: host, intermediate, root). 
