# Do you still use version in Docker compose?
# https://dev.to/ajeetraina/do-we-still-use-version-in-compose-3inp#:~:text=While%20the%20version%20property%20might,date%20with%20the%20latest%20features.
# Version: "3.9"
services:

    # Database.
    mongo:
        image: mongo:latest
        container_name: mongo-container
        hostname: mongo-host
        environment:
            - MONGO_INITDB_ROOT_USERNAME=${MONGO_INITDB_ROOT_USERNAME}
            - MONGO_INITDB_ROOT_PASSWORD=${MONGO_INITDB_ROOT_PASSWORD}
        ports:
            - "${MONGO_PORT}:27017"

    # Database user interface.
    mongo-express:
        image: mongo-express:latest
        container_name: mongo-express-container
        hostname: mongo-express-host
        environment:
            - ME_CONFIG_MONGODB_ADMINUSERNAME=${ME_CONFIG_MONGODB_ADMINUSERNAME}
            - ME_CONFIG_MONGODB_ADMINPASSWORD=${ME_CONFIG_MONGODB_ADMINPASSWORD}
            - ME_CONFIG_MONGODB_URL=${ME_CONFIG_MONGODB_URL}
            - ME_CONFIG_BASICAUTH=0
        ports:
            - "${MONGO_EXPRESS_PORT}:8081"
        depends_on:
            - mongo

    # Broker.
    rabbitmq:
        image: rabbitmq:3-management-alpine
        container_name: rabbitmq-container
        hostname: rabbitmq-host
        ports:
            - "${RABBITMQ_PORT_UI}:15672" # Management user interface.
            - "${RABBITMQ_PORT}:5672"     # Messaging port.

    # Agrilearn API.
    api:
        image: agrilearn/agrilearn_api_image
        build:
            context: .
            dockerfile: dockerfiles/Dockerfile.dev.api
            args:
                - NEXUS_URL=${NEXUS_URL}
                - NEXUS_PYPI=${NEXUS_PYPI}
                - no_proxy=${no_proxy}
        volumes:
            - ./.env:${AGRILEARN_ENV_PATH}
            - .:/agrilearn_app/bredao
        command: "make run-api"
        environment:
            - NEXUS_URL=${NEXUS_URL}
            - NEXUS_PYPI=${NEXUS_PYPI}
            - no_proxy=${no_proxy}
            - API_ROOT_USERNAME=${API_ROOT_USERNAME}
            - API_ROOT_PASSWORD=${API_ROOT_PASSWORD}
            - MONGO_HOST=${MONGO_HOST}
            - MONGO_PORT=${MONGO_PORT}
            - MONGO_INITDB_ROOT_USERNAME=${MONGO_INITDB_ROOT_USERNAME}
            - MONGO_INITDB_ROOT_PASSWORD=${MONGO_INITDB_ROOT_PASSWORD}
            - RABBITMQ_USER=${RABBITMQ_USER}
            - RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD}
            - RABBITMQ_HOST=${RABBITMQ_HOST}
        ports:
            - "${AGRILEARN_API_PORT}:80"
        depends_on:
            - rabbitmq

    # Agrilearn web streamlite interface.
    web:
        build:
          context: .
          dockerfile: dockerfiles/Dockerfile.dev.web
          args:
            - NEXUS_URL=${NEXUS_URL}
            - NEXUS_PYPI=${NEXUS_PYPI}
            - no_proxy=${no_proxy}
        volumes:
            - ./.env:${AGRILEARN_ENV_PATH}
            - .:/agrilearn_app/bredao
        command: "make run-streamlit"
        environment:
            - NEXUS_URL=${NEXUS_URL}
            - NEXUS_PYPI=${NEXUS_PYPI}
            - no_proxy=${no_proxy}
        ports:
            - "${WEB_PORT}:8501"
        depends_on:
            - api

    # Common dependencies used in agrilearn packages.
    commons:
        image: agrilearn/agrilearn_commons_image
        build:
            context: .
            dockerfile: dockerfiles/Dockerfile.dev.commons
            args:
                - NEXUS_URL=${NEXUS_URL}
                - NEXUS_PYPI=${NEXUS_PYPI}
                - no_proxy=${no_proxy}

    # Get sattelite images.
    # No container_name parameter: Docker requires each container to have a unique name. Remove the custom name to scale the service.
    # No hostname parameter: for distinguishing workers by different hostnames.
    downloader:
        build:
            context: .
            dockerfile: dockerfiles/Dockerfile.dev.module
            args:
                - MODULE_NAME=download
                - NEXUS_URL=${NEXUS_URL}
                - NEXUS_PYPI=${NEXUS_PYPI}
                - no_proxy=${no_proxy}
        volumes:
            - ./.env:${AGRILEARN_ENV_PATH}
            - .:/agrilearn_app/bredao
            - ./submodules/commons:/agrilearn_app/submodules/commons
        command: "make run-downloader-worker"
        environment:
            - MODULE_NAME=download
            - MONGO_HOST=${MONGO_HOST}
            - MONGO_PORT=${MONGO_PORT}
            - MONGO_INITDB_ROOT_USERNAME=${MONGO_INITDB_ROOT_USERNAME}
            - MONGO_INITDB_ROOT_PASSWORD=${MONGO_INITDB_ROOT_PASSWORD}
            - RABBITMQ_USER=${RABBITMQ_USER}
            - RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD}
            - RABBITMQ_HOST=${RABBITMQ_HOST}
        deploy:
            mode: replicated
            replicas: ${N_REPLICAS_DOWNLOAD}
        depends_on:
            commons:
                condition: service_completed_successfully

    # Agrilearn emergence.
    # No container_name parameter: Docker requires each container to have a unique name. Remove the custom name to scale the service.
    # No hostname parameter: for distinguishing workers by different hostnames.
    emergence:
        build:
            context: .
            dockerfile: dockerfiles/Dockerfile.dev.module
            args:
                - MODULE_NAME=emergence
                - BUILD_TIME_SERIES=True
                - NEXUS_URL=${NEXUS_URL}
                - NEXUS_PYPI=${NEXUS_PYPI}
                - no_proxy=${no_proxy}
        volumes:
            - ./.env:${AGRILEARN_ENV_PATH}
            - .:/agrilearn_app/bredao
            - ./submodules/commons:/agrilearn_app/submodules/commons

        environment:
            - MONGO_HOST=${MONGO_HOST}
            - MONGO_PORT=${MONGO_PORT}
            - MONGO_INITDB_ROOT_USERNAME=${MONGO_INITDB_ROOT_USERNAME}
            - MONGO_INITDB_ROOT_PASSWORD=${MONGO_INITDB_ROOT_PASSWORD}
            - RABBITMQ_USER=${RABBITMQ_USER}
            - RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD}
            - RABBITMQ_HOST=${RABBITMQ_HOST}
        command: "make run-model-worker"
        deploy:
            mode: replicated
            replicas: ${N_REPLICAS_EMERGENCE}
        depends_on:
            commons:
                condition: service_completed_successfully

    # Agrilearn crop classification (RNN).
    # No container_name parameter: Docker requires each container to have a unique name. Remove the custom name to scale the service.
    # No hostname parameter: for distinguishing workers by different hostnames.
    crop_rnn:
        build:
            context: .
            dockerfile: dockerfiles/Dockerfile.dev.module
            args:
                - MODULE_NAME=crop_rnn
                - BUILD_CROP_RNN=True
                - NEXUS_URL=${NEXUS_URL}
                - NEXUS_PYPI=${NEXUS_PYPI}
                - no_proxy=${no_proxy}
        volumes:
            - ./.env:${AGRILEARN_ENV_PATH}
            - .:/agrilearn_app/bredao
            - ./submodules/commons:/agrilearn_app/submodules/commons
        environment:
            - MONGO_HOST=${MONGO_HOST}
            - MONGO_PORT=${MONGO_PORT}
            - MONGO_INITDB_ROOT_USERNAME=${MONGO_INITDB_ROOT_USERNAME}
            - MONGO_INITDB_ROOT_PASSWORD=${MONGO_INITDB_ROOT_PASSWORD}
            - RABBITMQ_USER=${RABBITMQ_USER}
            - RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD}
            - RABBITMQ_HOST=${RABBITMQ_HOST}
        command: "make run-model-worker"
        deploy:
            mode: replicated
            replicas: ${N_REPLICAS_CROP_RNN}
        depends_on:
            commons:
                condition: service_completed_successfully

    # Agrilearn senescence detection.
    # No container_name parameter: Docker requires each container to have a unique name. Remove the custom name to scale the service.
    # No hostname parameter: for distinguishing workers by different hostnames.
    senescence:
        build:
            context: .
            dockerfile: dockerfiles/Dockerfile.dev.module
            args:
                - MODULE_NAME=senescence
                - BUILD_TIME_SERIES=True
                - NEXUS_URL=${NEXUS_URL}
                - NEXUS_PYPI=${NEXUS_PYPI}
                - no_proxy=${no_proxy}
        volumes:
            - ./.env:${AGRILEARN_ENV_PATH}
            - .:/agrilearn_app/bredao
            - ./submodules/commons:/agrilearn_app/submodules/commons
        environment:
            - MONGO_HOST=${MONGO_HOST}
            - MONGO_PORT=${MONGO_PORT}
            - MONGO_INITDB_ROOT_USERNAME=${MONGO_INITDB_ROOT_USERNAME}
            - MONGO_INITDB_ROOT_PASSWORD=${MONGO_INITDB_ROOT_PASSWORD}
            - RABBITMQ_USER=${RABBITMQ_USER}
            - RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD}
            - RABBITMQ_HOST=${RABBITMQ_HOST}
        command: "make run-model-worker"
        deploy:
            mode: replicated
            replicas: ${N_REPLICAS_SENESCENCE}
        depends_on:
            commons:
                condition: service_completed_successfully

    # Agrilearn harvest detection.
    # No container_name parameter: Docker requires each container to have a unique name. Remove the custom name to scale the service.
    # No hostname parameter: for distinguishing workers by different hostnames.
    harvest:
        build:
            context: .
            dockerfile: dockerfiles/Dockerfile.dev.module
            args:
                - MODULE_NAME=harvest
                - BUILD_HARVEST=True
                - NEXUS_URL=${NEXUS_URL}
                - NEXUS_PYPI=${NEXUS_PYPI}
                - no_proxy=${no_proxy}
        volumes:
            - ./.env:${AGRILEARN_ENV_PATH}
            - .:/agrilearn_app/bredao
            - ./submodules/commons:/agrilearn_app/submodules/commons
        environment:
            - MONGO_HOST=${MONGO_HOST}
            - MONGO_PORT=${MONGO_PORT}
            - MONGO_INITDB_ROOT_USERNAME=${MONGO_INITDB_ROOT_USERNAME}
            - MONGO_INITDB_ROOT_PASSWORD=${MONGO_INITDB_ROOT_PASSWORD}
            - RABBITMQ_USER=${RABBITMQ_USER}
            - RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD}
            - RABBITMQ_HOST=${RABBITMQ_HOST}
        command: "make run-model-worker"
        deploy:
            mode: replicated
            replicas: ${N_REPLICAS_HARVEST}
        depends_on:
            commons:
                condition: service_completed_successfully
