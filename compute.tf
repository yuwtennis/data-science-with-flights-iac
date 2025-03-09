// Auth proxy for running migration from local
data "template_file" "cloud_sql_auth_proxy_cloud_init" {
  template = file("${path.module}/scripts/cloud_sql_auth_proxy.tpl")
  vars = {
    container_name                 = "cloud-sql-auth-proxy"
    cloud_sql_auth_proxy_image_tag = local.cloud_sql_auth_proxy_docker_image_tag
    cloud_sql_dns_name             = google_sql_database_instance.flights.dns_name
  }
}

// Replace the instance whenever metadata user-data changes
resource "terraform_data" "cloud_sql_auth_proxy_cloud_init_state" {
  input = data.template_file.cloud_sql_auth_proxy_cloud_init.rendered
}

resource "google_compute_instance" "cloud_sql_auth_proxy" {
  name         = "cloud-sql-auth-proxy"
  machine_type = "e2-micro"
  zone         = "${local.region}-a"
  tags = [
    tolist(google_compute_firewall.ingress_postgresql_rule.target_tags)[0],
    tolist(google_compute_firewall.egress_tcp_any_rule.target_tags)[0],
    tolist(google_compute_firewall.ingress_deny_all_rule.target_tags)[0],
    tolist(google_compute_firewall.ingress_iap_ssh_forwarding_rule.target_tags)[0]
  ]

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-117-lts"
    }
  }

  network_interface {
    network    = google_compute_network.vpc.self_link
    subnetwork = google_compute_subnetwork.private_subnet.self_link
  }

  metadata = {
    cloud-sql-dns-name             = google_sql_database_instance.flights.dns_name
    cloud-sql-auth-proxy-image-tag = local.cloud_sql_auth_proxy_docker_image_tag
    google-logging-enabled         = true
    user-data                      = terraform_data.cloud_sql_auth_proxy_cloud_init_state.output
  }

  service_account {
    scopes = ["cloud-platform"]
    email  = google_service_account.cloud_sql_auth_proxy.email
  }

  allow_stopping_for_update = true

  lifecycle {
    replace_triggered_by = [
      terraform_data.cloud_sql_auth_proxy_cloud_init_state
    ]
  }

  // Explicit dependency just in case
  depends_on = [
    google_compute_router_nat.public_nat,
    google_compute_forwarding_rule.psc_cloud_sql
  ]
}