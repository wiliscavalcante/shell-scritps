---

# **Documentação do Script de Configuração do Cluster Kubernetes com Kubeadm e CRI-O usando ZFS**

## **Visão Geral**
Este script automatiza a configuração de um ambiente Kubernetes utilizando o `kubeadm`, `CRI-O` como runtime de contêineres e `ZFS` como backend de armazenamento. Além disso, ele inclui a flexibilidade de gerenciar proxies tanto no sistema operacional quanto no CRI-O. A configuração foi projetada para sistemas **RHEL 9**.

### **Objetivos do Script**
1. **Configuração do ambiente de proxy no sistema operacional**.
2. **Desativação do swap**, configuração de roteamento de pacotes e carregamento de módulos de rede.
3. **Instalação e configuração dos repositórios do Kubernetes e CRI-O**.
4. **Configuração do ZFS como driver de armazenamento** para o CRI-O.
5. **Funções para ativar e desativar o proxy no CRI-O**, que estão disponíveis para uso manual, mas não são executadas automaticamente.

---

## **Detalhes das Etapas do Script**

### **1. Configuração do Proxy Global no Sistema Operacional**

- **Função: `proxy-on` e `proxy-off`**
  
  O script cria um arquivo de configuração de proxy em `/etc/profile.d/proxy.sh` que pode ativar ou desativar o proxy globalmente no sistema operacional. Isso é útil para garantir que todas as operações que exigem internet, como o download de pacotes ou imagens de contêiner, sejam realizadas de forma adequada quando há um proxy corporativo envolvido.

  - **Proxy-on**: Ativa o proxy no sistema operacional, permitindo que as operações usem o proxy definido.
  - **Proxy-off**: Desativa o proxy global, removendo as variáveis de ambiente relacionadas ao proxy.

  O proxy pode ser configurado com credenciais do usuário, se necessário, e as URLs específicas do proxy corporativo são definidas diretamente no script.

  **Exemplo de uso:**
  - O script ativa automaticamente o proxy, caso não esteja ativo no ambiente, ao ser executado.

---

### **2. Desativação do Swap**

- **Comando: `swapoff -a`**
  
  O Kubernetes não funciona corretamente com o swap ativado. Esta etapa garante que o swap seja desativado e removido de `/etc/fstab`, para que ele não seja reativado em reinicializações futuras.

---

### **3. Habilitação de Encaminhamento de Pacotes IPv4**

- **Configuração: `sysctl net.ipv4.ip_forward`**

  O encaminhamento de pacotes IPv4 é habilitado para permitir a comunicação correta entre os pods e os nós no cluster Kubernetes.

---

### **4. Carregamento do Módulo `br_netfilter`**

- **Módulo: `br_netfilter`**
  
  O módulo `br_netfilter` é carregado e configurado para ser carregado automaticamente nas reinicializações. Ele é essencial para que o Kubernetes gerencie o tráfego de rede entre os pods.

---

### **5. Configuração de Nameservers**

- **Arquivo: `/etc/resolv.conf`**

  Nameservers são configurados para garantir que a resolução de DNS funcione corretamente para os serviços internos e externos.

---

### **6. Configuração dos Repositórios do Kubernetes e CRI-O**

- **Repositório Kubernetes:**
  O repositório oficial do Kubernetes é configurado no arquivo `/etc/yum.repos.d/kubernetes.repo`. Isso garante que os pacotes necessários, como `kubelet`, `kubeadm`, e `kubectl`, possam ser instalados corretamente.

- **Repositório CRI-O:**
  O repositório oficial do CRI-O é configurado no arquivo `/etc/yum.repos.d/cri-o.repo`, garantindo a instalação direta do runtime CRI-O a partir das fontes corretas.

---

### **7. Instalação de Dependências**

- **Pacote `container-selinux`**
  
  O script verifica se o pacote `container-selinux` está instalado e o instala, se necessário. Este pacote é essencial para garantir que os contêineres funcionem corretamente em sistemas que utilizam SELinux.

---

### **8. Configuração do ZFS e CRI-O**

- **ZFS Pool `crio-pool`**
  
  O ZFS é configurado como backend de armazenamento para o CRI-O. Um pool ZFS chamado `crio-pool` é criado no disco e configurado para ser o driver de armazenamento padrão do CRI-O.

- **Configuração do CRI-O**
  Após a criação do pool ZFS, o CRI-O é configurado para usar o ZFS como driver de armazenamento:
  
  ```bash
  [crio]
  storage_driver = "zfs"
  storage_option = [
    "zfs.zpool=crio-pool"
  ]
  ```

---

### **9. Instalação do kubeadm, kubelet e kubectl**

- **Pacotes: `kubeadm`, `kubelet`, `kubectl`**

  Estes pacotes são instalados a partir do repositório Kubernetes configurado anteriormente. O `kubelet` é habilitado para iniciar automaticamente e permanecer ativo. Estes pacotes são essenciais para inicializar e gerenciar o cluster Kubernetes.

---

### **10. Funções para Ativar e Desativar o Proxy no CRI-O**

- **Funções: `ativar_proxy_crio` e `desativar_proxy_crio`**

  O script define duas funções para ativar e desativar o proxy no CRI-O. Elas são úteis em ambientes onde é necessário alternar entre o uso do proxy para baixar imagens de contêineres e desativar o proxy para outras operações, como o `kubeadm init`. 

  - **Ativar Proxy no CRI-O**: Adiciona as configurações de proxy ao serviço CRI-O e reinicia o serviço.
  - **Desativar Proxy no CRI-O**: Remove as configurações de proxy do CRI-O e reinicia o serviço.

  **Importante**: Essas funções **não são executadas automaticamente** no script. Elas estão disponíveis para serem chamadas manualmente conforme necessário.

  **Exemplo de uso:**
  - **Ativar proxy no CRI-O**: Execute `ativar_proxy_crio` para ativar o proxy quando for necessário baixar imagens.
  - **Desativar proxy no CRI-O**: Execute `desativar_proxy_crio` para remover o proxy antes de executar o `kubeadm init`.

---

## **Uso Geral do Script**

1. O script pode ser executado como um todo para configurar um ambiente pronto para rodar o **kubeadm init** em um sistema com **RHEL 9**.
2. Ele ativa automaticamente o proxy no sistema operacional, se necessário.
3. **As funções de proxy para o CRI-O ficam disponíveis, mas são chamadas manualmente**, permitindo flexibilidade ao administrador.
4. O **ZFS** é configurado para ser o backend de armazenamento para o CRI-O, garantindo uma solução robusta para armazenamento de contêineres.

---

### **Observações Finais**

- **Ambiente de Proxy:** Certifique-se de ajustar os valores de proxy, nameservers e outros detalhes de rede de acordo com o seu ambiente.
- **ZFS:** Se o ZFS não for necessário no seu ambiente, revise as etapas relacionadas ao ZFS.
- **Funções de Proxy no CRI-O:** Estas funções são úteis para alternar rapidamente entre o uso e a desativação do proxy no CRI-O, dependendo das operações a serem realizadas no cluster.

---
