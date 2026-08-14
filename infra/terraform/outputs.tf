output "instance_public_ip" {
  description = "Public IP of the birthday VM"
  value       = oci_core_instance.main.public_ip
}

output "compartment_id" {
  description = "Compartment used for all resources"
  value       = local.compartment_id
}

output "ssh_command" {
  description = "How to reach the VM"
  value       = "ssh -i <your-private-key> opc@${oci_core_instance.main.public_ip}"
}

output "deploy_ready_note" {
  value = "Point your DuckDNS subdomain at ${oci_core_instance.main.public_ip}, then run the Ansible bootstrap playbook."
}
