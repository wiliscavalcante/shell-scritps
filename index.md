# AWS API Gateway

Currently (jan/2025), the Serasa Experian uses Apigee Edge to manage and operate our APIs. However, we recently faced some significant incidents (INC8420283 and INC10006413) and these incidents highlighted a critical architectural vulnerability of Apigee, which acts as a single point of failure. As a result, these issues negatively impacted the service level and availability of all the company's APIs, compromising the continuity of our services.

In addition to the technical problems, the response from the technical support team provided by Google was considered unsatisfactory and inadequate to resolve the issues presented efficiently and promptly. This scenario led us to reconsider our API management strategy and seek more robust and reliable alternatives.

Given this situation, we conducted a feasibility study for adopting a second option for an API Gateway. This study took into account several factors, including the costs involved, existing partnerships, current contracts, as well as market benchmarks and the company's internal expertise. After an extensive analysis, the gateway evaluated and considered as a potential alternative was the AWS API Gateway, which aligned with the company's needs and expectations.

In line with the project executed by the global team, part of the solution was used and automations were adjusted to meet local particularities. The adjustments made are:
- Decentralized authentication workload, preventing spoofing;
- Adjustment for integration with the local authenticator (AUTH-ME);
- Integration with the local CI/CD pipeline.

[PRM AWS API Gateway x Apigee](https://pages.experian.local/x/QgYwQw)

## Tech Docs
Amazon API Gateway helps developers to create and manage APIs to back-end systems running on Amazon EC2, AWS Lambda, or any publicly addressable web service. With Amazon API Gateway, you can generate custom client SDKs for your APIs, to connect your back-end systems to mobile, web, and server applications or services.

>❗IMPORTANT❗: Your API will be published to the Internet, so it must be compliant with the [Experian Data Classification, Ownership and Handling Standard](https://experian.sharepoint.com/sites/GBLPolicies/_layouts/15/search.aspx/sitefiles?q=%22Data%20Classification%20Ownership%20and%20Handling%20Standard%20(Global)%22&amp;refiners=%7B%22FileType%22%3A%5B%22pdf%22%5D%7D).

### Table of Contents
1. [Set up the infrastructure for EEC](#set-up-the-infrastructure-for-eec)
2. [Create the API Gateway definition file](#create-the-api-gateway-definition-file)
3. [Configure PiaaS for deployment of API Gateway](#configure-piaas-for-deployment-of-api-gateway)


### Set up the infrastructure for EEC

##### Amazon API Gateway requires 4 major infrastructure configuration:
>❗PRE REQS❗:  
>1. Your microservice route must be created in your cluster's Istio (Gateway/Virtual Service).</br>
>2. The BURoleForDevSecOpsCockpitService role must have permission to the lambda.amazonaws.com service.</br>
>3. The BURoleForLambdaExecution role must be created and configured with the following permissions AWSLambdaVPCAccessExecutionPermissions and EC2NetworkInterfacePermissions.</br>
>4. The BURoleForApiGatewayCloudwatch role must be created and configured with permission to execute the apigateway.amazonaws.com service.


**Custom Domain Name:** A domain name is needed to E-Connect forward the requests to your API Gateway and to your API using the basePath feature. Configure it launching the *"aws-apigw-custom-domain"* automation in the [DevSecOps Cockpit](https://cockpit-container-front-prod.devsecops-paas-prd.br.experian.eeca)Configure, in this automation you need to register the exact entry of the external domain that will serve the AWS API Gateway. (Ex.: uat-idf.serasaexperian.com.br)

>❗IMPORTANT❗: You must have a valid certificate imported into ACM from your cloud account. </br> 
>If your external domain is a new domain:</br>
>1. Register with CSSv3 to receive this entry and redirect it to your cluster through the Host header. [REQ3576397](https://experian.service-now.com/now/nav/ui/classic/params/target/sc_req_item.do%3Fsys_id%3Da69ac78c83b516585329ee50ceaad3bd%26sysparm_stack%3D%26sysparm_view%3D).</br>
>2. Register the entry in the WAF pointing to CSSv3 [REQ3556072](https://experian.service-now.com/now/nav/ui/classic/params/target/sc_req_item.do%3Fsys_id%3D48edac84c361d2905227dc1e050131dc%26sysparm_stack%3D%26sysparm_view%3D).</br>
>3. You must follow the DNS registration process [REQ3567767](https://experian.service-now.com/now/nav/ui/classic/params/target/sc_req_item.do%3Fsys_id%3D850e5d1683e59694d8bf82c8beaad398%26sysparm_stack%3D%26sysparm_view%3D).


**Request Authorizer:** When a client makes a request your API's method, API Gateway calls the authorizer that takes the caller's identity as the input and returns an IAM policy as the output. This is mandatory if your API uses Brazil IAM as your OAuth2 provider. Configure it launching the *"aws-apigw-authorizer"* automation in the [DevSecOps Cockpit](https://cockpit-container-front-prod.devsecops-paas-prd.br.experian.eeca).

>❗IMPORTANT❗: Your cloud account must have connectivity to the Auth-Me cloud account (Digital Account). ([REQ3779372](https://experian.service-now.com/now/nav/ui/classic/params/target/sc_request.do%3Fsys_id%3D7d306a1c9390621c062b32c5fbba107c%26sysparm_stack%3D%26sysparm_view%3D))


**VPC Endpoint:** Since the Experian Express Cloud (EEC) provides only a private VPC, we need to create a VPC Endpoint Interface that will spin-up an ENI for each subnet, with a private IP address, that E-Connect will use to forward the requests to. Configure it by opening a [CHG2552458](https://experian.service-now.com/now/nav/ui/classic/params/target/change_request.do%3Fsys_id%3Def80595c47c86a94e29d8155516d432c%26sysparm_stack%3D%26sysparm_view%3D) for the cloud team to create the VPC Endpoint

**VPC Link:** As stated before, all services in EEC uses a private VPC and to connect AWS API Gateway with your backend, probably running in EKS, you will need to create a VPC Link between the Gateway and the Network Load Balancer of your EKS Cluster. Configure it launching the *"aws-apigw-vpc-link"* automation in the [DevSecOps Cockpit](https://cockpit-container-front-prod.devsecops-paas-prd.br.experian.eeca). The nlb_arn field must be populated with the cluster load balancer arn.


### Create the API Gateway definition file

Currently, AWS API Gateway supports [OpenAPI v2.0](https://swagger.io/specification/v2/) and [OpenAPI v3.0](https://spec.openapis.org/oas/v3.1.1.html) definition files, with exceptions listed in [Amazon API Gateway important notes for REST APIs](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-known-issues.html#api-gateway-known-issues-rest-apis).

The first thing you need to do is to copy your API specification file, aka swagger, to the "/api" directory in the root of your application and rename it to "apigw.yaml".

![](img/api_dir.png)

After that you need to remove [unsupported features](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-known-issues.html#api-gateway-known-issues-rest-apis) like default response and include the AWS API Gateway extensions. Above you can see examples of spec for OAS 2 and OAS 3.

> ℹ️ To understand how AWS API Gateway extensions are used in an application, see: [OpenAPI extensions for API Gateway](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-swagger-extensions.html).

#### OpenAPI v2.0 Specification
<details>
<summary>Click to see more...</h2></summary>

```yaml
swagger: "2.0"
info:
  title: DT-OTP-BR
  description: One-time password
  version: 1.0.0
  contact:
    name: Experian API team
    email: suporte-api-digital@br.experian.com
host: otp.sandbox-arch.br.experian.eeca
basePath: /security/otp/v1
schemes:
  - https
consumes:
  - application/json
produces:
  - application/json
paths:
  /token:
    post:
      tags:
        - Token
      summary: Create Token
      description: Create a token for an user. To access this method the client (application)
        must have "CLI-AUTH-IDENTIFIED" authentication and "CLI-1STPARTY" role
      operationId: generateToken
      security:
        - Brazil-IAMSecurity: []
      parameters:
      - name: "Authorization"
        in: "header"
        required: true
        type: "string"
      - in: "body"
        name: "TokenRequest"
        description: Token creation info. All data must be informed.
        required: true
        schema:
          $ref: "#/definitions/TokenRequest"
      responses:
        201:
          description: Token created
          schema:
            $ref: "#/definitions/TokenResponse"
          headers:
            Access-Control-Allow-Origin:
              type: "string"
        401:
          description: Authorization Failed
          headers:
            Access-Control-Allow-Origin:
              type: "string"
        500:
          description: Internal Server Error
          schema:
            $ref: "#/definitions/ErrorModel"
          headers:
            Access-Control-Allow-Origin:
              type: "string"
      x-amazon-apigateway-integration:
        type: "http"
        httpMethod: "POST"
        uri: "https://${stageVariables.endpoint_url}/token"
        connectionId: "${stageVariables.connectionId}"
        connectionType: "VPC_LINK"
        passthroughBehavior: "when_no_templates"
        requestParameters:
          integration.request.header.Authorization: "method.request.header.Authorization"
        responses:
          "201":
            statusCode: "201"
            responseParameters:
              method.response.header.Access-Control-Allow-Origin: "'*'"
          "500":
            statusCode: "500"
            responseParameters:
              method.response.header.Access-Control-Allow-Origin: "'*'"
          "401":
            statusCode: "401"
            responseParameters:
              method.response.header.Access-Control-Allow-Origin: "'*'"
        tlsConfig:
          insecureSkipVerification: true
      x-amazon-apigateway-request-validator: "basic"
    options:
      tags:
        - CORS
      responses:
        "200":
          description: Success
          headers:
            Access-Control-Allow-Origin:
              type: "string"
            Access-Control-Allow-Methods:
              type: "string"
            Access-Control-Allow-Headers:
              type: "string"
      x-amazon-apigateway-integration:
        responses:
          default:
            statusCode: "200"
            responseParameters:
              method.response.header.Access-Control-Allow-Methods: "'GET, PUT, POST, DELETE, PATCH, OPTIONS'"
              method.response.header.Access-Control-Allow-Headers: "'Authorization, Content-Type'"
              method.response.header.Access-Control-Allow-Origin: "'*'"
        requestTemplates:
          application/json: "{\"statusCode\": 200}"
        passthroughBehavior: "when_no_match"
        type: "mock"
  /validate-token:
    post:
      tags:
        - Token
      summary: Validate Token
      description: Validate a token for an user. To access this method the client
        (application) must have "CLI-AUTH-IDENTIFIED" authentication and "CLI-1STPARTY" role
      operationId: validateToken
      security:
        - Brazil-IAMSecurity: []
      parameters:
      - name: "Authorization"
        in: "header"
        required: true
        type: "string"
      - in: "body"
        name: "TokenValidate"
        description: Token validation info. All data must be informed.
        required: true
        schema:
          $ref: "#/definitions/TokenValidate"
      responses:
        200:
          description: Token is valid
          headers:
            Access-Control-Allow-Origin:
              type: "string"
        401:
          description: Authorization Failed
          headers:
            Access-Control-Allow-Origin:
              type: "string"
        404:
          description: Token not found
          headers:
            Access-Control-Allow-Origin:
              type: "string"
        500:
          description: Internal Server Error
          schema:
            $ref: "#/definitions/ErrorModel"
          headers:
            Access-Control-Allow-Origin:
              type: "string"
      x-amazon-apigateway-integration:
        type: "http"
        httpMethod: "POST"
        uri: "https://${stageVariables.endpoint_url}/validate-token"
        connectionId: "${stageVariables.connectionId}"
        connectionType: "VPC_LINK"
        passthroughBehavior: "when_no_templates"
        requestParameters:
          integration.request.header.Authorization: "method.request.header.Authorization"
        responses:
          "200":
            statusCode: "200"
            responseParameters:
              method.response.header.Access-Control-Allow-Origin: "'*'"
          "500":
            statusCode: "500"
            responseParameters:
              method.response.header.Access-Control-Allow-Origin: "'*'"
          "401":
            statusCode: "401"
            responseParameters:
              method.response.header.Access-Control-Allow-Origin: "'*'"
          "404":
            statusCode: "404"
            responseParameters:
              method.response.header.Access-Control-Allow-Origin: "'*'"
        tlsConfig:
          insecureSkipVerification: true
      x-amazon-apigateway-request-validator: "basic"
    options:
      tags:
        - CORS
      responses:
        "200":
          description: Success
          headers:
            Access-Control-Allow-Origin:
              type: "string"
            Access-Control-Allow-Methods:
              type: "string"
            Access-Control-Allow-Headers:
              type: "string"
      x-amazon-apigateway-integration:
        responses:
          default:
            statusCode: "200"
            responseParameters:
              method.response.header.Access-Control-Allow-Methods: "'GET, PUT, POST, DELETE, PATCH, OPTIONS'"
              method.response.header.Access-Control-Allow-Headers: "'Authorization, Content-Type'"
              method.response.header.Access-Control-Allow-Origin: "'*'"
        requestTemplates:
          application/json: "{\"statusCode\": 200}"
        passthroughBehavior: "when_no_match"
        type: "mock"
securityDefinitions:
  Brazil-IAMSecurity:
    type: "apiKey"
    name: "Authorization"
    in: "header"
    x-amazon-apigateway-authtype: "custom"
    x-amazon-apigateway-authorizer:
      authorizerUri: "arn:aws:apigateway:sa-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:sa-east-1:623955547361:function:APIGW-IAMSecurity-Authorizer/invocations"
      authorizerResultTtlInSeconds: 900
      identitySource: "method.request.header.Authorization"
      type: "request"
definitions:
  TokenRequest:
    required:
      - userId
    type: object
    properties:
      userId:
        type: string
      expirationPlusMinutes:
        type: integer
        format: "int32"
        description: Value in minutes to increase expiration time. The default expiration
          time is 10 minutes from the date of the request.
  TokenResponse:
    type: object
    properties:
      token:
        type: string
  TokenValidate:
    required:
      - token
      - userId
    type: object
    properties:
      userId:
        type: string
      token:
        type: string
  ErrorModel:
    required:
      - code
      - message
    type: object
    properties:
      code:
        type: string
      message:
        type: string

x-amazon-apigateway-endpoint-configuration:
  disableExecuteApiEndpoint: true

x-amazon-apigateway-request-validators:
  basic:
    validateRequestBody: true
    validateRequestParameters: true

x-amazon-apigateway-gateway-responses:
  UNAUTHORIZED:
    statusCode: 401
    responseTemplates:
      application/json: "{\"code\": \"401\", \"message\":$context.error.messageString}"

x-amazon-apigateway-policy:
  Version: "2012-10-17"
  Statement:
    - Effect: "Allow"
      Principal: "*"
      Action: "execute-api:Invoke"
      Resource: "execute-api:/*"
    - Effect: "Deny"
      Principal: "*"
      Action: "execute-api:Invoke"
      Resource: "execute-api:/*"
      Condition:
        StringNotEquals:
          aws:SourceVpce: "vpce-05b804da86e894337"
```

</details>

#### OpenAPI v3.0 Specification
<details>
<summary>Click to see more...</h2></summary>

```yaml
openapi: 3.0.1
info:
  title: DT-OTP-BR
  description: One-time password
  version: 1.0.0
  contact:
    name: Experian API team
    email: suporte-api-digital@br.experian.com
servers:
  - url: https://otp.sandbox-arch.br.experian.eeca/security/otp/v1
    x-amazon-apigateway-endpoint-configuration:
      disableExecuteApiEndpoint: true
paths:
  /token:
    post:
      tags:
        - Token
      summary: Create Token
      description: Create a token for an user. To access this method the client (application)
        must have "CLI-AUTH-IDENTIFIED" authentication and "CLI-1STPARTY" role
      operationId: generateToken
      security:
        - Brazil-IAMSecurity: []
      parameters:
        - name: "Authorization"
          in: "header"
          required: true
          schema:
            type: "string"
      requestBody:
        description: Token creation info. All data must be informed.
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/TokenRequest'
        required: true
      responses:
        201:
          description: Token created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/TokenResponse'
          headers:
            Access-Control-Allow-Origin:
              schema:
                type: "string"
        401:
          description: Authorization Failed
          headers:
            Access-Control-Allow-Origin:
              schema:
                type: "string"
        500:
          description: Internal Server Error
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorModel'
          headers:
            Access-Control-Allow-Origin:
              schema:
                type: "string"
      x-amazon-apigateway-integration:
        type: http
        httpMethod: POST
        uri: "https://${stageVariables.endpoint_url}/token"
        connectionId: "${stageVariables.connectionId}"
        connectionType: VPC_LINK
        passthroughBehavior: when_no_templates
        requestParameters:
          integration.request.header.Authorization: "method.request.header.Authorization"
        responses:
          "201":
            statusCode: "201"
            responseParameters:
              method.response.header.Access-Control-Allow-Origin: "'*'"
          "401":
            statusCode: "401"
            responseParameters:
              method.response.header.Access-Control-Allow-Origin: "'*'"
          "500":
            statusCode: "500"
            responseParameters:
              method.response.header.Access-Control-Allow-Origin: "'*'"
        tlsConfig:
          insecureSkipVerification: true
      x-amazon-apigateway-request-validator: basic
    options:
      tags:
        - CORS
      responses:
        "200":
          description: Success
          headers:
            Access-Control-Allow-Origin:
              schema:
                type: "string"
            Access-Control-Allow-Methods:
              schema:
                type: "string"
            Access-Control-Allow-Headers:
              schema:
                type: "string"
      x-amazon-apigateway-integration:
        responses:
          default:
            statusCode: "200"
            responseParameters:
              method.response.header.Access-Control-Allow-Methods: "'GET, PUT, POST, DELETE, PATCH, OPTIONS'"
              method.response.header.Access-Control-Allow-Headers: "'Authorization, Content-Type'"
              method.response.header.Access-Control-Allow-Origin: "'*'"
        requestTemplates:
          application/json: "{\"statusCode\": 200}"
        passthroughBehavior: "when_no_match"
        type: "mock"
  /validate-token:
    post:
      tags:
        - Token
      summary: Validate Token
      description: Validate a token for an user. To access this method the client
        (application) must have "CLI-AUTH-IDENTIFIED" authentication and "CLI-1STPARTY" role
      operationId: validateToken
      security:
        - Brazil-IAMSecurity: []
      parameters:
        - name: "Authorization"
          in: "header"
          required: true
          schema:
            type: "string"
      requestBody:
        description: Token validation info. All data must be informed.
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/TokenValidate'
        required: true
      responses:
        200:
          description: Token is valid
          headers:
            Access-Control-Allow-Origin:
              schema:
                type: "string"
        401:
          description: Authorization Failed
          headers:
            Access-Control-Allow-Origin:
              schema:
                type: "string"
        404:
          description: Token not found
          headers:
            Access-Control-Allow-Origin:
              schema:
                type: "string"
        500:
          description: Internal Server Error
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorModel'
          headers:
            Access-Control-Allow-Origin:
              schema:
                type: "string"
      x-amazon-apigateway-integration:
        type: http
        httpMethod: POST
        uri: "https://${stageVariables.endpoint_url}/validate-token"
        connectionId: "${stageVariables.connectionId}"
        connectionType: VPC_LINK
        passthroughBehavior: when_no_templates
        requestParameters:
          integration.request.header.Authorization: "method.request.header.Authorization"
        responses:
          "200":
            statusCode: "200"
            responseParameters:
              method.response.header.Access-Control-Allow-Origin: "'*'"
          "401":
            statusCode: "401"
            responseParameters:
              method.response.header.Access-Control-Allow-Origin: "'*'"
          "404":
            statusCode: "404"
            responseParameters:
              method.response.header.Access-Control-Allow-Origin: "'*'"
          "500":
            statusCode: "500"
            responseParameters:
              method.response.header.Access-Control-Allow-Origin: "'*'"
        tlsConfig:
          insecureSkipVerification: true
      x-amazon-apigateway-request-validator: basic
    options:
      tags:
        - CORS
      responses:
        "200":
          description: Success
          headers:
            Access-Control-Allow-Origin:
              schema:
                type: "string"
            Access-Control-Allow-Methods:
              schema:
                type: "string"
            Access-Control-Allow-Headers:
              schema:
                type: "string"
      x-amazon-apigateway-integration:
        responses:
          default:
            statusCode: "200"
            responseParameters:
              method.response.header.Access-Control-Allow-Methods: "'GET, PUT, POST, DELETE, PATCH, OPTIONS'"
              method.response.header.Access-Control-Allow-Headers: "'Authorization, Content-Type'"
              method.response.header.Access-Control-Allow-Origin: "'*'"
        requestTemplates:
          application/json: "{\"statusCode\": 200}"
        passthroughBehavior: "when_no_match"
        type: "mock"
components:
  securitySchemes:
    Brazil-IAMSecurity:
      type: "apiKey"
      name: "Authorization"
      in: "header"
      x-amazon-apigateway-authtype: "custom"
      x-amazon-apigateway-authorizer:
        authorizerUri: "arn:aws:apigateway:sa-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:sa-east-1:623955547361:function:APIGW-IAMSecurity-Authorizer/invocations"
        authorizerResultTtlInSeconds: 900
        identitySource: "method.request.header.Authorization"
        type: "request"
  schemas:
    TokenRequest:
      required:
        - userId
      type: object
      properties:
        userId:
          type: string
        expirationPlusMinutes:
          type: integer
          format: "int32"
          description: Value in minutes to increase expiration time. The default expiration
            time is 10 minutes from the date of the request.
    TokenResponse:
      type: object
      properties:
        token:
          type: string
    TokenValidate:
      required:
        - token
        - userId
      type: object
      properties:
        userId:
          type: string
        token:
          type: string
    ErrorModel:
      required:
        - code
        - message
      type: object
      properties:
        code:
          type: string
        message:
          type: string

x-amazon-apigateway-request-validators:
  basic:
    validateRequestBody: true
    validateRequestParameters: true

x-amazon-apigateway-gateway-responses:
  UNAUTHORIZED:
    statusCode: 401
    responseTemplates:
      application/json: "{\"code\": \"401\", \"message\":$context.error.messageString}"

x-amazon-apigateway-policy:
  Version: "2012-10-17"
  Statement:
    - Effect: "Allow"
      Principal: "*"
      Action: "execute-api:Invoke"
      Resource: "execute-api:/*"
    - Effect: "Deny"
      Principal: "*"
      Action: "execute-api:Invoke"
      Resource: "execute-api:/*"
      Condition:
        StringNotEquals:
          aws:SourceVpce: "vpce-05b804da86e894337"
```

</details>


### Configure PiaaS for deployment of API Gateway
Only [PiaaS 2.0](https://pages.experian.local/display/EDPB/O+que+temos+de+novo) supports deployment of APIs in AWS API Gateway, and to use it you will need to update the [piaas.yml](https://pages.experian.local/pages/viewpage.action?pageId=1396796905) of your application and include the '*apigateway*' step in the '*after_deploy*' stage of QA and MASTER branches.

> ⚠️ The AWS API Gateway deployment in PiaaS requires the application to have Kubernetes Helm artifacts and an OAS file (*swagger.yaml* or *openapi.yaml*) in the path src/main/resources. This is required to determine the backend URL when not provided in the *piaas.yml*.

```yaml
version: 6.0.0
application:
  name: experian-otp-domain-services
  type: rest
  gearr: 11097
  language:
    name: Java-17
  jira_key: DIRMAI
  framework: Spring
  product: Digital OTP Services
  gearr_dependencies: 17416
  cmdb_dependencies: spobrjenkins:8080,spobrsonar1-uat:9000
team:
  tribe: Digital Pass
  squad: Identity and Access Management
  assignment_group: Brazil Digital PaaS
  business_service: Other Software Solutions
branches:
  qa:
    before_build:
      sonarqube:
    build:
      mvn: clean package -Dmaven.test.skip=true
      docker:
    after_build:
      veracode: --veracode-id=0000000 --extensao=jar
      helm: --url-charts-repo=s3://eec-aws-xxxxxxxxxxxx-uat-charts --safe=USCLD_PAWS_000000000000 --iamUser=BUUserForDevSecOpsPiaaS --awsAccount=000000000000 --aws-region=sa-east-1
    deploy:
      eks: --cluster-name=bu-eks-01-uat --project=namespace --safe=USCLD_PAWS_000000000000 --iamUser=BUUserForDevSecOpsPiaaS --awsAccount=000000000000 --aws-region=sa-east-1
    after_deploy:
      apigateway: --rate-limit=120 --burst-limit=60 --domain-name=otp.bu-uat.br.experian.eeca --aws-vpc-link=000abc --aws-account=000000000000 --aws-region=sa-east-1
```

### Project Example

[Example](https://code.experian.local/projects/AB/repos/experian-otp-services/browse)

### Adding the API Gateway to a new project Java Archetype via Onboarding-Apollo11

To add the `apigw` submodule configurations to a new project, follow these steps:
1. Go to the DevSecOps Cockpit.
2. Navigate to PiaaS and click the "Onboarding Application" button.
3. Select "JAVA" as the application language.
4. In the "Application Modules" section, select the `apigw` option.
5. Fill in the other necessary fields and execute the onboarding process.

### Adding the API Gateway to an existing project Java Archetype via Onboarding-Apollo11

To add the `apigw` submodule configurations to an existing project, follow these steps:
1. Go to the DevSecOps Cockpit.
2. Navigate to the service catalog and search for Apollo11. Click on "More" to view all the automations.
3. Run the `Add-archtype-apollo11` automation.
4. Select "JAVA" as the application language.
5. In the "Application Modules" section, select the `apigw` option.
6. Fill in the other necessary fields and execute the onboarding process.

After completing these steps, the project will be created with a folder named API, and inside it, you will find the `apigw.yaml` file with the pre-configurations.

### Apigw.yaml Configuration 

The apigw.yaml file is an OpenAPI 3.0.1 specification file used to define the API Gateway configuration. Below is an explanation of the key sections and configurations:

**Info Section**
```
info:
  title: ${API_TITLE}
  description: ${API_DESCRIPTION}
  contact:
    name: ${API_TEAM_NAME}
    email: ${API_TEAM_EMAIL}
  version: ${API_VERSION}
```
This section provides metadata about the API, including the title, description, contact information, and version.

**Servers Section**
```
servers:
  - url: ${API_URL}
    x-amazon-apigateway-endpoint-configuration:
      disableExecuteApiEndpoint: true
```
Defines the server URL and disables the default execute API endpoint.

**Paths Section**

Defines the API endpoints and their operations. For example, the /resource endpoint:
```
paths:
  /resource:
    post:
      tags:
        - Resource
      summary: Create Resource
      description: Create a resource for a user. To access this method, the client (application) must have "CLI-AUTH-IDENTIFIED" authentication and "CLI-1STPARTY" role.
      operationId: createResource
      security:
        - Brazil-IAMSecurity: []
      parameters:
        - name: "Authorization"
          in: "header"
          required: true
          schema:
            type: "string"
      requestBody:
        description: Resource creation info. All data must be informed.
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ResourceRequest'
        required: true
      responses:
        201:
          description: Resource created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ResourceResponse'
          headers:
            Access-Control-Allow-Origin:
              schema:
                type: "string"
        401:
          description: Authorization Failed
          headers:
            Access-Control-Allow-Origin:
              schema:
                type: "string"
        500:
          description: Internal Server Error
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorModel'
          headers:
            Access-Control-Allow-Origin:
              schema:
                type: "string"
      x-amazon-apigateway-integration:
        type: http
        httpMethod: POST
        uri: "https://${STAGE_VARIABLES_ENDPOINT_URL}/resource"
        connectionId: "${STAGE_VARIABLES_CONNECTION_ID}"
        connectionType: VPC_LINK
        passthroughBehavior: when_no_templates
        requestParameters:
          integration.request.header.Authorization: "method.request.header.Authorization"
        responses:
          "201":
            statusCode: "201"
            responseParameters:
              method.response.header.Access-Control-Allow-Origin: "'*'"
          "401":
            statusCode: "401"
            responseParameters:
              method.response.header.Access-Control-Allow-Origin: "'*'"
          "500":
            statusCode: "500"
            responseParameters:
              method.response.header.Access-Control-Allow-Origin: "'*'"
        tlsConfig:
          insecureSkipVerification: true
      x-amazon-apigateway-request-validator: basic
```
This section defines the /resource endpoint with a POST method, including request parameters, request body, responses, and integration with AWS services. It is also possible to define multiple endpoints in the same configuration file.

**Components Section**

Defines reusable components such as security schemes and schemas:
```
components:
  securitySchemes:
    Brazil-IAMSecurity:
      type: "apiKey"
      name: "Authorization"
      in: "header"
      x-amazon-apigateway-authtype: "custom"
      x-amazon-apigateway-authorizer:
        authorizerUri: "arn:aws:apigateway:sa-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:sa-east-1:623955547361:function:APIGW-IAMSecurity-Authorizer/invocations"
        authorizerResultTtlInSeconds: 900
        identitySource: "method.request.header.Authorization"
        type: "request"
  schemas:
    ResourceRequest:
      required:
        - userId
      type: object
      properties:
        userId:
          type: string
        expirationPlusMinutes:
          type: integer
          description: Value in minutes to increase expiration time. The default expiration time is 10 minutes from the date of the request.
    ResourceResponse:
      type: object
      properties:
        resource:
          type: string
    ErrorModel:
      required:
        - code
        - message
      type: object
      properties:
        code:
          type: string
        message:
          type: string
```
This section includes security schemes for authentication and schemas for request and response bodies.

**Request Validators and Gateway Responses**

Defines request validators and custom gateway responses:
```
x-amazon-apigateway-request-validators:
  basic:
    validateRequestBody: true
    validateRequestParameters: true

x-amazon-apigateway-gateway-responses:
  UNAUTHORIZED:
    statusCode: 401
    responseTemplates:
      application/json: "{\"code\": \"401\", \"message\":$context.error.messageString}"
```
This section configures request validation and custom responses for unauthorized access.

**Policy Section**

Defines the API Gateway policy:
```
x-amazon-apigateway-policy:
  Version: "2012-10-17"
  Statement:
    - Effect: "Allow"
      Principal: "*"
      Action: "execute-api:Invoke"
      Resource: "execute-api:/*"
    - Effect: "Deny"
      Principal: "*"
      Action: "execute-api:Invoke"
      Resource: "execute-api:/*"
      Condition:
        StringNotEquals:
          aws:SourceVpce: "vpce-05b804da86e894337"
```
This section specifies the IAM policy for the API Gateway, allowing and denying access based on conditions.
