# pwrstat_prometheus
Prometheus adapter for CyberPower UPS [PowerPanel utility for Linux](https://www.cyberpowersystems.com/product/software/power-panel-personal/powerpanel-for-linux/)

This project depends on PowerPanel's pwrstatd running on the Linux server (launched via systemd or similar) and a working
connection to the UPS (typically via USB cable).  The `pwrstat -status` command should work correctly on the server.

Typically run on a Linux machine like such:  

```
(pwrstat -version; pwrstat -status) | gawk -f pwrstat-prometheus.awk
```

This spits out Prometheus metrics & help text.  My intention is to wrap something around this to perform it on-demand when Prometheus scrapes the adapter.

There is now a Golang HTTP server that executes the right commands to run pwrstat and spit out Prometheus metrics.  It's built into a Docker image and a Helm chart deploys into k8s.

I cannot publish the Docker image in the public because it requires a binary copy of the PowerPanel software from CyberPower, which it pulls during the docker build process.  The EULA prohibits publishing the binary.

I typically build it like such:  
```
docker build -t myLocalRegistry/pwrstat_prom_server:0.1 -f container/Dockerfile .
docker push myLocalRegistry/pwrstat_prom_server:0.1
```

Be sure to configure the image.repository and image.tag in the Helm chart to reference the correct Docker registry location of your image.  Hosting a Docker registry is outside the scope of this document.

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

Under the hood, the Helm chart creates a [PodMonitor](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md#monitoring.coreos.com/v1.PodMonitor)
object which informs a kube-prometheus-stack install to scrape Prometheus metrics from the pod's port 9190 /metrics URI
every 1 minute (configurable via prometheus.interval, which is a string of the format specified
[here](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md#monitoring.coreos.com/v1.Duration) )

No Service is created for this pod so it's not discoverable by cluster workloads.

The Pod running the HTTP server, which depends on the `pwrstat` utility, needs to have a UNIX domain socket to the underlying
server's `pwrstatd` process in `/var/pwrstatd.ipc` which we mount using a hostPath inside the pod.  The path to the local
server's directory containing pwrstatd's UNIX domain socket is configured in the pwrstat.pwrstatdIpcPath variable (it is
*/var* by default).  The filename is expected to be *pwrstatd.ipc* inside that directory.
