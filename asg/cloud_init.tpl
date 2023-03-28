#cloud-config
hostname: ${hostname}
package_upgrade: false
runcmd:
- wget -P /tmp/ "https://gm-iris.s3.us-west-1.amazonaws.com/haproxy/init-ha.sh" ; chmod 550 /tmp/init-ha.sh ; sh /tmp/init-ha.sh
- echo export "ASGID='${asg_name}'" >> /etc/profile.d/gmvars.sh ; echo export "AWSREGION='${aws_region}'" >> /etc/profile.d/gmvars.sh ; echo export "HAPROXY_LOGLEVEL='${hap_loglevel}'" >> /etc/profile.d/gmvars.sh
- sed -i 's/443 ssl check/${port} check /' /etc/haproxy/haproxy.cfg ; sed -i 's/local0 warning/local0 ${hap_loglevel}/' /etc/haproxy/haproxy.cfg
- sed -i 's/sock/sock" "HAPPW=${statspw}/' /lib/systemd/system/haproxy.service 
- aws secretsmanager get-secret-value --secret-id ${ssl_certificate_cert} --query SecretString --output text --region ${aws_region} > cert.pem ; mv cert.pem /etc/ssl/certs/ ; chmod 440 /etc/ssl/certs/cert.pem
- reboot