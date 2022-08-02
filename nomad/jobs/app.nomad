# App deployment in Nomad 1.3.1
# w/ vault templates


job "my-fs-app" {
  datacenters = ["dc1"]
  type = "service"
  priority = 10
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
  group "application" {
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
      dns { servers = ["192.168.100.1"] }
    }

# This is where the app gets deployed
		
    task "app-instance" {
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
      service {
        name = "app-instance"
        tags = ["global", "cache"]
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
      resources {
        cpu    = 128 # 128Mhz
        memory = 256 # 256MB
      }
    } # close task
  } # close group
} # close job
