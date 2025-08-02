talos_image = {
  factory_url = "https://factory.talos.dev"
  version     = "v1.10.6"
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