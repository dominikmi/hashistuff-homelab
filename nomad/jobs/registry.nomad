# Docker registry deployed in Nomad 0.10.5
# 01-05-2020, v0.0.2

job "registry" {
  datacenters = ["dc1"]
  type = "service"
  priority = 10
  constraint {
      attribute = "${attr.unique.hostname}"
      value     = "dmthin.nukelab.local"
  }
  constraint {
    attribute = "${attr.driver.docker.volumes.enabled}"
    value = "true"
  }
  update {
    stagger = "10s"
    max_parallel = 1
  }
  group "registry" {
    count = 1
    restart {
      attempts = 10
      interval = "5m"
      delay = "30s"
      mode = "delay"
    }

# This is where the registry gets deployed
		
    task "registry" {
      driver = "docker"
      config {
        volumes = [ "/mnt/registry:/var/lib/registry","/etc/vault.d/certs:/certs" ] 
        image = "registry"
        port_map = {
          registry_web_port = 5000
        }
      }
      env {
        "REGISTRY_HTTP_TLS_CERTIFICATE" = "/certs/full-chain-dmthin-peer.pem"
        "REGISTRY_HTTP_TLS_KEY" = "/certs/dmthin-peer-key.pem"
      }
      service {
        name = "registry"
        tags = ["global", "cache"]
        port = "registry_web_port"
        check {
	  name = "alive"
          type = "tcp"
          port = "registry_web_port"
	  interval = "10s"
	  timeout = "2s"
        }
      }
      resources {
	cpu = 500 # 500 Mhz
	memory = 256 # 256MB
	network {
	  mbits = "1"
	  port "registry_web_port" {
	    static = "5000"
          }
	}
      }
    } # close task
  } # close group
} # close job
