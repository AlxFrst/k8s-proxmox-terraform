resource "proxmox_vm_qemu" "k8s_node" {
  depends_on  = [proxmox_vm_qemu.k8s_controller]
  count       = var.node_count
  name        = "${var.pm_vm_name_prefix}-node-${count.index + 1}"
  target_node = var.pm_node
  clone       = var.pm_template_name
  agent       = 1
  os_type     = "cloud-init"
  cores       = var.node_cores
  sockets     = 1
  cpu         = "host"
  memory      = var.node_memory
  scsihw      = "virtio-scsi-pci"
  ipconfig0   = "ip=dhcp"
  ciuser      = var.vm_user
  cipassword  = var.vm_password
  sshkeys     = var.ssh_public_key
  qemu_os     = "l26"
  disk {
    slot    = 0
    size    = var.node_disk_size
    type    = "scsi"
    storage = var.pm_storage
  }

  network {
    model  = "virtio"
    bridge = var.pm_bridge
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      user        = var.vm_user
      private_key = var.ssh_private_key
      host        = self.ssh_host
    }
    source      = "assets/nodeInstaller.sh"
    destination = "/tmp/nodeInstaller.sh"
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.vm_user
      private_key = var.ssh_private_key
      host        = self.ssh_host
    }
    inline = [
      "echo 'Starting Node ${count.index + 1} Provisioner 🚀'",
      "chmod +x /tmp/nodeInstaller.sh",
      "sudo /tmp/nodeInstaller.sh",
      "sudo apt install -y nfs-common",

      # create the .ssh folder
      "sudo mkdir -p /home/${var.vm_user}/.ssh",
      "sudo chown -R ${var.vm_user}:${var.vm_user} /home/${var.vm_user}/.ssh",
      "sudo chmod 700 /home/${var.vm_user}/.ssh",
      "echo '${var.ssh_private_key}' > /home/${var.vm_user}/.ssh/id_rsa",
      "sed -i 's/\\n//g' /home/${var.vm_user}/.ssh/id_rsa", #remove this line if your private key is not on multiple lines
      "sudo chmod 600 /home/${var.vm_user}/.ssh/id_rsa",

      # copy the join command from the controller to the node and execute it
      "scp -o StrictHostKeyChecking=no -i /home/${var.vm_user}/.ssh/id_rsa ${var.vm_user}@${proxmox_vm_qemu.k8s_controller.0.ssh_host}:/tmp/joinCommand.sh /tmp/joinCommand.sh",
      "sudo chmod +x /tmp/joinCommand.sh",
      "sudo /tmp/joinCommand.sh",

      # remove ssh key from the node
      "sudo rm /home/${var.vm_user}/.ssh/id_rsa",
      "echo 'Node ${count.index + 1} Provisioner Complete 🎉'",

    ]
  }
}
