#!/bin/bash
set -e

kind create cluster --name=issue-xp-missing-shebang --config=kind-config.yaml
kubectx kind-issue-xp-missing-shebang

kubectl create namespace crossplane-system
kubectl apply -f init/pv.yaml

helm install crossplane --namespace crossplane-system --create-namespace https://charts.crossplane.io/master/crossplane-1.14.0-rc.0.347.g9ce5007c.tgz

# setup local-storage and patch crossplane container
kubectl -n crossplane-system patch deployment/crossplane --type='json' -p='[{"op":"add","path":"/spec/template/spec/containers/1","value":{"image":"alpine","name":"dev","command":["sleep","infinity"],"volumeMounts":[{"mountPath":"/tmp/cache","name":"package-cache"}]}},{"op":"add","path":"/spec/template/metadata/labels/patched","value":"true"}]'
kubectl -n crossplane-system wait deploy crossplane --for condition=Available --timeout=60s
kubectl -n crossplane-system wait pods -l app=crossplane,patched=true --for condition=Ready --timeout=60s


up xpkg build --ignore="init/*.yaml,example/claim.yaml,kind-config.yaml" --output=test.xpkg
up xpkg xp-extract --from-xpkg test.xpkg -o ./test.gz
kubectl -n crossplane-system cp ./test.gz -c dev $(kubectl -n crossplane-system get pod -l app=crossplane,patched=true -o jsonpath="{.items[0].metadata.name}"):/tmp/cache
kubectl apply -f init/xpkg.yaml

sleep 60

helm list -aA
kubectl apply -f example/claim.yaml
