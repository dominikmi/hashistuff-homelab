# MinIO server deployed in Nomad 1.5.6
# 14-06-2023, v1.0

job "minio-server" {
  datacenters = ["dc1"]
  namespace = "infra"
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
  group "minio-server" {
    count = 1
    restart {
      attempts = 10
      interval = "5m"
      delay = "30s"
      mode = "delay"
    }

# define network within the group

    network {
      port "api" {
        static = 9900 # Port to be exposed
        to     = 9000 # port on the docker side
      }
      port "console" {
        static = 9901 # port to be exposed
        to     = 9001 # port on the docker side
      }
      dns { servers = ["192.168.120.231"] }
    }

# Services in Consul mesh

    service {
      name = "minio-console"
      tags = [
        "traefik",
        "traefik.enable=true",
        "traefik.http.routers.miniocon.rule=Host(`miniocon.nukelab.home`)",
        "traefik.http.routers.miniocon.tls=true"
      ]
      port = "console"
      check {
        name     = "HTTP_check"
        type     = "http"
        port     = "console"
        path     = "/"
        interval = "30s"
        timeout  = "5s"
        method   = "GET"
      }
    }

    service {
      name = "minio-api"
      tags = [
          "traefik",
          "traefik.enable=true",
          "traefik.http.routers.minioapi.rule=Host(`minioapi.nukelab.home`)",
          "traefik.http.routers.minioapi.tls=true"
      ]
      port = "api"
      check {
          name     = "tcp_validate"    
          type     = "tcp"    
          port     = "api"    
          interval = "15s"    
          timeout  = "30s"
      }
    }

# This is where the minio server gets deployed
		
    task "minio-server" {
      driver = "docker"
      config {
        image = "powernuke.nukelab.home:5443/minio:1.0-2"
        volumes = [ "/data/minio/data:/data", ]
        ports = ["api","console"]
        args = ["server","/data","--console-address", ":9001"]
      }
      vault {
        policies = ["minio-access"]
      }
      template {
        destination = "secrets/file.env"
        env = true
# Read minio admin credentials from Vault
        data = <<EOF
{{with secret "kv/data/minio"}}
{{range $key, $value := .Data.data}}
{{$key}}={{$value | toJSON}}{{end}}
{{end}}
EOF
        change_mode = "restart"
      }
      resources {
        cpu    = 400 # 400Mhz
        memory = 512 # 512 MB
      }
    } # close task
  } # close group
} # close job