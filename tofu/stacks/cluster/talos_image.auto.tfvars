talos_image = {
  factory_url       = "https://factory.talos.dev"
  version           = "v1.14.6" # renovate: github-releases=siderolabs/talos
  schematic_path    = "../../modules/talos/image/schematic.yaml"
  arch              = "amd64"
  platform          = "nocloud"
  proxmox_datastore = "local"
}