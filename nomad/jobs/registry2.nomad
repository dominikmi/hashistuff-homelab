# Docker registry deployed in Nomad 1.3.5
# 08-01-2022, v0.2
# 22-06-2022, v0.3
# 16-09-2022, v0.4 registry+registry UI bound together

job "registry2" {
  datacenters = ["dc1"]
  type = "service"
  priority = 10
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
        "traefik.http.routers.registry-ui.rule=Host(`registry-ui.nukelab.home`)",
        "traefik.http.routers.registry-ui.tls=true",
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
	      image = "powernuke.nukelab.home:5443/registry:2.8.1-3"
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
    } # close task

    task "registry-ui" {
      driver = "docker"
      config {
        image = "joxit/docker-registry-ui:latest"
        ports = ["regui"]
      }
      env {
        REGISTRY_TITLE="Nukelab Docker Registry"
        REGISTRY_URL="https://powernuke.nukelab.home:5443"
        DELETE_IMAGES=true
        SINGLE_REGISTRY=true
      }      
      resources {
        cpu    = 200
        memory = 128
      }
    } # close task

  } # close group
} # close job