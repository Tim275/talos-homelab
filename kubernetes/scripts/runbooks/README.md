# Runbooks

Nach einem Vorfall: [Postmortem-Vorlage](postmortem-template.md) · Wann Releases stoppen: [Error-Budget-Policy](error-budget-policy.md)

Jeder Page-Alarm verlinkt über `runbook_url` direkt auf seinen Abschnitt. Der Runbook-Button in Slack führt dorthin.

## Control Plane

| Alarm | Stufe |
|---|---|
| [ClusterAPIServerDown](control-plane.md#clusterapiserverdown) | Page |
| [ControlPlaneNodeDown](control-plane.md#controlplanenodedown) | Page |
| [EtcdQuorumLoss](control-plane.md#etcdquorumloss) | Page |
| [CoreDNSDown](control-plane.md#corednsdown) | Page |
| [etcdHighFsyncDurations](control-plane.md#etcdhighfsyncdurations) | Ticket |
| [etcdHighNumberOfFailedGRPCRequests](control-plane.md#etcdhighnumberoffailedgrpcrequests) | Ticket |
| [etcdDatabaseQuotaLowSpace](control-plane.md#etcddatabasequotalowspace) | Page |
| [AdmissionWebhookRejecting](control-plane.md#admissionwebhookrejecting) | Page |
| [KubeSchedulerDown](control-plane.md#kubeschedulerdown) | Page |
| [KubeControllerManagerDown](control-plane.md#kubecontrollermanagerdown) | Page |
| [KubeletScrapeTargetsManyDown](control-plane.md#kubeletscrapetargetsmanydown) | Ticket |

## Proxmox-Hosts

| Alarm | Stufe |
|---|---|
| [ProxmoxHostDown](hosts.md#proxmoxhostdown) | Page |
| [ProxmoxHostRebootLoop](hosts.md#proxmoxhostrebootloop) | Page |
| [ProxmoxStorageCritical](hosts.md#proxmoxstoragecritical) | Page |
| [ProxmoxZfsPoolCritical](hosts.md#proxmoxzfspoolcritical) | Page |
| [HostRootFilesystemCritical](hosts.md#hostrootfilesystemcritical) | Page |
| [HostCPUTemperatureCritical](hosts.md#hostcputemperaturecritical) | Page |
| [HostBridgeDown](hosts.md#hostbridgedown) | Page |
| [SSDSmartHealthFailed](hosts.md#ssdsmarthealthfailed) | Ticket |
| [SSDCriticalWarning](hosts.md#ssdcriticalwarning) | Ticket |
| [SSDMediaErrors](hosts.md#ssdmediaerrors) | Ticket |

## Netzwerk

| Alarm | Stufe |
|---|---|
| [InternetConnectivityLost](network.md#internetconnectivitylost) | Page |
| [HomelabEdgeDown](network.md#homelabedgedown) | Page |
| [LogsGatewayRoutesDisabled](network.md#logsgatewayroutesdisabled) | Page |
| [CloudflaredAllDown](network.md#cloudflaredalldown) | Page |
| [CloudflaredNoEdgeConnections](network.md#cloudflarednoedgeconnections) | Page |
| [EnvoyEdgeSLOFastBurn](network.md#envoyedgeslofastburn) | Page |
| [EnvoyEdgeSLOSlowBurn](network.md#envoyedgeslofastburn) | Page |
| [CiliumAgentsCrashing](network.md#ciliumagentscrashing) | Page |
| [IstiodDown](network.md#istioddown) | Ticket |
| [ZtunnelNodeDown](network.md#ztunnelnodedown) | Page |
| [NetBirdRoutingPeerDown](network.md#netbirdroutingpeerdown) | Ticket |
| [RateLimitServiceDown](network.md#ratelimitservicedown) | Ticket |

## Storage

| Alarm | Stufe |
|---|---|
| [CephHealthError](storage.md#cephhealtherror) | Page |
| [CephMonQuorumAtRisk](storage.md#cephmonquorumatrisk) | Page |
| [CephOSDMajorityDown](storage.md#cephosdmajoritydown) | Page |
| [LogsDiskIOError](storage.md#logsdiskioerror) | Ticket |
| [PVCCriticallyFull](storage.md#pvccriticallyfull) | Page |
| [VeleroNoRecentBackup](storage.md#veleronorecentbackup) | Ticket |
| [VeleroNoRecentWeeklyBackup](storage.md#veleronorecentweeklybackup) | Ticket |

## Daten

| Alarm | Stufe |
|---|---|
| [CnpgPrimaryDown](data.md#cnpgprimarydown) | Page |
| [CNPGBackupStale](data.md#cnpgbackupstale) | Ticket |
| [KafkaOfflinePartitions](data.md#kafkaofflinepartitions) | Page |

## Plattform

| Alarm | Stufe |
|---|---|
| [KeycloakDown](platform.md#keycloakdown) | Page |
| [KeycloakBurnRateFast](platform.md#keycloakburnratefast) | Page |
| [KeycloakBurnRateSlow](platform.md#keycloakburnratefast) | Page |
| [N8NBurnRateFast](platform.md#n8nburnratefast) | Page |
| [N8NBurnRateSlow](platform.md#n8nburnratefast) | Page |
| [ArgoCDAppsMassDeletion](platform.md#argocdappsmassdeletion) | Page |
| [CertExpiringIn7Days](platform.md#certexpiringin7days) | Ticket |
| [SealedSecretsCertExpiresIn14Days](platform.md#sealedsecretscertexpiresin14days) | Ticket |
| [LogsSealedSecretsDecryptFailure](platform.md#logssealedsecretsdecryptfailure) | Ticket |
| [LogsAuditAnonymousAccess](platform.md#logsauditanonymousaccess) | Page |
| [PrometheusPodMissing](platform.md#prometheuspodmissing) | Page |
| [AlertmanagerPodMissing](platform.md#alertmanagerpodmissing) | Page |
| [AlertmanagerClusterFailedToSendAlerts](platform.md#alertmanagerclusterfailedtosendalerts) | Page |

## Drova

| Alarm | Stufe |
|---|---|
| [DrovaApiGatewayBurnRateFast](drova.md#fehler-burn) | Page |
| [DrovaApiGatewayBurnRateSlow](drova.md#fehler-burn) | Page |
| [DrovaUserServiceBurnRateFast](drova.md#fehler-burn) | Page |
| [DrovaUserServiceBurnRateSlow](drova.md#fehler-burn) | Page |
| [DrovaTripServiceBurnRateFast](drova.md#fehler-burn) | Page |
| [DrovaTripServiceBurnRateSlow](drova.md#fehler-burn) | Page |
| [DrovaDriverServiceBurnRateFast](drova.md#fehler-burn) | Page |
| [DrovaDriverServiceBurnRateSlow](drova.md#fehler-burn) | Page |
| [DrovaChatServiceBurnRateFast](drova.md#fehler-burn) | Page |
| [DrovaChatServiceBurnRateSlow](drova.md#fehler-burn) | Page |
| [DrovaApiGatewayLatencyBurnRateFast](drova.md#latenz-burn) | Page |
| [DrovaApiGatewayLatencyBurnRateSlow](drova.md#latenz-burn) | Page |
| [DrovaUserServiceLatencyBurnRateFast](drova.md#latenz-burn) | Page |
| [DrovaUserServiceLatencyBurnRateSlow](drova.md#latenz-burn) | Page |
| [DrovaTripServiceLatencyBurnRateFast](drova.md#latenz-burn) | Page |
| [DrovaTripServiceLatencyBurnRateSlow](drova.md#latenz-burn) | Page |
| [DrovaDriverServiceLatencyBurnRateFast](drova.md#latenz-burn) | Page |
| [DrovaDriverServiceLatencyBurnRateSlow](drova.md#latenz-burn) | Page |
| [DrovaChatServiceLatencyBurnRateFast](drova.md#latenz-burn) | Page |
| [DrovaChatServiceLatencyBurnRateSlow](drova.md#latenz-burn) | Page |
| [DrovaRpcHopFailing](drova.md#drovarpchopfailing) | Ticket |
