terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.129.0"
    }
  }

  required_version = ">=1.8.4"
}

provider "yandex" {
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  service_account_key_file = "key.json"
}

# Создание сети
resource "yandex_vpc_network" "network" {
  name = "balancer-network"
}

# Создание подсети
resource "yandex_vpc_subnet" "subnet" {
  name           = "balancer-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

# Создание двух идентичных виртуальных машин
resource "yandex_compute_instance" "web-server" {
  count = 2

  name        = "web-server-${count.index + 1}"
  platform_id = "standard-v1"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 5
  }

  boot_disk {
    initialize_params {
      image_id = "fd80bm0rh4rkepi5ksdi"
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    user-data = <<-EOF
      #cloud-config
      package_update: true
      packages:
        - nginx
      runcmd:
        - systemctl enable nginx
        - systemctl start nginx
        - echo "<h1>Server: $(hostname)</h1>" > /var/www/html/index.nginx-debian.html
        - systemctl restart nginx
    EOF
  }

  scheduling_policy {
    preemptible = true
  }
}

# Создание целевой группы для балансировщика
resource "yandex_lb_target_group" "target-group" {
  name = "web-target-group"

  dynamic "target" {
    for_each = yandex_compute_instance.web-server
    content {
      subnet_id = yandex_vpc_subnet.subnet.id
      address   = target.value.network_interface[0].ip_address
    }
  }
}

# Создание сетевого балансировщика нагрузки
resource "yandex_lb_network_load_balancer" "load-balancer" {
  name = "web-load-balancer"

  listener {
    name        = "web-listener"
    port        = 80
    target_port = 80

    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.target-group.id

    healthcheck {
      name = "http-healthcheck"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}

# Вывод внешнего IP балансировщика
output "load_balancer_public_ip" {
  value = one(one(yandex_lb_network_load_balancer.load-balancer.listener).external_address_spec).address
}

# Вывод IP виртуальных машин
output "instance_ips" {
  value = {
    for instance in yandex_compute_instance.web-server :
    instance.name => instance.network_interface[0].nat_ip_address
  }
}