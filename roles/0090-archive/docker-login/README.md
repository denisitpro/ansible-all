# Ansible Role: Docker Registry Login

This Ansible role handles authentication to a Docker Registry, including Docker Hub, using the `docker_login` module. It ensures secure access to private or public container images.

## Requirements

- Docker must be installed and configured on the target machine.
- Personal Access Token (PAT) is required for Docker Hub authentication, as passwords are no longer supported.

## Role Variables

The following variables can be defined to configure the role:

| Variable                  | Default       | Description                                                                 |
|---------------------------|---------------|-----------------------------------------------------------------------------|
| `docker_registry_url`     | `""`          | URL of the Docker Registry. Defaults to Docker Hub if not specified.       |
| `docker_registry_username`| `""`          | Username for Docker Registry authentication.                               |
| `docker_registry_password`| `""`          | Password or Personal Access Token (PAT) for Docker Registry authentication.|

## Logout Functionality

The role includes a `docker-logout` tag to log out from the Docker Registry. This clears locally stored authentication credentials.

## Examples

### Login to Docker Hub

To authenticate with Docker Hub, set the username and token:

```yaml
docker_registry_username: "username"
docker_registry_password: "token"
```

### Login to a Specific Docker Registry
To authenticate with a specific Docker Registry, specify its URL along with the username and token:
```yaml
docker_registry_url: "https://registry.example.com"
docker_registry_username: "username"
docker_registry_password: "token"
```