# Setup Proxy/dns for craystack vm- ubuntu 20.04 
Copy the below script and Run it with << bash scriptname >>
```

#!/bin/bash
tee /etc/environment<<EOF
https_proxy=http://hpeproxy.its.hpecorp.net:443
http_proxy=http://hpeproxy.its.hpecorp.net:80
HTTPS_PROXY=http://hpeproxy.its.hpecorp.net:443
HTTP_PROXY=http://hpeproxy.its.hpecorp.net:80
NO_PROXY="localhost,127.0.0.1,us.cray.com,americas.cray.com,dev.cray.com,hpc.amslabs.hpecorp.net,eag.rdlabs.hpecorp.net,github.hpe.com,jira-pro.its.hpecorp.net"
EOF

tee /etc/apt/apt.conf.d/proxy.conf<<EOF
Acquire::http::Proxy "http://hpeproxy.its.hpecorp.net:80";
Acquire::https::Proxy "http://hpeproxy.its.hpecorp.net:443";
EOF


mkdir -p /etc/systemd/system/docker.service.d/
tee /etc/systemd/system/docker.service.d/http-proxy.conf<<EOF
[Service]
Environment="HTTP_PROXY=http://hpeproxy.its.hpecorp.net:80"
Environment="HTTPS_PROXY=http://hpeproxy.its.hpecorp.net:443"
Environment="NO_PROXY=localhost,127.0.0.1,us.cray.com,americas.cray.com,dev.cray.com,hpc.amslabs.hpecorp.net,eag.rdlabs.hpecorp.net,github.hpe.com,jira-pro.its.hpecorp.net"
EOF

mkdir ~/.docker/
tee ~/.docker/config.json<<EOF
{
"proxies":
{
   "default":
   {
     "httpProxy": "http://hpeproxy.its.hpecorp.net:80/",
     "httpsProxy": "http://hpeproxy.its.hpecorp.net:443/",
     "noProxy": "localhost,127.0.0.1,.us.cray.com,.americas.cray.com,.dev.cray.com,.eag.rdlabs.hpecorp.net,github.hpe.com,jira-pro.its.hpecorp.net"
   }
}
}
EOF


systemctl daemon-reload 

tee /etc/systemd/resolved.conf<<EOF
[Resolve]
DNS=16.110.135.51 16.110.135.52
EOF


sudo apt update && sudo apt -y full-upgrade
[ -f /var/run/reboot-required ] && sudo reboot -f

```


