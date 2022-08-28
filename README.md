# pwrstat_prometheus
Prometheus adapter for CyberPower UPS PowerPanel utility for Linux

Typically run on a Linux machine like such:  

```
(pwrstat -version; pwrstat -status) | gawk -f pwrstat-prometheus.awk
```

This spits out Prometheus metrics & help text.  My intention is to wrap something around this to perform it on-demand when Prometheus scrapes the adapter.

There is now a Golang HTTP server that executes the right commands to run pwrstat and spit out Prometheus metrics.  It's built into a Docker image and a Helm chart deploys into k8s.

I cannot publish the Docker image in the public because it requires a binary copy of the PowerPanel software from CyberPower, which it pulls during the docker build process.  The EULA prohibits publishing the binary.

It's a good idea to label your nodes so specific nodes that have a CyberPower UPS, and the PowerPanel software (pwrstatd) running, are the only ones where this software will run.  
E.g.: `kubectl label node server1 pwrstat="true"`

Then install the helm chart with a nodeSelector:

```
cat <<EOF > ups-values.yaml
image:
  repository: myLocalRegistry/pwrstat_prom_server
  tag: "0.2"
nodeSelector:
  pwrstat: "true"
EOF

helm -n monitoring-system upgrade -i ups helm/pwrstat-prom -f ups-values.yaml
```

The helm chart deploys this as a DaemonSet so it has a chance to run on every node in your cluster, in case 1 or more of them happen to have their own CyberPower UPS providing their power.

Only 1 CyberPower UPS per server is supported at the moment; I have not tried this with a 2nd unit attached to the same server, I might try this sometime.
