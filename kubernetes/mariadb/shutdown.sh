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

microk8s kubectl delete secret fineract-tenants-db-secret
microk8s kubectl delete -f mifos-webapp-ingress.yml
microk8s kubectl delete -f fineract-ingress.yml
microk8s kubectl delete -f fineractmysql-configmap.yml
microk8s kubectl delete -f fineractmysql-deployment.yml
microk8s kubectl delete -f fineract-server-deployment.yml
microk8s kubectl delete -f mifos-webapp-deployment.yml