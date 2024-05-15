#!/bin/bash
# Copyright (c) 2024 IBM Corporation

# This is temp hack to try out Chengyu's nydus snapshotter fix in https://github.com/containerd/nydus-snapshotter/pull/593
# before the CoCo operator has been updated to consume it.

nydus_snapshotter_install_dir="/tmp/nydus-snapshotter"
nydus_snapshotter_url=https://github.com/containerd/nydus-snapshotter.git
nydus_snapshotter_version="v0.13.13"
git clone -b "${nydus_snapshotter_version}" "${nydus_snapshotter_url}" "${nydus_snapshotter_install_dir}"
pushd "$nydus_snapshotter_install_dir" || exit

# Use sed rather than yq as we don't know which version might be installed
sudo sed -i -e 's/^\(\s*FS_DRIVER: \).*$/\1\"proxy\"/g' "misc/snapshotter/base/nydus-snapshotter.yaml"
sudo sed -i -e 's/^\(\s*ENABLE_CONFIG_FROM_VOLUME: \).*$/\1\"false\"/g' "misc/snapshotter/base/nydus-snapshotter.yaml"
sudo sed -i -e 's/^\(\s*ENABLE_SYSTEMD_SERVICE: \).*$/\1\"true\"/g' "misc/snapshotter/base/nydus-snapshotter.yaml"
sudo sed -i -e 's/^\(\s*ENABLE_RUNTIME_SPECIFIC_SNAPSHOTTER: \).*$/\1\"true\"/g' "misc/snapshotter/base/nydus-snapshotter.yaml"

sudo sed -i -e 's%^\(\s*image: \)\("ghcr.io\/containerd/nydus-snapshotter:latest"\)%\1\"ghcr.io/containerd/nydus-snapshotter:v0.13.13\"%g' "misc/snapshotter/base/nydus-snapshotter.yaml"

kubectl create -f "misc/snapshotter/nydus-snapshotter-rbac.yaml"
kubectl apply -f "misc/snapshotter/base/nydus-snapshotter.yaml"

kubectl rollout status DaemonSet nydus-snapshotter -n nydus-system --timeout 5m

pods_name=$(kubectl get pods --selector=app=nydus-snapshotter -n nydus-system -o=jsonpath='{.items[*].metadata.name}')
kubectl logs "${pods_name}" -n nydus-system
