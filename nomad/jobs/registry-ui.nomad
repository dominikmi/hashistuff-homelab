# Docker registry with UI deployed in Nomad 1.2.3
# 12-01-2022, v0.3
# 22-06-2022, v0.4

job "registry-ui" {
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
  group "registry-ui" {
    count = 1
    restart {
      attempts = 10
      interval = "5m"
      delay = "30s"
      mode = "delay"
    }

# define network within the group

    network {
      port "regui" {
        static = 8880
        to     = 80
      }
      dns { servers = ["192.168.120.231"] }
    }

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
      service {
        name = "registry-ui"
        tags = ["global", "cache"]
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
      resources {
        cpu    = 200
        memory = 128
      }
    } # close task

  } # close group
} # close job
