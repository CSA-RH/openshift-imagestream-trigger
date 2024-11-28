# Descripton

The script `deploy.sh` creates a new image based on the `openshift/hello-openshift` image. It sets the environment variable `RESPONSE` to the value passed as a parameter or assigns a random number if no value is provided. The script then creates a deployment along with the necessary networking resources to make the application accessible.

The image is built using the OpenShift internal image registry, with the build process handled by a BuildConfig resource. The build utilizes a dynamically generated Dockerfile, which is created in the container folder. The resulting image is accessed via an ImageStreamTag located in a namespace different from the application's namespace.

On some Linux systems, you may need to grant execution permissions to the script using the following command 

```bash
chmod +x deploy.sh
```

# Prerequisites

- An app project named <app-namespace>
- An image project named <app-namespace>-common
- oc CLI tool logged with an user with permission to both namespaces. 

