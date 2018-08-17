variable "workdir" {
    type    = "string"
    default = "./"
}

variable "DBConn" {
    type = "map"

    default = {
        DBHost = "postgresql"
        DBUser = "zabbix"
        DBPass = "123456"
        DBData = "/var/lib/postgresql/data/pgdata"
    }
}

resource "docker_image" "zabbix-backend" {
    name = "zabbix/zabbix-server-pgsql:centos-3.4-latest"
}

resource "docker_image" "zabbix-frontend-nginx" {
    name = "zabbix/zabbix-web-nginx-pgsql:alpine-3.4-latest"
}

resource "docker_image" "zabbix-agent" {
    name = "zabbix/zabbix-agent:alpine-3.4-latest"
}

resource "docker_image" "postgresql" {
    name = "postgres:10.5-alpine"
}

resource "docker_image" "nginx" {
    name = "nginx:1.14-alpine"
}

resource "docker_network" "test" {
    name = "example.com"
}

provider "docker" {
    host = "unix:///var/run/docker.sock"
}

resource "docker_container" "zabbix-backend" {
    count   = 1
    image   = "${docker_image.zabbix-backend.name}"
    name    = "zabbix-backend"
    restart = "unless-stopped"

    network_alias = [ "zabbix-server" ]

    ports {
        internal = 10051
        external = 10051
    }

    volumes {
        container_path = "/usr/lib/zabbix/alertscripts/line_notify.sh"
        host_path      = "${var.workdir}/Terraform/zabbix-test/line_notify.sh"
        read_only      = true
    }

    env = [
            "DB_SERVER_HOST=${var.DBConn["DBHost"]}",
            "POSTGRES_USER=${var.DBConn["DBUser"]}",
            "POSTGRES_PASSWORD=${var.DBConn["DBPass"]}",
            "TZ=Asia/Taipei"
        ]

    networks = [ "${docker_network.test.name}" ]
}

resource "docker_container" "zabbix-frontend" {
    count           = 1
    image           = "${docker_image.zabbix-frontend-nginx.name}"
    name            = "zabbix-frontend"
    restart         = "on-failure"
    max_retry_count = "3"
    network_alias   = [ "zabbix-frontend" ]

    ports {
        internal = 80
        external = 80
    }

    env = [
            "DB_SERVER_HOST=${var.DBConn["DBHost"]}",
            "POSTGRES_USER=${var.DBConn["DBUser"]}",
            "POSTGRES_PASSWORD=${var.DBConn["DBPass"]}",
            "TZ=Asia/Taipei",
            "PHP_TZ=Asia/Taipei"
        ]

    networks = [ "${docker_network.test.name}" ]
}

resource "docker_container" "zabbix-agent" {
    count           = 1
    image           = "${docker_image.zabbix-agent.name}"
    name            = "zabbix-agent"
    restart         = "on-failure"
    max_retry_count = "3"
    network_alias   = [ "zabbix-agent" ]

    env = [ "ZBX_HOSTNAME=zabbix-agent", "ZBX_SERVER_HOST=zabbix-server" ]
    networks = [ "${docker_network.test.name}" ]
}

resource "docker_container" "postgresql" {
    count   = 1
    image   = "${docker_image.postgresql.name}"
    name    = "${var.DBConn["DBHost"]}"
    restart = "unless-stopped"

    network_alias = [ "${var.DBConn["DBHost"]}" ]

    ports {
        internal = 5432
        external = 5432
    }

    volumes {
        container_path = "${var.DBConn["DBData"]}"
        host_path      = "${var.workdir}/Docker/postgresql/zabbix"
    }

    env = [
            "DB_SERVER_HOST=${var.DBConn["DBHost"]}",
            "POSTGRES_USER=${var.DBConn["DBUser"]}",
            "POSTGRES_PASSWORD=${var.DBConn["DBPass"]}",
            "PGDATA=${var.DBConn["DBData"]}"
        ]

    networks = [ "${docker_network.test.name}" ]
}

resource "docker_container" "nginx" {
    count   = 1
    image   = "${docker_image.nginx.name}"
    name    = "nginx${format("%02d",count.index + 1)}"
    restart = "unless-stopped"

    network_alias = [ "nginx" ]

    volumes {
        container_path = "/etc/nginx/conf.d/default.conf"
        host_path      = "${var.workdir}/Docker/nginx/default.conf"
        read_only      = true
    }

    volumes {
        container_path = "/ssl"
        host_path      = "${var.workdir}/ssl"
        read_only      = true
    }

    ports {
        internal = 80
        external = 8080
    }

    networks = [ "${docker_network.test.name}" ]
}
