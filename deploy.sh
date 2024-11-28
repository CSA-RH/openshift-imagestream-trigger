#!/bin/bash

# Script directories
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
CONTAINER_DIR=$SCRIPT_DIR/container

# Namespaces
APP_NAMESPACE=$(oc project -q)
IMAGES_NAMESPACE=$(oc project -q)-common
echo CURRENT NAMESPACE=$APP_NAMESPACE
if [ -z "${APP_NAMESPACE}" ]; then
  echo "There is no current namespace selected. Please create a namespace for app and image"
  echo "with the form <projectname> and <project name>-common"
  exit 1
fi
echo IMAGE NAMESPACE=$IMAGES_NAMESPACE
echo "---"
# Function to check if a resource exists
check_openshift_resource_exists() {
    local resource_type="$1"
    local resource_name="$2"
    local namespace="$3"
    
    if oc get $resource_type $resource_name -n $namespace >/dev/null 2>&1; then
        return 0  # True: resource exists
    else
        return 1  # False: resource does not exist
    fi
}

# Check if projects exists. 
if check_openshift_resource_exists Project $IMAGES_NAMESPACE $IMAGES_NAMESPACE; then
    echo Project $IMAGES_NAMESPACE exists. Nothing to do
else
    echo Project $IMAGES_NAMESPACE does not exists. 
    echo Create the namespace $IMAGES_NAMESPACE before continuing. Exiting...
    echo ""
    echo "    oc new-project $IMAGES_NAMESPACE"
    echo ""

    exit 1
fi

MESSAGE="Random number: $RANDOM"
# If a parameter is passed, take it into a message
if [ "$#" -gt 0 ]; then
    MESSAGE="$@"
fi

# Cleanup container folder
if [ -d $CONTAINER_DIR ]; then
  rm -rf $CONTAINER_DIR
fi
mkdir -p $CONTAINER_DIR

cat <<EOF > $CONTAINER_DIR/Dockerfile
FROM openshift/hello-openshift

ENV RESPONSE="$MESSAGE"
EOF

# Create deployment if not exists. 
if check_openshift_resource_exists Deployment hello $APP_NAMESPACE; then
  echo "Deployment hello exists. Nothing to do"
else
  oc policy add-role-to-user system:image-puller \
    system:serviceaccount:$APP_NAMESPACE:default --namespace=$IMAGES_NAMESPACE
  cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: hello
  name: hello
  namespace: $APP_NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello
  strategy: {}
  template:
    metadata:
      labels:
        app: hello
    spec:
      containers:
      - image: ' ' 
        name: test-hello
        resources: {}
status: {}
EOF
  oc set triggers deploy/hello --from-image=$IMAGES_NAMESPACE/test-hello:latest -c test-hello
fi

# Create ImageStream for test-hello
if check_openshift_resource_exists ImageStream test-hello $IMAGES_NAMESPACE; then
  echo "ImageStream test-hello exists. Nothing to do"
else
  cat <<EOF | oc apply -f -
apiVersion: image.openshift.io/v1
kind: ImageStream
metadata:
  name: test-hello
  namespace: $IMAGES_NAMESPACE  
spec:
  lookupPolicy:
    local: true
EOF
  # Create BuildConfig for test-hello if not exists
  cat <<EOF | oc apply -f - 
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  labels:
    build: test-hello-build
  name: test-hello-build
  namespace: $IMAGES_NAMESPACE  
spec:
  output:
    to:
      kind: ImageStreamTag
      name: test-hello:latest
  source:
    binary: {}
    type: Binary
  strategy:
    dockerStrategy: 
      dockerfilePath: Dockerfile
    type: Docker
EOF
fi

# Create service
if check_openshift_resource_exists Service hello $APP_NAMESPACE; then
  echo "Service hello exists. Nothing to do"
else
  oc expose deploy/hello --port 8080
fi

# Create route
if check_openshift_resource_exists route hello $APP_NAMESPACE; then
  echo "Route hello exists. Nothing to do"
else
  oc expose svc/hello
fi
echo "---"

# Remove previous build objects
oc delete build -n $IMAGES_NAMESPACE --selector build=test-hello-build > /dev/null 
# Start build for obs-main-api
oc start-build -n $IMAGES_NAMESPACE test-hello-build --from-file $SCRIPT_DIR/container
# Follow the logs until completion 
oc logs $(oc get build --selector build=test-hello-build -oNAME -n $IMAGES_NAMESPACE) -n $IMAGES_NAMESPACE -f
# Route path
ROUTE=$(oc get route hello -ojsonpath='{.spec.host}')
echo "------->"
echo " Please navigate to "
echo ""
echo "        http://$ROUTE"
echo ""
echo " It should display the following message:"
echo ""
echo "      $MESSAGE"
echo ""
echo "<-------"