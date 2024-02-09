Repositório destinado ao armazenamento de scripts shell úteis no dia dia.

Resumo do Cargo:
Como SRE Sênior, você desempenhará um papel chave na garantia da confiabilidade, escalabilidade e desempenho dos nossos sistemas, com um enfoque especial em soluções AWS e práticas integradas de FinOps e DevSecOps. Você colaborará com as equipes de desenvolvimento para implementar infraestruturas robustas, eficientes e seguras, enquanto promove uma cultura de segurança e otimização de custos em toda a organização.

Responsabilidades Principais:

Implementar e gerenciar soluções de confiabilidade e desempenho com foco em AWS.
Integrar práticas de FinOps e DevSecOps para otimização de custos e segurança em todas as fases do desenvolvimento e operações.
Desenvolver e manter sistemas avançados de monitoramento e alerta.
Gerenciar infraestruturas em nuvem, com ênfase na otimização de recursos e custos.
Liderar iniciativas de análise pós-incidente e desenvolvimento de estratégias de prevenção.
Automatizar processos para melhorar a eficiência operacional.
Ficar atualizado com as tendências emergentes em SRE, FinOps, DevSecOps e engenharia de sistemas.
Qualificações Necessárias:

Bacharelado em Ciência da Computação, Engenharia de Software, ou campo relacionado.
Mínimo de 5 anos de experiência em SRE, DevOps ou funções similares.
Profundo conhecimento em sistemas operacionais, redes e segurança de TI.
Experiência robusta com AWS e outras tecnologias de nuvem.
Habilidades com Kubernetes, Docker e Terraform para gestão de infraestrutura e orquestração de contêineres.
Experiência com práticas de FinOps para otimização de custos em ambientes de nuvem.
Conhecimento em implementar práticas de DevSecOps para segurança integrada no ciclo de vida do desenvolvimento de software.
Capacidade com linguagens de script como Python, Bash ou Perl.
Experiência com ferramentas de automação como Ansible, Puppet ou Chef.

Caro(a) [Nome do Gerente],

Segue o feedback da entrevista realizada com um dos candidatos para a posição de SRE Sênior.

Avaliação Geral:
O candidato demonstrou um entendimento sólido das competências técnicas necessárias para o cargo. As habilidades e experiências discutidas durante a entrevista estão em linha com os requisitos da posição, incluindo conhecimentos em AWS, Kubernetes, Docker, Terraform, FinOps e DevSecOps.

Aspectos Positivos:

Experiência Técnica: Experiência relevante com as tecnologias e práticas que são centrais para a função.
Abordagem de Resolução de Problemas: Apresentou uma metodologia lógica e eficaz para a resolução de problemas, alinhada com as necessidades da posição.
Alinhamento Cultural: O candidato mostrou sinais de alinhamento com a cultura da empresa, o que é positivo para a integração na equipe.
Considerações:

Enquanto o candidato parece ser forte nas áreas técnicas e de alinhamento cultural, a decisão final deverá considerar a comparação com outros candidatos que serão entrevistados.
É importante manter um processo de seleção aberto e equitativo, garantindo que todos os candidatos sejam avaliados com base em critérios consistentes.
Conclusão:
Este candidato apresentou um perfil promissor para a posição. Aguardo a conclusão das demais entrevistas para realizar uma comparação abrangente entre todos os candidatos entrevistados.

Agradeço a oportunidade de contribuir para este processo de seleção e estou à disposição para discutir este ou outros candidatos em mais detalhes.

Atenciosamente,

[Seu Nome]


Oi, time! 🚀

Acabei de criar uma página no Confluence com uma lista de comandos AWS CLI que nos ajudaram em troubleshooting recentemente. Dêem uma olhada: Comandos AWS CLI.

Se você tiver algum comando que seja um verdadeiro salva-vidas, por favor, adicione à página ou me mande para incluirmos. Vamos fazer dessa página um super recurso para todos nós! 💡

Obrigado!

###############
[11:57] Bedi, Kingshuk
  name: alb-ingress-controller

  namespace: kube-system

  resourceVersion: "2353604"

  uid: c1472236-fd84-4368-9257-c6d1a11878eb

spec:

  progressDeadlineSeconds: 600

  replicas: 1

  revisionHistoryLimit: 10

  selector:

    matchLabels:

      app.kubernetes.io/name: alb-ingress-controller

  strategy:

    rollingUpdate:

      maxSurge: 25%

      maxUnavailable: 25%

    type: RollingUpdate

  template:

    metadata:

      annotations:

        kubectl.kubernetes.io/restartedAt: "2024-02-09T14:05:42Z"

      creationTimestamp: null

      labels:

        app.kubernetes.io/name: alb-ingress-controller

    spec:

      containers:

      - args:

        - --ingress-class=alb

        - --cluster-name=ccmi_phase2_dev_eks_cluster-us-east-1-dev

        - --aws-vpc-id=vpc-0f0c91d2c6350a4c9

        - --aws-region=us-east-1

        image: 784731249099.dkr.ecr.us-east-1.amazonaws.com/ccmi-phase2-dev:alb-controller

        imagePullPolicy: IfNotPresent

        name: alb-ingress-controller

        resources: {}

        terminationMessagePath: /dev/termination-log

        terminationMessagePolicy: File

      dnsPolicy: ClusterFirst

      restartPolicy: Always

      schedulerName: default-scheduler

      securityContext: {}

      serviceAccount: alb-ingress-controller

      serviceAccountName: alb-ingress-controller
[11:58] Bedi, Kingshuk
this is my alb ingress
[11:59] Bedi, Kingshuk
but the pod is entering into crashloopback error state 
 
[11:59] Bedi, Kingshuk
with the following error 
[root@ip-10-30-175-168 ccmi]# kubectl logs alb-ingress-controller-6b55dcf4d5-4c9wv -n kube-system

{"level":"info","ts":"2024-02-09T14:54:15Z","msg":"version","GitVersion":"v2.7.0","GitCommit":"ed00c8199179b04fa2749db64e36d4a48ab170ac","BuildDate":"2024-02-01T01:05:49+0000"}

{"level":"info","ts":"2024-02-09T14:54:15Z","logger":"controller-runtime.metrics","msg":"Metrics server is starting to listen","addr":":8080"}

{"level":"info","ts":"2024-02-09T14:54:15Z","logger":"setup","msg":"adding health check for controller"}

{"level":"info","ts":"2024-02-09T14:54:15Z","logger":"setup","msg":"adding readiness check for webhook"}

{"level":"info","ts":"2024-02-09T14:54:15Z","logger":"controller-runtime.webhook","msg":"Registering webhook","path":"/mutate-v1-pod"}

{"level":"info","ts":"2024-02-09T14:54:15Z","logger":"controller-runtime.webhook","msg":"Registering webhook","path":"/mutate-v1-service"}

{"level":"info","ts":"2024-02-09T14:54:15Z","logger":"controller-runtime.webhook","msg":"Registering webhook","path":"/validate-elbv2-k8s-aws-v1beta1-ingressclassparams"}

{"level":"info","ts":"2024-02-09T14:54:15Z","logger":"controller-runtime.webhook","msg":"Registering webhook","path":"/mutate-elbv2-k8s-aws-v1beta1-targetgroupbinding"}

{"level":"info","ts":"2024-02-09T14:54:15Z","logger":"controller-runtime.webhook","msg":"Registering webhook","path":"/validate-elbv2-k8s-aws-v1beta1-targetgroupbinding"}

{"level":"info","ts":"2024-02-09T14:54:15Z","logger":"controller-runtime.webhook","msg":"Registering webhook","path":"/validate-networking-v1-ingress"}

{"level":"info","ts":"2024-02-09T14:54:15Z","logger":"setup","msg":"starting podInfo repo"}

{"level":"info","ts":"2024-02-09T14:54:17Z","logger":"controller-runtime.webhook.webhooks","msg":"Starting webhook server"}

{"level":"info","ts":"2024-02-09T14:54:17Z","msg":"Starting server","kind":"health probe","addr":"[::]:61779"}

{"level":"info","ts":"2024-02-09T14:54:17Z","msg":"Starting server","path":"/metrics","kind":"metrics","addr":"[::]:8080"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Stopping and waiting for non leader election runnables"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Stopping and waiting for leader election runnables"}

I0209 14:54:18.032643       1 leaderelection.go:248] attempting to acquire leader lease kube-system/aws-load-balancer-controller-leader...

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Starting EventSource","controller":"targetGroupBinding","controllerGroup":"elbv2.k8s.aws","controllerKind":"TargetGroupBinding","source":"kind source: *v1beta1.TargetGroupBinding"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Starting EventSource","controller":"targetGroupBinding","controllerGroup":"elbv2.k8s.aws","controllerKind":"TargetGroupBinding","source":"kind source: *v1.Service"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Starting EventSource","controller":"targetGroupBinding","controllerGroup":"elbv2.k8s.aws","controllerKind":"TargetGroupBinding","source":"kind source: *v1.Endpoints"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Starting EventSource","controller":"targetGroupBinding","controllerGroup":"elbv2.k8s.aws","controllerKind":"TargetGroupBinding","source":"kind source: *v1.Node"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Starting Controller","controller":"targetGroupBinding","controllerGroup":"elbv2.k8s.aws","controllerKind":"TargetGroupBinding"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Starting EventSource","controller":"ingress","source":"channel source: 0xc0005d6a00"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Starting EventSource","controller":"ingress","source":"channel source: 0xc0005d6a50"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Starting EventSource","controller":"ingress","source":"kind source: *v1.Ingress"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Starting EventSource","controller":"ingress","source":"kind source: *v1.Service"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Starting EventSource","controller":"ingress","source":"channel source: 0xc0005d6be0"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Starting EventSource","controller":"ingress","source":"channel source: 0xc0005d6c30"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Starting EventSource","controller":"ingress","source":"kind source: *v1beta1.IngressClassParams"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Starting EventSource","controller":"ingress","source":"kind source: *v1.IngressClass"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Starting Controller","controller":"ingress"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Starting workers","controller":"ingress","worker count":3}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Shutdown signal received, waiting for all workers to finish","controller":"ingress"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Starting EventSource","controller":"service","source":"kind source: *v1.Service"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Starting Controller","controller":"service"}

{"level":"error","ts":"2024-02-09T14:54:18Z","logger":"controller-runtime.source","msg":"failed to get informer from cache","error":"Timeout: failed waiting for *v1.Endpoints Informer to sync"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Starting workers","controller":"service","worker count":3}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Shutdown signal received, waiting for all workers to finish","controller":"service"}

{"level":"error","ts":"2024-02-09T14:54:18Z","logger":"controller-runtime.source","msg":"failed to get informer from cache","error":"Timeout: failed waiting for *v1.Node Informer to sync"}

{"level":"error","ts":"2024-02-09T14:54:18Z","msg":"Could not wait for Cache to sync","controller":"targetGroupBinding","controllerGroup":"elbv2.k8s.aws","controllerKind":"TargetGroupBinding","error":"failed to wait for targetGroupBinding caches to sync: failed to get informer from cache: Timeout: failed waiting for *v1.Endpoints Informer to sync"}

{"level":"error","ts":"2024-02-09T14:54:18Z","msg":"error received after stop sequence was engaged","error":"failed to wait for targetGroupBinding caches to sync: failed to get informer from cache: Timeout: failed waiting for *v1.Endpoints Informer to sync"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"All workers finished","controller":"service"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"All workers finished","controller":"ingress"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Stopping and waiting for caches"}

{"level":"error","ts":"2024-02-09T14:54:18Z","logger":"controller-runtime.source","msg":"failed to get informer from cache","error":"Timeout: failed waiting for *v1beta1.IngressClassParams Informer to sync"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Stopping and waiting for webhooks"}

{"level":"info","ts":"2024-02-09T14:54:18Z","msg":"Wait completed, proceeding to shutdown the manager"}

E0209 14:54:18.036193       1 leaderelection.go:330] error retrieving resource lock kube-system/aws-load-balancer-controller-leader: Get "https://172.20.0.1:443/api/v1/namespaces/kube-system/configmaps/aws-load-balancer-controller-leader": context canceled

{"level":"error","ts":"2024-02-09T14:54:18Z","logger":"setup","msg":"problem running manager","error":"open /tmp/k8s-webhook-server/serving-certs/tls.crt: no such file or directory"}
[12:01] Bedi, Kingshuk
this is my ingress  manifest
 
apiVersion: networking.k8s.io/v1

kind: Ingress

metadata:

  name: "ingress"

  namespace: "ccmiphase2dev"

  annotations:

    kubernetes.io/ingress.class: alb

    alb.ingress.kubernetes.io/scheme: internal

spec:

  rules:

  - http:

      paths:

      - pathType: Prefix

        path: "/*"

        backend:

          service:

            name: "ingress-service"

            port:

              number: 80













