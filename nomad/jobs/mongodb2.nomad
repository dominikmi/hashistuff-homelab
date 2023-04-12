# MongoDB deployed in Nomad 1.2.6
# 26-03-2022, v0.1
# 12-06-2022, v0.2, Nomad 1.3.1, vault templates


job "mongodb" {
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
  group "mongodb" {
    count = 1
    restart {
      attempts = 10
      interval = "5m"
      delay = "30s"
      mode = "delay"
    }

# define network within the group

    network {
      port "mongo" { 
	      static = 27017
	      to     = 27017 
      }
      dns { servers = ["192.168.100.1"] }
    }

# This is where the mongodb gets deployed
		
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
      resources {
        cpu    = 512 # 512Mhz
        memory = 768 # 768Mb
      }
    } # close task
  } # close group
} # close job
