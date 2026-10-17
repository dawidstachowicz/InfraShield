# InfraShield - Automated Azure Infrastructure & OS Hardening

**InfraShield** is an automated, secure cloud infrastructure environment deployed on Microsoft Azure. The project demonstrates a modern **DevSecOps** approach using Infrastructure as Code (IaC) with **Terraform**, Configuration as Code (CaC) with **Ansible**, and automated CI/CD pipelines with **Azure DevOps** in accordance with the CIS Benchmark standard.

---

## 🚀 Key Features

* **Modular Infrastructure (IaC):** Automated provisioning of Azure resources (vNet, Subnet, NSG, VM, Key Vault) via Terraform.
* **OS Hardening (CaC):** Agentless system configuration and security hardening based on **CIS Benchmarks** using Ansible.
* **DevSecOps & SAST:** Automated code scanning and security checks in CI/CD pipelines.
* **Zero Static Credentials:** Passwordless authentication using **Workload Identity Federation (OIDC)**.
* **Isolated State Management:** Terraform state stored securely in an isolated resource group (`rg-tfstate`) with State Locking and Encryption at Rest.

---

## 🛠️ Tech Stack

* **Cloud Provider:** Microsoft Azure
* **Infrastructure as Code:** Terraform
* **Configuration as Code:** Ansible
* **CI/CD Platform:** Azure DevOps
* **Security & Hardening:** CIS Benchmark, Azure Key Vault, OIDC

---

## 📁 Repository Structure

```text
InfraShield/
├── pipelines/    # Azure DevOps CI/CD pipeline definitions
├── ansible/             # Ansible playbooks, roles, and inventory
│   ├── inventory/
│   ├── playbooks/
│   └── roles/
│       └── hardening/   # CIS Benchmark OS hardening role
├── terraform/           # Terraform modules and main configuration
│   └── modules/
│       ├── network/     # vNet, Subnet, NSG, Public IP
│       └── vm/          # Linux Virtual Machine & NIC
├── .gitignore           # Prevents secrets and transient state from being committed
└── README.md            # Project documentation