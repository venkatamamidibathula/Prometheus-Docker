# 🔒 Enterprise Prometheus Monitoring Stack with NGINX Gateway

[![Docker](https://img.shields.io/badge/Docker-20.10%2B-blue)](https://www.docker.com/)
[![Prometheus](https://img.shields.io/badge/Prometheus-2.40%2B-orange)](https://prometheus.io/)
[![Grafana](https://img.shields.io/badge/Grafana-9.0%2B-orange)](https://grafana.com/)
[![NGINX](https://img.shields.io/badge/NGINX-1.20%2B-green)](https://nginx.org/)

Enterprise-grade monitoring solution where **all traffic flows securely through NGINX** with SSL termination and static file discovery.

## 🏗️ Component Architecture

```
                    ┌─────────────────────────────────┐
                    │         NGINX Gateway           │
                    │    (SSL/TLS Termination)       │
                    │      Port 443 (HTTPS)         │
                    └─────────────┬───────────────────┘
                                  │
                    ┌─────────────▼───────────────────┐
                    │      Internal Docker Network    │
                    │     (All HTTP Internally)      │
                    └─────────────┬───────────────────┘
                                  │
        ┌─────────────────────────┼─────────────────────────┐
        │                         │                         │
        ▼                         ▼                         ▼
┌──────────────┐          ┌──────────────┐          ┌──────────────┐
│  Prometheus  │◄────────►│   Grafana    │          │ Alertmanager │
│   :9090      │          │    :3000     │          │    :9093     │
└──────┬───────┘          └──────────────┘          └──────┬───────┘
       │                                                   │
       ▼                                                   ▼
┌──────────────┐                                    ┌──────────────┐
│   Blackbox   │                                    │  MS Teams    │
│   Exporter   │                                    │   Webhook    │
│    :9115     │                                    └──────────────┘
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Target Files │
│(Static File  │
│ Discovery)   │
└──────────────┘
```

## 🔄 Component Communication Flow

### **NGINX Gateway (Entry Point)**
- **External**: HTTPS/443 → SSL termination → Internal routing
- **Routes**: `/prometheus` → Prometheus:9090, `/grafana` → Grafana:3000, `/alertmanager` → Alertmanager:9093
- **Security**: All services hidden behind NGINX, only 443 exposed

### **Prometheus (Core Monitoring)**
- **Scrapes**: Targets via static file discovery + Blackbox exporter
- **Communicates**: 
  - → Blackbox Exporter (HTTP probes)
  - → Alertmanager (Alert forwarding)
  - ← Grafana (Data queries)

### **Grafana (Visualization)**
- **Data Source**: Prometheus via internal HTTP
- **Access**: Via NGINX `/grafana` path
- **Dashboards**: Auto-provisioned for monitoring stack

### **Alertmanager (Alert Management)**
- **Receives**: Alerts from Prometheus
- **Sends**: Notifications to MS Teams via webhook
- **Routes**: Based on environment labels (Dev/Test/Stage/Prod)

### **Blackbox Exporter (External Monitoring)**
- **Probes**: HTTP/HTTPS/DNS/TCP endpoints
- **Metrics**: Exported to Prometheus
- **Targets**: Defined in static discovery files

### **MS Teams Integration**
- **Receives**: Webhook from Alertmanager
- **Converts**: Prometheus alerts → Teams messages
- **Environment-aware**: Different channels per environment

## 🚀 Quick Setup

### 1. Clone Repository
```bash
git clone https://github.com/venkatamamidibathula/Prometheus-Docker.git
cd Prometheus-Docker
```

### 2. SSL Certificate Setup
Place your organization's SSL certificates in `nginx/ssl/`:
```bash
mkdir -p nginx/ssl
# Copy your organization's certificates:
cp /path/to/your/certificate.crt nginx/ssl/cert.pem
cp /path/to/your/private.key nginx/ssl/key.pem
cp /path/to/your/ca-bundle.crt nginx/ssl/ca-bundle.pem  # Optional
```

### 3. Configure Environment
```bash
cp .env.example .env
# Edit .env with your domain and settings
nano .env
```

### 4. Launch Stack
```bash
docker-compose up -d
```

### 5. Access Services
- **Prometheus**: https://your-domain.com/prometheus
- **Grafana**: https://your-domain.com/grafana
- **Alertmanager**: https://your-domain.com/alertmanager

## 📁 Key Configuration Files

```
prometheus/
├── prometheus.yml          # Main config
├── alert_rules.yaml       # Alert definitions
└── targets/              # Static file discovery
    ├── dev_targets.yaml   # Dev environment
    ├── test_targets.yaml  # Test environment  
    ├── stage_targets.yaml # Stage environment
    └── prod_targets.yaml  # Prod environment

nginx/
├── nginx.conf            # Main reverse proxy config
└── ssl/                  # Your organization's SSL certificates
    ├── cert.pem          # SSL certificate
    ├── key.pem           # Private key
    └── ca-bundle.pem     # CA bundle (optional)

alertmanager/
└── alertmanager.yml      # MS Teams routing

blackbox/
└── config.yml           # Probe configurations
```

## ➕ Adding New Applications

### Step 1: Add Target File
Create or update target file in `prometheus/targets/`:

```yaml
# prometheus/targets/new_app_prod.yaml
- targets:
    - 'https://new-app.company.com'
    - 'https://new-api.company.com:8443'
  labels:
    environment: 'Prod'          # Must be: Dev, Test, Stage, Prod
    team: 'backend'
    service: 'new-application'
    app: 'new-app'
```

### Step 2: Add System Metrics (Optional)
If the app has node exporter, add to `exporter_metrics.yaml`:

```yaml
- targets:
    - 'new-app-server:9100'
  labels:
    environment: 'Prod'
    job: 'node-exporter'
    service: 'new-application'
```

### Step 3: Update Blackbox Config (If needed)
For custom probes, update `blackbox/config.yml`:

```yaml
modules:
  new_app_probe:
    prober: http
    http:
      method: GET
      valid_status_codes: [200, 201]
      headers:
        Authorization: "Bearer token"
```

### Step 4: Add Custom Alerts (Optional)
Add specific alerts in `alert_rules.yaml`:

```yaml
- alert: NewAppDown
  expr: probe_success{service="new-application"} == 0
  for: 2m
  labels:
    severity: critical
    environment: "{{ $labels.environment }}"
  annotations:
    summary: "New Application is down"
```

### Step 5: Reload Configuration
```bash
# Prometheus auto-reloads target files
# Or force reload:
curl -X POST https://your-domain.com/prometheus/-/reload
```

## 🔧 Environment Management

### Target File Naming Convention
```bash
prometheus/targets/
├── {service}_dev.yaml      # Development
├── {service}_test.yaml     # Testing  
├── {service}_stage.yaml    # Staging
└── {service}_prod.yaml     # Production
```

### Required Labels
Every target **must** include:
```yaml
labels:
  environment: 'Prod'     # Always capitalize: Dev, Test, Stage, Prod
  service: 'service-name'
  team: 'team-name'
```

## 🚨 Alert Routing

Alerts automatically route based on `environment` label:
- **Dev** → `#dev-alerts` Teams channel
- **Test** → `#test-alerts` Teams channel  
- **Stage** → `#stage-alerts` Teams channel
- **Prod** → `#prod-alerts` Teams channel

## 🔍 Health Monitoring

```bash
# Check all services (requires your SSL certificates)
curl -f https://your-domain.com/prometheus/-/healthy
curl -f https://your-domain.com/grafana/api/health  
curl -f https://your-domain.com/alertmanager/-/healthy

# View NGINX routing
docker-compose logs nginx

# Monitor target discovery  
curl -s https://your-domain.com/prometheus/api/v1/targets | jq '.data.activeTargets[].labels'
```

## 📊 Built-in Dashboards

1. **Infrastructure Overview** - System metrics across environments
2. **Service Health Dashboard** - HTTP response times and status
3. **Alert Status Board** - Current alerts by environment  
4. **Blackbox Monitoring** - External endpoint monitoring

## 🔄 Scaling Applications

### Adding Multiple Instances
```yaml
# prometheus/targets/app_prod.yaml
- targets:
    - 'https://app-1.company.com'
    - 'https://app-2.company.com' 
    - 'https://app-3.company.com'
  labels:
    environment: 'Prod'
    service: 'web-app'
    cluster: 'primary'
```

### Load Balanced Services
```yaml
# Monitor load balancer + individual instances
- targets:
    - 'https://app-lb.company.com'      # Load balancer
  labels:
    environment: 'Prod'
    service: 'web-app'
    type: 'loadbalancer'

- targets:
    - 'https://app-1.internal.com'      # Backend instances
    - 'https://app-2.internal.com'
  labels:
    environment: 'Prod'
    service: 'web-app'  
    type: 'backend'
```

---

⚠️ **Important Notes:**
- Environment labels must be capitalized: `Dev`, `Test`, `Stage`, `Prod`
- New servers require entries in both target files AND `exporter_metrics.yaml`
- All external access goes through NGINX - never expose internal ports
- Prometheus automatically reloads target files every 30 seconds
- Use your organization's valid SSL certificates for production deployment

🔒 **Secure by Design**: All traffic encrypted, all services behind NGINX gateway

⭐ Star this repo if it helps your monitoring setup!