#!/bin/bash

set -e

# This is a simplified "end to end" test script that installs all Plone helm charts
# in a local K8S cluster. Please make sure this script runs without errors before
# doing merging changes (this validation may be done automatically using the Github
# Actions).
#
# Using helm to install Plone assumes you have a running K8S cluster and a properly
# configures kubectl client. If you want to install a simplificed K8S cluster for
# development purposes, we suggest the usage of K3D (a thin wrapper around K3S project).
# Instalation instructions are available on https://k3d.io
# On Linux systems, you can use the following command:
# curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

for cmd in kubectl helm; {
    if ! command -v $cmd &> /dev/null
    then
        echo "$cmd not found"
        exit 1
    fi
}

# OPTIONAL: as part of the 'end to end' testing, you can install the
# *k8s-diagrams* tool in your $PATH to enable the automatic generation
# of svg images showing all the different components installed and
# the relationship between them.
# https://github.com/trois-six/k8s-diagrams/releases/tag/v0.0.6

generate_k8s_images="${K8S_IMAGES:-false}"
if ! command -v k8s-diagrams -h &> /dev/null
then
    generate_k8s_images=false
fi

# Also, to convert the dot files generated by k8s-diagrams into png/svg
# images, it is required to install the graphviz package.
if ! command -v dot -V &> /dev/null
then
    generate_k8s_images=false
fi

function finish {
  kubectl delete namespace plone-helm
}
trap finish EXIT

kubectl create namespace plone-helm

for helm_name in $(cat all-charts.txt | xargs); {
    echo Testing $helm_name

    helm dependency update ./$helm_name
    helm dependency list ./$helm_name

    helm lint ./$helm_name

    helm install -n plone-helm myplone ./$helm_name

    sleep 5

    if [ "$generate_k8s_images" = true ]; then
        dotdir="$(pwd)/$helm_name/diagrams"
        svgdir="$(pwd)/img/$helm_name"

        # wait more time, k8s deployment time may vary
        sleep 300

        rm -rf $dotdir
        k8s-diagrams --namespace plone-helm \
                     --outputDirectory $dotdir \
                     --label "helm $helm_name"
        mkdir -p $svgdir
        cd $dotdir
        dot -Tsvg k8s.dot > k8s.png
        dot -Tsvg k8s.dot > k8s.svg
        cp -prf k8s.png k8s.svg assets $svgdir
        cd -
    fi

    helm uninstall -n plone-helm myplone
}
