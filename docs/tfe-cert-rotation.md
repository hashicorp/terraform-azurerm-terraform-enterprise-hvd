# TFE Certificate Rotation

A required prerequisite to deploying this module is storing a base64-encoded string of your TFE TLS certificate file (PEM format) and a base64-encoded string of your TFE TLS certificate private key file (PEM format) in an Azure Key Vault for bootstrapping purposes. The steps to rotate these certificates are simply to update these two secrets within your "bootstrap" Azure Key Vault, update the applicable module input variables with the new Key Vault secret identifiers, and then replace/re-image the VM(s) within your TFE virtual machine scale set (VMSS).

## Procedure

1. Obtain your new TFE TLS certificate and private key files (both in PEM format).
   
2. Update the existing secrets within your "bootstrap" Azure Key Vault with the new values (base64-encoded strings). To base64-encode the strings:
   
   On Linux (bash):
   ```sh
   cat new_tfe_cert.pem | base64 -w 0
   cat new_tfe_privkey.pem | base64 -w 0
   ```

   On macOS (terminal):
   ```sh
   cat new_tfe_cert.pem | base64
   cat new_tfe_privkey.pem | base64
   ```

   On Windows (PowerShell):
   ```powershell
   function ConvertTo-Base64 {
    param (
        [Parameter(Mandatory=$true)]
        [string]$InputString
    )
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
    $EncodedString = [Convert]::ToBase64String($Bytes)
    return $EncodedString
   }

   Get-Content new_tfe_cert.pem -Raw | ConvertTo-Base64 -Width 0
   Get-Content new_tfe_privkey.pem -Raw | ConvertTo-Base64 -Width 0
   ```

   After this step, you should have new secret versions for each of these secrets with new secret identifier values.

   >📝 Note: Ensure that no new-line characters were added when you base64-encoded your certs.

3. Update the following input variable values within your `terraform.tfvars` file with the new Key Vault secret identifiers:
   
   ```hcl
   tfe_tls_cert_keyvault_secret_id    = "<https://new-tfe-cert-key-vault-secret-identifier>"
   tfe_tls_privkey_keyvault_secret_id = "<https://new-tfe-privkey-key-vault-secret-identifier>"
   ```

4. During a maintenance window, run `terraform apply` against your root Terraform configuration that manages your TFE deployment.

5. Ensure that the VM(s) within the TFE VMSS have been replaced/re-imaged with the changes. Monitor the cloud-init process to ensure a successful re-install.