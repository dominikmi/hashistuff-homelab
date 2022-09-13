# a test job for Traefik proxy testing
# v0.1

job "whoami" {
  type        = "service"
  datacenters = ["dc1"]
  constraint {
      attribute = "${attr.unique.hostname}"
      value     = "srv2u100"
  }
  group "whoami" {
 
    network {
      port "http" {
        static = 80
      }
    }
 
    service {
      tags = [
        "traefik",
        "traefik.enable=true",
        "traefik.http.routers.whoami.rule=Host(`whoami.nukelab.home`)",
        "traefik.http.routers.whoami.tls=true"
      ]
      port = "http"
      check {
        type     = "tcp"
        interval = "10s"
        timeout  = "5s"
      }
    }
    task "whoami" {
      driver = "docker"
      config {
        image = "traefik/whoami"
        ports = ["http"]
      }
      resources {}
    }
  }
}
