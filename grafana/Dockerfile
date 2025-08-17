FROM grafana/grafana
ENV GF_SMTP_ENABLED=true
ENV GF_SMTP_HOST=smtp.moslof.com:25
ENV GF_SMTP_FROM_ADDRESS=alertmanager@moslof.com
ENV GF_SMTP_FROM_NAME="Grafana Alerts"
CMD ["grafana-server"] 
