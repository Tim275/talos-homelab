# harbor

Projekte, Robot-Accounts, unveränderliche Release-Tags und Garbage Collection von Harbor als Code. Die Instanz selbst
kommt per GitOps (`kubernetes/platform/delivery/harbor`), die Anmeldung über Keycloak setzt dort `CONFIG_OVERWRITE_JSON`.
Apply läuft über `tofu-cd.yml` nach dem Merge, lokal `tofu plan` mit `TF_VAR_harbor_password`
(Secret `harbor-secrets` in `harbor`, Schlüssel `HARBOR_ADMIN_PASSWORD`).
Keine Retention-Regel: Harbor löscht unveränderliche Tags nicht, die Quota begrenzt das Projekt.
Die Robot-Secrets verwaltet der Stack nicht. Sie liegen in OpenBao (`harbor/robot-drova-pull`) und als
`HARBOR_USERNAME`/`HARBOR_PASSWORD` im Repo drova.
Projekte und Robots sind von Hand angelegt und stehen in `imports.tofu`, auf einer leeren Instanz die Datei entfernen.
