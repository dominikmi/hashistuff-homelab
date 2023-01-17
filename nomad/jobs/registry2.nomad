# Docker registry deployed in Nomad 1.3.5
# 08-01-2022, v0.2
# 22-06-2022, v0.3
# 16-09-2022, v0.4 registry+registry UI bound together
# 03-10-2022, v0.5 registry+UI set as dependent deployment
# 06-10-2022, v0.6 with Traefik tags in

job "registry2" {
  datacenters = ["dc1"]
  type        = "service"
  namespace   = "infra"
  priority    = 10
  constraint {
      attribute = "${attr.unique.hostname}"
      value     = "powernuke"
  }
  update {
    stagger          = "10s"
    max_parallel     = 1
    min_healthy_time = "30s"  
    healthy_deadline = "5m"
    auto_revert      = true
  }
  group "registry" {
    count = 1
    restart {
      attempts = 10
      interval = "5m"
      delay = "30s"
      mode = "delay"
    }

# define network within the group

    network {
      mode = "bridge"
      port "reg" { 
	      static = 5443
	      to     = 5443 
      }

      port "regui" {
        static = 8880
        to     = 80
      }

      dns { servers = ["192.168.120.231"] }
    }

# services

    service {
      name = "registry"
      tags = [
        "traefik",
        "traefik.enable=true",
        "traefik.http.routers.registry.rule=Host(`registry.nukelab.home`)",
        "traefik.http.routers.registry.tls=true",
      ]
      port = "reg"
      check {
	      name            = "HTTPS check"
        type            = "http"
        protocol        = "https"
	      port            = "reg"
	      path            = "/v2/_catalog"
	      interval        = "30s"
	      timeout         = "5s"
	      method	  = "GET"
      }
    }

    service {
      name = "registry-ui"
      tags = [
        "traefik",
        "traefik.enable=true",
        "traefik.http.routers.regui.rule=Host(`regui.nukelab.home`)",
        "traefik.http.routers.regui.tls=true"
      ]
      port = "regui"
      check {
        name     = "HTTP check"
        type     = "http"
        port     = "regui"
        path     = "/"
        interval = "30s"
        timeout  = "5s"
        method   = "GET"
      }
    }

# This is where the registry gets deployed
		
    task "registry" {
      driver = "docker"
      config {
	      image   = "powernuke.nukelab.home:5443/registry:2.8.1-7"
        command = "registry"
        args    = [ "serve", "/local/registry-config.yml" ]
	      volumes = [
	        "/data/registry:/var/lib/registry",
	        "/etc/pki/tls/certs/powernuke-peer-fullchain.pem:/certs/powernuke-peer-fullchain.pem",
	        "/etc/pki/tls/private/powernuke-peer-key.pem:/private/powernuke-peer-key.pem"
        ]
        ports = ["reg"] 
      }
      env {
	      REGISTRY_HTTP_ADDR="0.0.0.0:5443"
        REGISTRY_HTTP_TLS_CERTIFICATE = "/certs/powernuke-peer-fullchain.pem"
        REGISTRY_HTTP_TLS_KEY = "/private/powernuke-peer-key.pem"
        PORT = 5443
      }
      resources {
        cpu    = 200 # 200Mhz
        memory = 128 # 128 MB
      }
      template {
        data = <<EOH
version: 0.1
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
  delete:
    enabled: true
http:
  addr: :5000
  headers:
    Access-Control-Allow-Origin: ['*']
    Access-Control-Allow-Methods: ['HEAD', 'GET', 'OPTIONS', 'DELETE']
    Access-Control-Allow-Headers: ['Authorization', 'Accept']
    Access-Control-Max-Age: [1728000]
    Access-Control-Allow-Credentials: [true]
    Access-Control-Expose-Headers: ['Docker-Content-Digest']
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
EOH

      destination = "/local/registry-config.yml"
      change_mode = "restart"
      }
      lifecycle {
        sidecar = true
        hook = "prestart"
      }
    } # close task

    task "registry-ui" {
      driver = "docker"
      config {
        image = "joxit/docker-registry-ui:2.3.0"
        ports = ["regui"]
      }
      env {
        REGISTRY_TITLE="Nukelab Docker Registry"
        REGISTRY_URL="https://powernuke.nukelab.home:5443"
        DELETE_IMAGES=true
        SINGLE_REGISTRY=true
#        NGINX_PROXY_PASS_URL="https://registry-ui.nukelab.home"
      }      
      resources {
        cpu    = 200
        memory = 128
      }  
    } # close task
  } # close group
} # close job
