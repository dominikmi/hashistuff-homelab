# Initial basic config v0.1
# 03-12-2022 Nomad v1.4.3

job "mosquitto" {
  datacenters = ["dc1"]
  type        = "service"
  namespace   = "IoT"
  priority    = 10  
  constraint {
      attribute = "${attr.unique.hostname}"
      value     = "powernuke"
  }
  update {
    stagger          = "15s"
    max_parallel     = 1
    min_healthy_time = "30s"
    healthy_deadline = "5m"
    auto_revert      = true
  }
  group "mosquitto" {
    count = 1
    network {
      mode = "bridge"
      port  "mqtt" {
        to     = 1883 
        static = 1883
      }
      dns {
        servers = ["192.168.120.231"]
      }
    }

## set up labels passed on to Traefik for handling access over proxied mqtt & websocket ports

    service {
      port = "mqtt"
      tags = [
        "traefik",
        "traefik.enable=true",
        "traefik.tcp.services.mqtt.loadbalancer.server.port=1883",
        "traefik.tcp.routers.tcpr_mqtt.entrypoints=mqtt",
        "traefik.tcp.routers.tcpr_mqtt.rule=HostSNI(`mosq.nukelab.home`)",
        "traefik.tcp.routers.tcpr_mqtt.service=mqtt"
      ]
      check {
       type     = "tcp"
       interval = "15s"
       timeout  = "5s"
      }
    }

## This is where the mosquitto gets deployed with initial config arguments

    task "mosquitto-instance" {
      driver = "docker"
      config {
        command       = "mosquitto"
        args          = [ "-c", "/local/mosquitto.conf" ]
        image         = "powernuke.nukelab.home:5443/mosquitto:2.0.15-3"
        volumes = [
          "/data/mosquitto/data:/mosquitto/data",
          "/data/mosquitto/logs:/mosquitto/logs"
        ]
        ports = ["mqtt", "websockets", "secwebsockets"]
      }
      vault {
        policies = ["mosquitto-access"]
      }

## Creating password files for mqtt, websockets and securewebsockets
## Vault was populated with the results of mosquitto_passwd -c <passwordfile> <user> per each service

      template {
        data        = <<EOH
{{ with secret "kv/data/mosquitto/passwordfiles" }}
{{ .Data.data.pwdmqtt }}
{{ end }}
EOH
        destination = "/local/pwdmqtt.txt"
        change_mode = "restart"
        splay       = "1m"
      }
      template {
        data        = <<EOH
per_listener_settings true
connection_messages true
log_timestamp true
log_type websockets
log_type error
log_type warning
log_type notice
log_type information
log_type debug
log_type subscribe
log_type unsubscribe
log_type all
websockets_log_level 14

persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/log/mosquitto.log

listener 1883
allow_anonymous false
password_file /local/pwdmqtt.txt
EOH
       destination = "local/mosquitto.conf"
       change_mode = "noop"
     }
    }
  }
}
