resource "proxmox_vm_qemu" "k8s_controller" {
  depends_on = [ proxmox_vm_qemu.k8s_storage ]
  count       = 1
  name        = "${var.pm_vm_name_prefix}-controller"
  target_node = var.pm_node
  clone       = var.pm_template_name
  agent       = 1
  os_type     = "cloud-init"
  cores       = var.controller_cores
  sockets     = 1
  cpu         = "host"
  memory      = var.controller_memory
  scsihw      = "virtio-scsi-pci"
  ipconfig0   = "ip=dhcp"
  ciuser      = var.vm_user
  cipassword  = var.vm_password
  disk {
    slot    = 0
    size    = var.controller_disk_size
    type    = "scsi"
    storage = var.pm_storage
  }

  network {
    model  = "virtio"
    bridge = var.pm_bridge
  }

  # share the assets folder with the VMx
  provisioner "file" {
    connection {
      type        = "ssh"
      user        = var.vm_user
      password = var.vm_user
      host        = self.ssh_host
    }
    source      = "assets/installController.sh"
    destination = "/tmp/installController.sh"
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      user        = var.vm_user
      password = var.vm_user
      host        = self.ssh_host
    }
    source      = "assets/metallb-namespace.yaml"
    destination = "/tmp/metallb-namespace.yaml"
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      user        = var.vm_user
      password = var.vm_user
      host        = self.ssh_host
    }
    source      = "assets/metallb-config.yaml"
    destination = "/tmp/metallb-config.yaml"
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      user        = var.vm_user
      password = var.vm_user
      host        = self.ssh_host
    }
    source      = "assets/gitlab-deployment.yaml"
    destination = "/tmp/gitlab-deployment.yaml"
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.vm_user
      password = var.vm_user
      host        = self.ssh_host
    }
    inline = [
      "chmod +x /tmp/installController.sh",
      "sudo /tmp/installController.sh",
      "sudo kubeadm token create --print-join-command > /tmp/joinCommand.sh",

      # Install helm
      "sudo curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3",
      "sudo bash get_helm.sh",

      # Install metallb & configure metallb
      "echo 'Installing metallb'",
      "sudo kubectl apply -f /tmp/metallb-namespace.yaml",
      "sudo kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/metallb.yaml",
      "sudo sed -i 's/#RANGE#/${var.metallb_ip_range}/g' /tmp/metallb-config.yaml",
      "sudo kubectl apply -f /tmp/metallb-config.yaml",   
    ]
  }

}