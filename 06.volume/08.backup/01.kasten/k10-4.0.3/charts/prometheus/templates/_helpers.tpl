{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "prometheus.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "prometheus.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create unified labels for prometheus components
*/}}
{{- define "prometheus.common.matchLabels" -}}
app: {{ template "prometheus.name" . }}
release: {{ .Release.Name }}
{{- end -}}

{{- define "prometheus.common.metaLabels" -}}
chart: {{ template "prometheus.chart" . }}
heritage: {{ .Release.Service }}
{{- end -}}

{{- define "prometheus.alertmanager.labels" -}}
{{ include "prometheus.alertmanager.matchLabels" . }}
{{ include "prometheus.common.metaLabels" . }}
{{- end -}}

{{- define "prometheus.alertmanager.matchLabels" -}}
component: {{ .Values.alertmanager.name | quote }}
{{ include "prometheus.common.matchLabels" . }}
{{- end -}}

{{- define "prometheus.nodeExporter.labels" -}}
{{ include "prometheus.nodeExporter.matchLabels" . }}
{{ include "prometheus.common.metaLabels" . }}
{{- end -}}

{{- define "prometheus.nodeExporter.matchLabels" -}}
component: {{ .Values.nodeExporter.name | quote }}
{{ include "prometheus.common.matchLabels" . }}
{{- end -}}

{{- define "prometheus.pushgateway.labels" -}}
{{ include "prometheus.pushgateway.matchLabels" . }}
{{ include "prometheus.common.metaLabels" . }}
{{- end -}}

{{- define "prometheus.pushgateway.matchLabels" -}}
component: {{ .Values.pushgateway.name | quote }}
{{ include "prometheus.common.matchLabels" . }}
{{- end -}}

{{- define "prometheus.server.labels" -}}
{{ include "prometheus.server.matchLabels" . }}
{{ include "prometheus.common.metaLabels" . }}
{{- end -}}

{{- define "prometheus.server.matchLabels" -}}
component: {{ .Values.server.name | quote }}
{{ include "prometheus.common.matchLabels" . }}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "prometheus.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Figure out the config based on
the value of airgapped.repository
*/}}
{{- define "get.cmreloadimage" }}
{{- if not .Values.global.rhMarketPlace }}
{{- if .Values.global.airgapped.repository }}
{{- printf "%s/configmap-reload:%s" .Values.global.airgapped.repository (include "get.cmReloadImageTag" .) }}
{{- else }}
{{- printf "%s:%s" (include "get.cmReloadImageRepo" .) (include "get.cmReloadImageTag" .) }}
{{- end }}
{{- else }}
{{- printf "%s" (get .Values.global.images "configmap-reload") }}
{{- end -}}
{{- end }}

{{/*
Figure out the config based on
the value of airgapped.repository
*/}}
{{- define "get.serverimage" }}
{{- if not .Values.global.rhMarketPlace }}
{{- if .Values.global.airgapped.repository }}
{{- printf "%s/prometheus:%s" .Values.global.airgapped.repository (include "get.promImageTag" .) }}
{{- else }}
{{- printf "%s:%s" (include "get.promImageRepo" .) (include "get.promImageTag" .) }}
{{- end }}
{{- else }}
{{- printf "%s" (get .Values.global.images "prometheus") }}
{{- end -}}
{{- end }}


{{/*
Figure out the configmap-reload image tag
based on the value of global.upstreamCertifiedImages
*/}}
{{- define "get.cmReloadImageTag"}}
{{- if .Values.global.upstreamCertifiedImages }}
{{- if .Values.global.airgapped.repository }}
{{- printf "k10-%s-rh-ubi" (include "k10.prometheusConfigMapReloaderImageTag" .) }}
{{- else }}
{{- printf "%s-rh-ubi" (include "k10.prometheusConfigMapReloaderImageTag" .) }}
{{- end }}
{{- else }}
{{- if .Values.global.airgapped.repository }}
{{- printf "k10-%s" (include "k10.prometheusConfigMapReloaderImageTag" .) }}
{{- else }}
{{- printf "%s" (include "k10.prometheusConfigMapReloaderImageTag" .) }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Figure out the prometheus image tag
based on the value of global.upstreamCertifiedImages
*/}}
{{- define "get.promImageTag"}}
{{- if .Values.global.upstreamCertifiedImages }}
{{- if .Values.global.airgapped.repository }}
{{- printf "k10-%s-rh-ubi" (include "k10.prometheusImageTag" .) }}
{{- else }}
{{- printf "%s-rh-ubi" (include "k10.prometheusImageTag" .) }}
{{- end }}
{{- else }}
{{- if .Values.global.airgapped.repository }}
{{- printf "k10-%s" (include "k10.prometheusImageTag" .) }}
{{- else }}
{{- printf "%s" (include "k10.prometheusImageTag" .) }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Figure out the configmap-reload image repo
based on the value of global.upstreamCertifiedImages
*/}}
{{- define "get.cmReloadImageRepo" }}
{{- if .Values.global.upstreamCertifiedImages }}
{{- printf "%s/%s/configmap-reload" .Values.k10image.registry .Values.k10image.repository }}
{{- else }}
{{- print .Values.configmapReload.prometheus.image.repository }}
{{- end }}
{{- end }}

{{/*
Figure out the prom image repo
based on the value of global.upstreamCertifiedImages
*/}}
{{- define "get.promImageRepo" }}
{{- if .Values.global.upstreamCertifiedImages }}
{{- printf "%s/%s/prometheus" .Values.k10image.registry .Values.k10image.repository }}
{{- else }}
{{- print .Values.server.image.repository }}
{{- end }}
{{- end }}

{{/*
Create a fully qualified alertmanager name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}

{{- define "prometheus.alertmanager.fullname" -}}
{{- if .Values.alertmanager.fullnameOverride -}}
{{- .Values.alertmanager.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.alertmanager.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.alertmanager.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified node-exporter name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "prometheus.nodeExporter.fullname" -}}
{{- if .Values.nodeExporter.fullnameOverride -}}
{{- .Values.nodeExporter.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.nodeExporter.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.nodeExporter.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified Prometheus server name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "prometheus.server.fullname" -}}
{{- if .Values.server.fullnameOverride -}}
{{- .Values.server.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.server.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.server.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified Prometheus server clusterrole name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "prometheus.server.clusterrolefullname" -}}
{{- if .Values.server.clusterRoleNameOverride -}}
{{- .Values.server.clusterRoleNameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- if .Values.server.fullnameOverride -}}
{{- printf "%s-%s" .Release.Name .Values.server.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.server.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.server.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified pushgateway name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "prometheus.pushgateway.fullname" -}}
{{- if .Values.pushgateway.fullnameOverride -}}
{{- .Values.pushgateway.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.pushgateway.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.pushgateway.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for deployment.
*/}}
{{- define "prometheus.deployment.apiVersion" -}}
{{- if semverCompare "<1.9-0" .Capabilities.KubeVersion.GitVersion -}}
{{- print "extensions/v1beta1" -}}
{{- else if semverCompare "^1.9-0" .Capabilities.KubeVersion.GitVersion -}}
{{- print "apps/v1" -}}
{{- end -}}
{{- end -}}
{{/*
Return the appropriate apiVersion for daemonset.
*/}}
{{- define "prometheus.daemonset.apiVersion" -}}
{{- if semverCompare "<1.9-0" .Capabilities.KubeVersion.GitVersion -}}
{{- print "extensions/v1beta1" -}}
{{- else if semverCompare "^1.9-0" .Capabilities.KubeVersion.GitVersion -}}
{{- print "apps/v1" -}}
{{- end -}}
{{- end -}}
{{/*
Return the appropriate apiVersion for networkpolicy.
*/}}
{{- define "prometheus.networkPolicy.apiVersion" -}}
{{- if semverCompare ">=1.4-0, <1.7-0" .Capabilities.KubeVersion.GitVersion -}}
{{- print "extensions/v1beta1" -}}
{{- else if semverCompare "^1.7-0" .Capabilities.KubeVersion.GitVersion -}}
{{- print "networking.k8s.io/v1" -}}
{{- end -}}
{{- end -}}
{{/*
Return the appropriate apiVersion for podsecuritypolicy.
*/}}
{{- define "prometheus.podSecurityPolicy.apiVersion" -}}
{{- if semverCompare ">=1.3-0, <1.10-0" .Capabilities.KubeVersion.GitVersion -}}
{{- print "extensions/v1beta1" -}}
{{- else if semverCompare "^1.10-0" .Capabilities.KubeVersion.GitVersion -}}
{{- print "policy/v1beta1" -}}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use for the alertmanager component
*/}}
{{- define "prometheus.serviceAccountName.alertmanager" -}}
{{- if .Values.serviceAccounts.alertmanager.create -}}
    {{ default (include "prometheus.alertmanager.fullname" .) .Values.serviceAccounts.alertmanager.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccounts.alertmanager.name }}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use for the nodeExporter component
*/}}
{{- define "prometheus.serviceAccountName.nodeExporter" -}}
{{- if .Values.serviceAccounts.nodeExporter.create -}}
    {{ default (include "prometheus.nodeExporter.fullname" .) .Values.serviceAccounts.nodeExporter.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccounts.nodeExporter.name }}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use for the pushgateway component
*/}}
{{- define "prometheus.serviceAccountName.pushgateway" -}}
{{- if .Values.serviceAccounts.pushgateway.create -}}
    {{ default (include "prometheus.pushgateway.fullname" .) .Values.serviceAccounts.pushgateway.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccounts.pushgateway.name }}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use for the server component
*/}}
{{- define "prometheus.serviceAccountName.server" -}}
{{- if .Values.serviceAccounts.server.create -}}
    {{ default (include "prometheus.server.fullname" .) .Values.serviceAccounts.server.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccounts.server.name }}
{{- end -}}
{{- end -}}

{{/*
Define the prometheus.namespace template if set with forceNamespace or .Release.Namespace is set
*/}}
{{- define "prometheus.namespace" -}}
{{- if .Values.forceNamespace -}}
{{ printf "namespace: %s" .Values.forceNamespace }}
{{- else -}}
{{ printf "namespace: %s" .Release.Namespace }}
{{- end -}}
{{- end -}}
