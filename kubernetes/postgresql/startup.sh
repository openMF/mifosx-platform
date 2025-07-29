#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements. See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership. The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the
# specific language governing permissions and limitations
# under the License.
#

echo "Setting Up Mifos X Service configuration..."
microk8s kubectl create secret generic fineract-tenants-db-secret --from-literal=username=root --from-literal=password=$(head /dev/urandom | LC_CTYPE=C tr -dc A-Za-z0-9 | head -c 16)
microk8s kubectl apply -f fineractpostgresql-configmap.yml

echo "Setting Up Mifos X Ingress configuration..."
microk8s kubectl apply -f webapp-ingress.yml
microk8s kubectl apply -f fineract-ingress.yml

echo
echo "Starting Postgresql Database..."
microk8s kubectl apply -f fineractpostgresql-deployment.yml

fineractpostgresql_pod=""
while [[ ${#fineractpostgresql_pod} -eq 0 ]]; do
    fineractpostgresql_pod=$(microk8s kubectl get pods -l tier=fineractpostgresql --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
done

fineractpostgresql_status=$(microk8s kubectl get pods ${fineractpostgresql_pod} --no-headers -o custom-columns=":status.phase")
while [[ ${fineractpostgresql_status} -ne 'Running' ]]; do
    sleep 1
    fineractpostgresql_status=$(microk8s kubectl get pods ${fineractpostgresql_pod} --no-headers -o custom-columns=":status.phase")
done

echo
echo "Starting Apache Fineract server..."
microk8s kubectl apply -f fineract-server-deployment.yml

fineract_server_pod=""
while [[ ${#fineract_server_pod} -eq 0 ]]; do
    fineract_server_pod=$(microk8s kubectl get pods -l tier=backend --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
done

fineract_server_status=$(microk8s kubectl get pods ${fineract_server_pod} --no-headers -o custom-columns=":status.phase")
while [[ ${fineract_server_status} -ne 'Running' ]]; do
    sleep 1
    fineract_server_status=$(microk8s kubectl get pods ${fineract_server_pod} --no-headers -o custom-columns=":status.phase")
done

echo "Apache Fineract server is up and running"

echo "Starting Mifos Web App (Admin UI)..."
microk8s kubectl apply -f fineract-mifoscommunity-deployment.yml

fineract_mifoscommunity_pod=""
while [[ ${#fineract_mifoscommunity_pod} -eq 0 ]]; do
    fineract_mifoscommunity_pod=$(microk8s kubectl get pods -l tier=backend --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
done

fineract_mifoscommunity_status=$(microk8s kubectl get pods ${fineract_mifoscommunity_pod} --no-headers -o custom-columns=":status.phase")
while [[ ${fineract_mifoscommunity_status} -ne 'Running' ]]; do
    sleep 1
    fineract_mifoscommunity_status=$(microk8s kubectl get pods ${fineract_mifoscommunity_pod} --no-headers -o custom-columns=":status.phase")
done
echo "Mifos Web App (Admin UI) is up and running"