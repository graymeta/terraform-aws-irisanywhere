#cloud-config
hostname: ${hostname}
package_upgrade: false
runcmd:
- yum -y install curl wget socat awscliv2 jq
- curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
- unzip awscli-bundle.zip ; python3 ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
- aws secretsmanager get-secret-value --secret-id ${ssl_certificate_cert} --query SecretString --output text --region ${aws_region} > cert.pem ; mv cert.pem /etc/ssl/certs/ ; chmod 440 /etc/ssl/certs/cert.pem
- curl -O https://packages.zenetys.com/latest/redhat/7/RPMS/x86_64/haproxy26z-2.6.6-2.el7.zenetys.x86_64.rpm
- rpm -i haproxy26z-2.6.6-2.el7.zenetys.x86_64.rpm ; rm -f /etc/haproxy/haproxy.cfg ; echo >> "#end of Iris LB Config" /etc/haproxy/haproxy.cfg ; mkdir /var/lib/haproxy/dev
- wget -P /etc/haproxy/ "https://gm-iris.s3.us-west-1.amazonaws.com/haproxy/haproxy.cfg" ; echo "#init config" >> /etc/haproxy/haproxy.cfg
- wget -P /etc/haproxy/utils/ "https://gm-iris.s3.us-west-1.amazonaws.com/haproxy/asg-scale.sh" ; chmod 500 /etc/haproxy/utils/asg-scale.sh
- wget -P /etc/haproxy/utils/ "https://gm-iris.s3.us-west-1.amazonaws.com/haproxy/lb-bootstrap" ; chmod 550 /etc/haproxy/utils/lb-bootstrap
- wget -P /etc/haproxy/utils/ "https://gm-iris.s3.us-west-1.amazonaws.com/haproxy/add-node-lb.sh" ; chmod 500 /etc/haproxy/utils/add-node-lb.sh
- wget -P /etc/haproxy/utils/ "https://gm-iris.s3.us-west-1.amazonaws.com/haproxy/remove-node-lb.sh" ; chmod 500 /etc/haproxy/utils/remove-node-lb.sh
- wget -P /etc/haproxy/utils/ "https://gm-iris.s3.us-west-1.amazonaws.com/haproxy/get-asg-nodes.sh" ; chmod 500 /etc/haproxy/utils/get-asg-nodes.sh
- wget -P /etc/haproxy/utils/ "https://gm-iris.s3.us-west-1.amazonaws.com/haproxy/get-lb-benodes.sh" ; chmod 500 /etc/haproxy/utils/get-lb-benodes.sh
- mkdir /etc/haproxy/errors; wget -P /etc/haproxy/errors/ "https://gm-iris.s3.us-west-1.amazonaws.com/haproxy/503.http" ; chmod 550 /etc/haproxy/errors/503.http
- wget -P /etc/rsyslog.d/ "https://gm-iris.s3.us-west-1.amazonaws.com/haproxy/99-haproxy.conf" ; chmod 550 /etc/rsyslog.d/99-haproxy.conf
- systemctl enable haproxy.service ; systemctl start haproxy.service ; systemctl restart haproxy.service 
- touch /etc/profile.d/gmvars.sh ; chmod 550 /etc/profile.d/gmvars.sh
- echo export "ASGID='${asg_name}'" >> /etc/profile.d/gmvars.sh
- echo export "AWSREGION='${aws_region}'" >> /etc/profile.d/gmvars.sh
- echo export "HAPROXY_LOGLEVEL='${hap_loglevel}'" >> /etc/profile.d/gmvars.sh
- (crontab -l ; echo "* * * * * /etc/haproxy/utils/add-node-lb.sh") | crontab -
- (crontab -l ; echo "* * * * * /etc/haproxy/utils/remove-node-lb.sh") | crontab -
- sed -i 's/443 ssl check/${port} check /' /etc/haproxy/haproxy.cfg
- sed -i 's/local0 warning/local0 ${hap_loglevel}/' /etc/haproxy/haproxy.cfg
- sed -i 's/sock/sock" "HAPPW=${statspw}/' /lib/systemd/system/haproxy.service ; systemctl daemon-reload ; systemctl restart haproxy ; systemctl restart rsyslog
- reboot