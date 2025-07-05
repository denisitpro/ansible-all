
# Instructions for Configuring Vault Secrets Operator

## Step 1: Extract Kubernetes CA Certificate
```bash
kubectl -n kube-system get configmap kube-root-ca.crt -o jsonpath='{.data.ca\.crt}' > k8s-ca.crt
```
### Verify the certificate
```bash
openssl x509 -in k8s-ca.crt -text -noout
```

## Step 2: Create vault-reviewer ServiceAccount
```bash
kubectl create sa vault-reviewer -n kube-system

kubectl create clusterrolebinding vault-reviewer-binding \
  --clusterrole=system:auth-delegator \
  --serviceaccount=kube-system:vault-reviewer

kubectl create token vault-reviewer --duration=8760h -n kube-system > reviewer.token
```

## Step 3: Move Token to Terraform
Use Terraform to create and configure the Vault Kubernetes auth engine and role. You need to move the `k8s-ca.crt` and `reviewer.token` files into the Terraform repository and create or update the corresponding role binding.

### Example: How to Check the Token
```bash
# Decode token and verify subject
cat reviewer.token | cut -d '.' -f2 | base64 -d | jq '.sub'
# Optionally verify token expiration (manual step)
```

## Step 4: Validate Pod Token Retrieval
Deploy a simple debug pod using the following manifest:
``` yaml
apiVersion: v1
kind: Pod
metadata:
  name: vault-debug
  namespace: vault-secrets-operator
spec:
  serviceAccountName: vault-secrets-operator-controller-manager
  containers:
  - name: debug
    image: denisitpro/net-tools:1.5
    command: ["sleep", "3600"]
    env:
    - name: VAULT_ADDR
      value: "https://vault.example.com"
  restartPolicy: Never
```
After the pod starts, open a shell session: `k exec -it vault-debug -- sh`

Then run the following commands inside the pod:
```bash
# Example VAULT_ADDR (replace with your own)
export VAULT_ADDR=https://vault.example.org
vault write auth/kubernetes-example/login role="vso-role-example" jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
```
