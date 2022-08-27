# pwrstat_prometheus
Prometheus adapter for CyberPower UPS PowerPanel utility for Linux

Typically run on a Linux machine like such:  

```
(pwrstat -version; pwrstat -status) | gawk -f pwrstat-prometheus.awk
```

This spits out Prometheus metrics & help text.  My intention is to wrap something around this to perform it on-demand when Prometheus scrapes the adapter.
