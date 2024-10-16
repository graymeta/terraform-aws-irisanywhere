#cloud-config
hostname: ${hostname}
package_upgrade: false
runcmd:
- wget -P /tmp/ "https://gm-iris.s3.us-west-1.amazonaws.com/haproxy/init-ha.sh" ; chmod 550 /tmp/init-ha.sh ; sh /tmp/init-ha.sh >> /var/log/user-data.log 2>&1
- ( echo export "ASGID='${asg_name}'" >> /etc/profile.d/gmvars.sh ; echo export "AWSREGION='${aws_region}'" >> /etc/profile.d/gmvars.sh ; echo export "HAPROXY_LOGLEVEL='${hap_loglevel}'" >> /etc/profile.d/gmvars.sh; ) >> /var/log/user-data.log 2>&1
- sed -i 's/443 ssl check/${port} check /' /etc/haproxy/haproxy.cfg ; sed -i 's/local0 warning/local0 ${hap_loglevel}/' /etc/haproxy/haproxy.cfg >> /var/log/user-data.log 2>&1
- sed -i 's/sock/sock" "HAPPW=${statspw}/' /lib/systemd/system/haproxy.service >> /var/log/user-data.log 2>&1
- aws secretsmanager get-secret-value --secret-id ${ssl_certificate_cert} --query SecretString --output text --region ${aws_region} > cert.pem ; mv cert.pem /etc/ssl/certs/ ; chmod 440 /etc/ssl/certs/cert.pem >> /var/log/user-data.log 2>&1
- |
  echo '${haproxy_user_init}' | base64 -d > /tmp/haproxy_user_init.sh && chmod +x /tmp/haproxy_user_init.sh && /tmp/haproxy_user_init.sh >> /var/log/user-data.log 2>&1
- reboot >> /var/log/user-data.log 2>&1