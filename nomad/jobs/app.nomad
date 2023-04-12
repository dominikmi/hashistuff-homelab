# App deployment in Nomad 1.3.3
# w/ vault templates and Mongo as pre-start sidecar
# w/ Traefik labels and global TLS entrypoint

job "myapp" {
  datacenters = ["dc1"]
  type = "service"
  namespace = "production"
  priority = 20
  constraint {
    attribute = "${attr.unique.hostname}"
    value     = "srv1u100"
  }
  update {
    stagger          = "10s"
    max_parallel     = 1
    min_healthy_time = "30s"  
    healthy_deadline = "5m"
    auto_revert      = true
  }
  group "myapp" {
    count = 1
    restart {
      attempts = 10
      interval = "5m"
      delay = "30s"
      mode = "delay"
    }

# define network within the group

    network {
      port "app" { 
        static = 3000
	to     = 3000 
      }
      port "mongo" { 
	static = 27017
	to     = 27017 
      }
      dns { servers = ["192.168.100.1"] }
    }

# services definition and labelling

    service {
      name = "mongodb"
      tags = ["global", "cache"]
      port = "mongo"
      check {
        name     = "tcp_validate"    
        type     = "tcp"    
        port     = "mongo"    
        interval = "15s"    
        timeout  = "30s"
      }
    }

    service {
      name="myapp"
      tags = [
        "traefik",
        "traefik.enable=true",
        "traefik.http.routers.myapp.rule=Host(`myapp.nukelab.home`)",
        "traefik.http.routers.myapp.tls=true",
      ]
      port = "app"
      check {
        name     = "app_health"    
        type     = "http"
        path     = "/"    
        port     = "app"    
        interval = "30s"    
        timeout  = "10s"
      }
    }

# This is where MongoDB as sidecar is deployed

    task "mongo" {
      driver = "docker"
      config {
	      image = "powernuke.nukelab.home:5443/mongodb:4.4.19-1"
	      volumes = [ "/data/mongodb/data:/data/db", ]
        ports = ["mongo"] 
      }
      vault {
        policies = ["mongodb-access"]
      }
      template {
        destination = "secrets/file.env"
        env = true
# Read mongo secrets from Vault
        data = <<EOF
{{with secret "kv/data/mongo"}}
{{range $key, $value := .Data.data}}
{{$key}}={{$value | toJSON}}{{end}}
{{end}}
EOF
      }
      lifecycle {
        sidecar = true
        hook = "prestart"
      }      
      resources {
        cpu    = 512 # 512Mhz
        memory = 1024 # 1GB
      }
    } # close task

# This is where the app gets deployed
		
    task "myapp" {
      driver = "docker"
      config {
	      image = "powernuke.nukelab.home:5443/my-fs-app:0.8.3"
        ports = ["app"] 
      }
      vault {
        policies = ["my-fs-app-access"]
      }
      template {
        destination = "secrets/file.env"
        env = true
# Read app secrets from Vault
        data = <<EOF
{{with secret "kv/data/my-fs-app"}}
{{range $key, $value := .Data.data}}
{{$key}}={{$value | toJSON}}{{end}}
{{end}}
EOF
      }      
      resources {
        cpu    = 128 # 128Mhz
        memory = 256 # 256MB
      }
    } # close task
  } # close group
} # close job
