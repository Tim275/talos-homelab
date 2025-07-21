talos_image = {
  factory_url = "https://factory.talos.dev"
  version     = "v1.7.5"
  schematic   = <<-EOT
customization:
  systemExtensions:
    officialExtensions:
      - siderolabs/qemu-guest-agent
      - siderolabs/intel-ucode
EOT
  arch        = "amd64"
  platform    = "nocloud"
  proxmox_datastore = "local"
}