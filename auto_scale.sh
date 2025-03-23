#!/bin/bash

# Variables
GCP_PROJECT="vcc-assignment-3-454604"
GCP_ZONE="us-central1-a"
GCP_VM_NAME="autoscale-vm"
GCP_MACHINE_TYPE="e2-medium"
GCP_IMAGE_FAMILY="debian-11"
GCP_IMAGE_PROJECT="debian-cloud"
LOCAL_APP="server.py"
GCP_USER="b22cs016"
GCP_INSTANCE_IP=""

# Function to check CPU usage
check_cpu_usage() {
    USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    USAGE_INT=${USAGE%.*}  # Convert to integer
    echo "Current CPU Usage: $USAGE%"
    if [ "$USAGE_INT" -gt 75 ]; then
        echo "CPU usage exceeded 75%. Scaling to GCP..."
        create_gcp_vm
    else
        echo "CPU usage is normal. No action needed."
    fi
}

# Function to create a VM in GCP
create_gcp_vm() {
    gcloud compute instances create $GCP_VM_NAME \
        --project=$GCP_PROJECT \
        --zone=$GCP_ZONE \
        --machine-type=$GCP_MACHINE_TYPE \
        --image-family=$GCP_IMAGE_FAMILY \
        --image-project=$GCP_IMAGE_PROJECT \
        --tags=http-server,https-server
    
    sleep 60  # Wait for the instance to be ready
    GCP_INSTANCE_IP=$(gcloud compute instances list --filter="name=$GCP_VM_NAME" --format="get(networkInterfaces[0].accessConfigs[0].natIP)")
    echo "GCP VM IP: $GCP_INSTANCE_IP"
    transfer_app_to_gcp
}

# Function to transfer application to GCP
transfer_app_to_gcp() {
    echo "Transferring application to GCP VM..."
    scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $LOCAL_APP $GCP_USER@$GCP_INSTANCE_IP:~/
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $GCP_USER@$GCP_INSTANCE_IP "nohup python3 ~/server.py &"
    echo "Application deployed on GCP VM."
}

# Run the script every 5 minutes
echo "Starting auto-scaling monitoring..."
while true; do
    check_cpu_usage
    sleep 300  # Wait for 5 minutes before next check
done
