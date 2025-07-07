# Install Ceph on Kubernetes

**Wichtig:** Vor der installation muss das secret in der values.yml noch aus bitwarden übernommen werden.

```bash
helm repo add ceph-csi https://ceph.github.io/csi-charts
helm upgrade --install --create-namespace --namespace "ceph-csi-rbd" "ceph-csi-rbd" ceph-csi/ceph-csi-rbd -f values.yml
```
