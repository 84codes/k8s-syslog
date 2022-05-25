# k8s-syslog

Forwards logs from kubernetes to a (udp or tcp+tls) syslog server.

It uses the [Kubernetes pod log API](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.19/#read-log-pod-v1-core) to stream the logs from each container in each pod. A [ServiceAccount with pod read access](https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/) is required, but can also use `kubectl proxy` eg. for local development. See [deployment.yml](deployment.yml) for an example.

An environment variable named `SYSLOG_ADDRESS` is required, with the format `tcp+tls://logs.papertrailapp.com:12345` or `udp://localhost:514` or `file:///dev/stdout`.
