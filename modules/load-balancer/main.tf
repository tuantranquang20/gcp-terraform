# ============================================
# Network Endpoint Groups (NEGs) for Cloud Run
# ============================================

# NEG for Frontend Cloud Run Service
resource "google_compute_region_network_endpoint_group" "frontend_neg" {
  name                  = "${var.prefix}-${var.environment}-frontend-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  project               = var.project_id

  cloud_run {
    service = var.frontend_service_name
  }
}

# NEG for Backend Cloud Run Service
resource "google_compute_region_network_endpoint_group" "backend_neg" {
  name                  = "${var.prefix}-${var.environment}-backend-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  project               = var.project_id

  cloud_run {
    service = var.backend_service_name
  }
}

# ============================================
# Backend Services
# ============================================

# Backend Service for Frontend
resource "google_compute_backend_service" "frontend" {
  name             = "${var.prefix}-${var.environment}-frontend-backend"
  project          = var.project_id
  protocol         = "HTTP"
  port_name        = "http"
  timeout_sec      = 30
  enable_cdn       = var.enable_cdn
  compression_mode = var.enable_cdn ? "AUTOMATIC" : "DISABLED"

  backend {
    group = google_compute_region_network_endpoint_group.frontend_neg.id
  }

  log_config {
    enable      = true
    sample_rate = var.log_sample_rate
  }

  # Identity-Aware Proxy (optional)
  dynamic "iap" {
    for_each = var.iap_client_id != "" ? [1] : []
    content {
      enabled              = true
      oauth2_client_id     = var.iap_client_id
      oauth2_client_secret = var.iap_client_secret
    }
  }

  # Cloud CDN configuration
  dynamic "cdn_policy" {
    for_each = var.enable_cdn ? [1] : []
    content {
      cache_mode        = "CACHE_ALL_STATIC"
      default_ttl       = 3600
      max_ttl           = 86400
      client_ttl        = 3600
      negative_caching  = true
      serve_while_stale = 86400
    }
  }

  custom_request_headers = [
    "X-Client-Region: {client_region}",
    "X-Client-City: {client_city}",
  ]
}

# Backend Service for Backend API
resource "google_compute_backend_service" "backend" {
  name        = "${var.prefix}-${var.environment}-backend-backend"
  project     = var.project_id
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30
  enable_cdn  = false # API shouldn't be cached

  backend {
    group = google_compute_region_network_endpoint_group.backend_neg.id
  }

  log_config {
    enable      = true
    sample_rate = var.log_sample_rate
  }

  custom_request_headers = [
    "X-Client-Region: {client_region}",
  ]
}

# ============================================
# URL Map (Routing Rules)
# ============================================

resource "google_compute_url_map" "default" {
  name            = "${var.prefix}-${var.environment}-urlmap"
  project         = var.project_id
  default_service = google_compute_backend_service.frontend.id

  host_rule {
    hosts        = [var.domain_name]
    path_matcher = "main"
  }

  path_matcher {
    name            = "main"
    default_service = google_compute_backend_service.frontend.id

    # Route /api/* to backend service
    path_rule {
      paths   = ["/api/*", "/api"]
      service = google_compute_backend_service.backend.id
    }

    # Route /health to backend service
    path_rule {
      paths   = ["/health"]
      service = google_compute_backend_service.backend.id
    }

    # All other paths go to frontend
    path_rule {
      paths   = ["/*"]
      service = google_compute_backend_service.frontend.id
    }
  }
}

# ============================================
# SSL Certificate
# ============================================

# Google-managed SSL certificate
resource "google_compute_managed_ssl_certificate" "default" {
  count   = var.enable_ssl ? 1 : 0
  name    = "${var.prefix}-${var.environment}-ssl-cert"
  project = var.project_id

  managed {
    domains = [var.domain_name]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================
# HTTPS Proxy, HTTP to HTTPS redirect
# ============================================

# Người dùng (HTTPS)
#         ↓
#   [Forwarding Rule]       ← "cổng vào", lắng nghe port 443
#         ↓
# [Target HTTPS Proxy]      ← giải mã TLS, kiểm tra SSL cert
#         ↓
#     [URL Map]             ← /api/* → backend A, /* → backend B
#         ↓
#  [Backend Service]        ← máy chủ thực sự xử lý request



# HTTPS Target Proxy -  giải mã TLS, kiểm tra SSL cert
resource "google_compute_target_https_proxy" "default" {
  count            = var.enable_ssl ? 1 : 0
  name             = "${var.prefix}-${var.environment}-https-proxy"
  project          = var.project_id
  url_map          = google_compute_url_map.default.id
  ssl_certificates = [google_compute_managed_ssl_certificate.default[0].id]
}

# HTTP Target Proxy (for redirect)
resource "google_compute_target_http_proxy" "default" {
  name    = "${var.prefix}-${var.environment}-http-proxy"
  project = var.project_id
  url_map = var.enable_ssl ? google_compute_url_map.redirect[0].id : google_compute_url_map.default.id
}

# URL Map for HTTP to HTTPS redirect
resource "google_compute_url_map" "redirect" {
  count   = var.enable_ssl ? 1 : 0
  name    = "${var.prefix}-${var.environment}-https-redirect"
  project = var.project_id

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

# ============================================
# Global Forwarding Rules (Load Balancer IPs)
# ============================================

# Reserve a static IP address
resource "google_compute_global_address" "default" {
  name    = "${var.prefix}-${var.environment}-lb-ip"
  project = var.project_id
}

# HTTPS Forwarding Rule
resource "google_compute_global_forwarding_rule" "https" {
  count                 = var.enable_ssl ? 1 : 0
  name                  = "${var.prefix}-${var.environment}-https-rule"
  project               = var.project_id
  ip_address            = google_compute_global_address.default.address
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.default[0].id
}

# HTTP Forwarding Rule
resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.prefix}-${var.environment}-http-rule"
  project               = var.project_id
  ip_address            = google_compute_global_address.default.address
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.default.id
}

# ============================================
# Cloud Armor Security Policy (Optional)
# ============================================

resource "google_compute_security_policy" "policy" {
  count   = var.enable_cloud_armor ? 1 : 0
  name    = "${var.prefix}-${var.environment}-security-policy"
  project = var.project_id

  # Default rule - allow all
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule"
  }

  # Rate limiting rule
  rule {
    action   = "rate_based_ban"
    priority = "1000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action   = "allow"
      exceed_action    = "deny(429)"
      enforce_on_key   = "IP"
      ban_duration_sec = 600
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
    }
    description = "Rate limit: 100 requests per minute"
  }

  # Block specific countries (example)
  dynamic "rule" {
    for_each = length(var.blocked_countries) > 0 ? [1] : []
    content {
      action   = "deny(403)"
      priority = "2000"
      match {
        expr {
          expression = "origin.region_code in [${join(",", formatlist("'%s'", var.blocked_countries))}]"
        }
      }
      description = "Block traffic from specific countries"
    }
  }

  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable = var.enable_ddos_protection
    }
  }
}

# Attach security policy to backend services
resource "google_compute_backend_service_security_policy" "frontend" {
  count           = var.enable_cloud_armor ? 1 : 0
  backend_service = google_compute_backend_service.frontend.name
  security_policy = google_compute_security_policy.policy[0].name
}

resource "google_compute_backend_service_security_policy" "backend" {
  count           = var.enable_cloud_armor ? 1 : 0
  backend_service = google_compute_backend_service.backend.name
  security_policy = google_compute_security_policy.policy[0].name
}
