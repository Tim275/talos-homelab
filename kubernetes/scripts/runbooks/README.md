# Runbooks

Nach einem Vorfall: [Postmortem-Vorlage](postmortem-template.md) · Wann Releases stoppen: [Error-Budget-Policy](error-budget-policy.md)

Jeder P0/P1-Alarm verlinkt über `runbook_url` direkt auf seinen Abschnitt. Der Runbook-Button in Slack führt dorthin.

## Control Plane

| Alarm | Priorität |
|---|---|
| [ClusterAPIServerDown](control-plane.md#clusterapiserverdown) | P0 |
| [ControlPlaneNodeDown](control-plane.md#controlplanenodedown) | P0 |
| [EtcdQuorumLoss](control-plane.md#etcdquorumloss) | P0 |
| [CoreDNSDown](control-plane.md#corednsdown) | P0 |
| [etcdHighFsyncDurations](control-plane.md#etcdhighfsyncdurations) | P2 |
| [etcdHighNumberOfFailedGRPCRequests](control-plane.md#etcdhighnumberoffailedgrpcrequests) | P2 |
| [etcdDatabaseQuotaLowSpace](control-plane.md#etcddatabasequotalowspace) | P1 |
| [AdmissionWebhookRejecting](control-plane.md#admissionwebhookrejecting) | P1 |
| [KubeSchedulerDown](control-plane.md#kubeschedulerdown) | P1 |
| [KubeControllerManagerDown](control-plane.md#kubecontrollermanagerdown) | P1 |
| [KubeletScrapeTargetsManyDown](control-plane.md#kubeletscrapetargetsmanydown) | P2 |

## Proxmox-Hosts

| Alarm | Priorität |
|---|---|
| [ProxmoxHostDown](hosts.md#proxmoxhostdown) | P0 |
| [ProxmoxHostRebootLoop](hosts.md#proxmoxhostrebootloop) | P1 |
| [ProxmoxStorageCritical](hosts.md#proxmoxstoragecritical) | P1 |
| [ProxmoxZfsPoolCritical](hosts.md#proxmoxzfspoolcritical) | P1 |
| [HostRootFilesystemCritical](hosts.md#hostrootfilesystemcritical) | P1 |
| [HostCPUTemperatureCritical](hosts.md#hostcputemperaturecritical) | P1 |
| [HostBridgeDown](hosts.md#hostbridgedown) | P1 |
| [SSDSmartHealthFailed](hosts.md#ssdsmarthealthfailed) | P2 |
| [SSDCriticalWarning](hosts.md#ssdcriticalwarning) | P2 |
| [SSDMediaErrors](hosts.md#ssdmediaerrors) | P2 |

## Netzwerk

| Alarm | Priorität |
|---|---|
| [InternetConnectivityLost](network.md#internetconnectivitylost) | P0 |
| [HomelabEdgeDown](network.md#homelabedgedown) | P1 |
| [LogsGatewayRoutesDisabled](network.md#logsgatewayroutesdisabled) | P1 |
| [CloudflaredAllDown](network.md#cloudflaredalldown) | P1 |
| [CloudflaredNoEdgeConnections](network.md#cloudflarednoedgeconnections) | P1 |
| [EnvoyEdgeSLOFastBurn](network.md#envoyedgeslofastburn) | P1 |
| [EnvoyEdgeSLOSlowBurn](network.md#envoyedgeslofastburn) | P1 |
| [CiliumAgentsCrashing](network.md#ciliumagentscrashing) | P1 |
| [IstiodDown](network.md#istioddown) | P2 |
| [ZtunnelNodeDown](network.md#ztunnelnodedown) | P1 |
| [NetBirdRoutingPeerDown](network.md#netbirdroutingpeerdown) | P2 |
| [RateLimitServiceDown](network.md#ratelimitservicedown) | P2 |

## Storage

| Alarm | Priorität |
|---|---|
| [CephHealthError](storage.md#cephhealtherror) | P1 |
| [CephMonQuorumAtRisk](storage.md#cephmonquorumatrisk) | P1 |
| [CephOSDMajorityDown](storage.md#cephosdmajoritydown) | P1 |
| [LogsDiskIOError](storage.md#logsdiskioerror) | P2 |
| [PVCCriticallyFull](storage.md#pvccriticallyfull) | P1 |
| [VeleroNoRecentBackup](storage.md#veleronorecentbackup) | P2 |
| [VeleroNoRecentWeeklyBackup](storage.md#veleronorecentweeklybackup) | P2 |

## Daten

| Alarm | Priorität |
|---|---|
| [CnpgPrimaryDown](data.md#cnpgprimarydown) | P1 |
| [CNPGBackupStale](data.md#cnpgbackupstale) | P2 |
| [KafkaOfflinePartitions](data.md#kafkaofflinepartitions) | P1 |

## Plattform

| Alarm | Priorität |
|---|---|
| [KeycloakDown](platform.md#keycloakdown) | P1 |
| [KeycloakBurnRateFast](platform.md#keycloakburnratefast) | P1 |
| [KeycloakBurnRateSlow](platform.md#keycloakburnratefast) | P1 |
| [N8NBurnRateFast](platform.md#n8nburnratefast) | P1 |
| [N8NBurnRateSlow](platform.md#n8nburnratefast) | P1 |
| [ArgoCDAppsMassDeletion](platform.md#argocdappsmassdeletion) | P1 |
| [CertExpiringIn7Days](platform.md#certexpiringin7days) | P2 |
| [SealedSecretsCertExpiresIn14Days](platform.md#sealedsecretscertexpiresin14days) | P2 |
| [LogsSealedSecretsDecryptFailure](platform.md#logssealedsecretsdecryptfailure) | P2 |
| [LogsAuditAnonymousAccess](platform.md#logsauditanonymousaccess) | P1 |
| [PrometheusPodMissing](platform.md#prometheuspodmissing) | P1 |
| [AlertmanagerPodMissing](platform.md#alertmanagerpodmissing) | P1 |
| [AlertmanagerClusterFailedToSendAlerts](platform.md#alertmanagerclusterfailedtosendalerts) | P1 |

## Drova

| Alarm | Priorität |
|---|---|
| [DrovaApiGatewayBurnRateFast](drova.md#fehler-burn) | P1 |
| [DrovaApiGatewayBurnRateSlow](drova.md#fehler-burn) | P1 |
| [DrovaUserServiceBurnRateFast](drova.md#fehler-burn) | P1 |
| [DrovaUserServiceBurnRateSlow](drova.md#fehler-burn) | P1 |
| [DrovaTripServiceBurnRateFast](drova.md#fehler-burn) | P1 |
| [DrovaTripServiceBurnRateSlow](drova.md#fehler-burn) | P1 |
| [DrovaDriverServiceBurnRateFast](drova.md#fehler-burn) | P1 |
| [DrovaDriverServiceBurnRateSlow](drova.md#fehler-burn) | P1 |
| [DrovaChatServiceBurnRateFast](drova.md#fehler-burn) | P1 |
| [DrovaChatServiceBurnRateSlow](drova.md#fehler-burn) | P1 |
| [DrovaApiGatewayLatencyBurnRateFast](drova.md#latenz-burn) | P1 |
| [DrovaApiGatewayLatencyBurnRateSlow](drova.md#latenz-burn) | P1 |
| [DrovaUserServiceLatencyBurnRateFast](drova.md#latenz-burn) | P1 |
| [DrovaUserServiceLatencyBurnRateSlow](drova.md#latenz-burn) | P1 |
| [DrovaTripServiceLatencyBurnRateFast](drova.md#latenz-burn) | P1 |
| [DrovaTripServiceLatencyBurnRateSlow](drova.md#latenz-burn) | P1 |
| [DrovaDriverServiceLatencyBurnRateFast](drova.md#latenz-burn) | P1 |
| [DrovaDriverServiceLatencyBurnRateSlow](drova.md#latenz-burn) | P1 |
| [DrovaChatServiceLatencyBurnRateFast](drova.md#latenz-burn) | P1 |
| [DrovaChatServiceLatencyBurnRateSlow](drova.md#latenz-burn) | P1 |
| [DrovaRpcHopFailing](drova.md#drovarpchopfailing) | P2 |
