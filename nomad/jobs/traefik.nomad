# 09-09-2022, v0.1 Nomad 1.3.5
# Traefik test deployment

job "traefik" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 20  
  constraint {
      attribute = "${attr.unique.hostname}"
      value     = "powernuke"
  }
  update {
    stagger          = "15s"
    max_parallel     = 1
    min_healthy_time = "30s"
    healthy_deadline = "5m"
    auto_revert      = true
  }
  group "traefik" {
    count = 1
    update {
      auto_revert = true
    }
    network {
      port  "http" {
        to     = 80 
        static = 80
      }
      port "https" {
        to     = 443
        static = 443
      }
      port  "api" {
        to     = 8080
        static = 8080
      }
      dns {
        servers = ["192.168.120.231"]
      }
    }
    service {
      port = "http"
      tags = [
           "traefik",
           "traefik.enable=true",
           "traefik.http.routers.dashboard.rule=Host(`traefik.nukelab.home`)",
           "traefik.http.routers.dashboard.service=api@internal",
           "traefik.http.routers.dashboard.entrypoints=web,websecure"
      ]
      check {
       type     = "tcp"
       interval = "10s"
       timeout  = "5s"
      }
    }
    service {
      tags = ["lb", "api"]
      port = "api"
 
      check {
        type     = "http"
        path     = "/ping"
        interval = "10s"
        timeout  = "5s"
      }
    }

# This is where the Traefik is getting deployed

    task "proxy" {
      driver = "docker"
      config {
        image = "powernuke.nukelab.home:5443/traefik:2.8.4-8"
        ports = ["api", "http", "https"]
        args = [ "--configFile", 
                 "/local/traefik.yml",
                 "--providers.file.directory=/local/",
                 "--providers.file.watch=true"
        ]
      }
      vault {
        policies = ["traefik-access"]
      }

## setting up env variables

      template {
        data = <<EOH
{{ with secret "kv/data/traefik/nukelab" }}
CONSUL_HTTP_TOKEN={{.Data.data.consultoken | toJSON }}
TRAEFIK_PROVIDERS_CONSULCATALOG_ENDPOINT_TLS_CA={{.Data.data.ca | toJSON }}
TRAEFIK_PROVIDERS_CONSULCATALOG_ENDPOINT_TLS_CERT={{.Data.data.fullchain | toJSON }}
TRAEFIK_PROVIDERS_CONSULCATALOG_ENDPOINT_TLS_KEY={{.Data.data.certkey | toJSON }}
TRAEFIK_PROVIDERS_CONSULCATALOG_ENDPOINT_TOKEN={{.Data.data.consultoken | toJSON }}
{{ end }}
EOH 
        env         = true
        destination = "secrets/traefik.env"
        change_mode = "noop"
      }

## setting up primary dynamic config in the container's /local

      template {
       data        = <<EOH
tls:
 certificates:
   - certFile: /local/traefik.crt
     keyFile: /local/traefic.key
 stores:
   default:
     defaultCertificate:
       certFile: /local/traefik.crt
       keyFile: /local/traefik.key
EOH
       destination = "/local/dynamic.yml"
       change_mode = "restart"
       splay       = "1m"
     }

## filling up the traefik.crt and traefik.key from Vault and placing them in the /local sub-folder

      template {
        data        = <<EOH
{{ with secret "kv/data/traefik/nukelab" }}
{{ .Data.data.certkey | toJSON }}
{{ end }}
EOH
        destination = "/local/traefik.key"
        change_mode = "restart"
        splay       = "1m"
      }
      template {
        data        = <<EOH
{{ with secret "kv/data/traefik/nukelab" }}
{{ .Data.data.fullchain | toJSON }}
{{ end }}
EOH
        destination = "/local/traefik.crt"
        change_mode = "restart"
        splay       = "1m"
      }

## Setting up static config and populating it with already set stuff above

      template {
        data = <<EOH
{{ with secret "kv/data/traefik/nukelab" }}
serversTransport:
 insecureSkipVerify: true
entryPoints:
 web:
   address: ":80"
 websecure:
   address: ":443"
api:
 dashboard: true
 insecure: true
 debug: true
ping: {}
accessLog: {}
log:
 level: DEBUG
providers:
 providersThrottleDuration: 15s
 file:
   watch: true
   filename: "/local/dynamic.yml"
 consulCatalog:
   endpoint:
     scheme: "https"
     address: https://powernuke.nukelab.home:8501
     datacenter: nukelab
     token: {{ .Data.data.consultoken }} 
   cache: true
   prefix: traefik
   exposedByDefault: false
{{ end }}
EOH

       destination = "local/traefik.yml"
       change_mode = "noop"
     }
    }
  }
}
