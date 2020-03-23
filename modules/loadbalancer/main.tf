resource "google_compute_instance_group" "backend" {
  for_each  = var.architecture == "standard" ? [] : toset(var.zones)
  name      = "pe-compiler-${var.id}"
  instances = [for i in var.instances : i.self_link if i.zone == each.value]
  zone      = each.value
}

resource "google_compute_health_check" "pe_compiler" {
  count = var.architecture == "standard" ? 0 : 1 
  name  = "pe-compiler-${var.id}"

  tcp_health_check { port = var.ports[0] }
}

resource "google_compute_region_backend_service" "pe_compiler_lb" {
  count         = var.architecture == "standard" ? 0 : 1 
  name          = "pe-compiler-lb-${var.id}"
  health_checks = [google_compute_health_check.pe_compiler[0].self_link]
  region        = var.region

  dynamic "backend" {
    for_each = toset(var.zones)

    content { group = google_compute_instance_group.backend[backend.value].self_link }
  }
}

resource "google_compute_forwarding_rule" "pe_compiler_lb" {
  count                 = var.architecture == "standard" ? 0 : 1 
  name                  = "pe-compiler-lb-${var.id}"
  service_label         = "puppet"
  load_balancing_scheme = "INTERNAL"
  ports                 = var.ports
  network               = var.network
  subnetwork            = var.subnetwork
  backend_service       = google_compute_region_backend_service.pe_compiler_lb[0].self_link
}