#cloud-config
hostname: ${hostname}
package_upgrade: false
%{ if otlp_enabled }
write_files:
  - path: /etc/systemd/system/otelcol-contrib.service
    permissions: '0644'
    content: |
      [Unit]
      Description=OpenTelemetry Collector Contrib
      After=network-online.target
      Wants=network-online.target

      [Service]
      Type=simple
      ExecStart=/usr/local/bin/otelcol-contrib --config /etc/otel/config.yaml
      Restart=always
      RestartSec=5

      [Install]
      WantedBy=multi-user.target
%{ endif }
runcmd:
%{ if otlp_enabled }
  - wget -P /tmp/ "https://gm-iris.s3.us-west-1.amazonaws.com/haproxy/otel-config.yaml"; sudo mkdir -p /etc/otel; chmod +r /tmp/otel-config.yaml; sudo mv /tmp/otel-config.yaml /etc/otel/config.yaml
  - sudo sed -i '/otlp\/customer:/,/^[^[:space:]]/ s|^\(\s*endpoint:\s*\).*|\1${otlp_exporter_destination}:4317|' /etc/otel/config.yaml
  - wget -P /tmp/ "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.146.1/otelcol-contrib_0.146.1_linux_amd64.tar.gz"; sudo tar -xvf /tmp/otelcol-contrib_0.146.1_linux_amd64.tar.gz; sudo mv otelcol-contrib /usr/local/bin/otelcol-contrib; sudo chmod +x /usr/local/bin/otelcol-contrib
  - systemctl daemon-reload
  - systemctl enable --now otelcol-contrib
%{ endif }
  - wget -P /tmp/ "https://gm-iris.s3.us-west-1.amazonaws.com/haproxy/init-ha2.sh"; chmod 550 /tmp/init-ha2.sh; sh /tmp/init-ha2.sh >> /var/log/user-data.log 2>&1
  - echo export "ASGID='${asg_name}'" >> /etc/profile.d/gmvars.sh ; echo export "AWSREGION='${aws_region}'" >> /etc/profile.d/gmvars.sh ; echo export "HAPROXY_LOGLEVEL='${hap_loglevel}'" >> /etc/profile.d/gmvars.sh;
  - sed -i 's/443 ssl check/${port} check/' /etc/haproxy/haproxy.cfg ; sed -i 's/local0 warning/local0 ${hap_loglevel}/' /etc/haproxy/haproxy.cfg >> /var/log/user-data.log 2>&1
  - mkdir -p /etc/systemd/system/haproxy.service.d ; echo '[Service]' > /etc/systemd/system/haproxy.service.d/env.conf ; echo 'Environment="CONFIG=/etc/haproxy/haproxy.cfg" "PIDFILE=/run/haproxy.pid"' >> /etc/systemd/system/haproxy.service.d/env.conf ; echo 'Environment="HAPPW=${statspw}"' >> /etc/systemd/system/haproxy.service.d/env.conf
  - aws secretsmanager get-secret-value --secret-id ${ssl_certificate_cert} --query SecretString --output text --region ${aws_region} > cert.pem ; mv cert.pem /etc/ssl/certs/ ; chmod 440 /etc/ssl/certs/cert.pem >> /var/log/user-data.log 2>&1
  - |
    echo '${haproxy_user_init}' | base64 -d > /tmp/haproxy_user_init.sh && chmod +x /tmp/haproxy_user_init.sh && /tmp/haproxy_user_init.sh >> /var/log/user-data.log 2>&1
  - reboot >> /var/log/user-data.log 2>&1

