# Docker registry deployed in Nomad 1.2.3
# 08-01-2022, v0.2
# 22-06-2022, v0.3

job "registry" {
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
      port "web" { 
	      static = 5443
	      to     = 5443 
      }
      dns { servers = ["192.168.120.231"] }
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
        ports = ["web"] 
      }
      env {
#        REGISTRY_HTTP_HEADERS_ACCESS-CONTROL-ALLOW-ORIGIN="['*']"
#        REGISTRY_STORAGE_DELETE_ENABLED=true
#        REGISTRY_HTTP_HEADERS_ACCESS-CONTROL-ALLOW-METHODS="['HEAD', 'GET', 'OPTIONS', 'DELETE']"
#        REGISTRY_HTTP_HEADERS_ACCESS-CONTROL-EXPOSE-HEADERS="['Docker-Content-Digest']"
#        X-CONTENT-TYPE-OPTIONS="[nosniff]"
	REGISTRY_HTTP_ADDR="0.0.0.0:5443"
        REGISTRY_HTTP_TLS_CERTIFICATE = "/certs/powernuke-peer-fullchain.pem"
        REGISTRY_HTTP_TLS_KEY = "/private/powernuke-peer-key.pem"
        PORT = 5443
      }
      service {
        name = "registry"
        tags = ["global", "cache"]
        port = "web"
        check {
	  name            = "HTTPS check"
          type            = "http"
          protocol        = "https"
	  port            = "web"
	  path            = "/v2/_catalog"
	  interval        = "30s"
	  timeout         = "5s"
	  method	  = "GET"
        }
      }
      resources {
        cpu    = 200 # 200Mhz
        memory = 128 # 128 MB
      }
    } # close task
  } # close group
} # close job


