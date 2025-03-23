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
    USAGE=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage}')
    USAGE_INT=$(printf "%.0f" "$USAGE")  # Convert to integer
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
    
    echo "Waiting for VM to be ready..."
    sleep 60  

    # Get the public IP of the newly created VM
    GCP_INSTANCE_IP=$(gcloud compute instances describe $GCP_VM_NAME --zone=$GCP_ZONE --format="get(networkInterfaces[0].accessConfigs[0].natIP)")
    
    if [[ -z "$GCP_INSTANCE_IP" ]]; then
        echo "Error: Failed to retrieve GCP VM IP!"
        exit 1
    fi

    echo "GCP VM IP: $GCP_INSTANCE_IP"
    transfer_app_to_gcp
}

# Function to transfer application to GCP
transfer_app_to_gcp() {
    echo "Checking SSH key..."
    if [ ! -f ~/.ssh/id_rsa ]; then
        echo "SSH key not found! Generate one using: ssh-keygen -t rsa"
        exit 1
    fi

    echo "Transferring application to GCP VM..."
    scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $LOCAL_APP $GCP_USER@$GCP_INSTANCE_IP:~/

    echo "Starting application on GCP VM..."
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $GCP_USER@$GCP_INSTANCE_IP "nohup python3 ~/server.py > server.log 2>&1 & disown"

    echo "Application deployed on GCP VM."
}

# Run the script every 5 minutes
echo "Starting auto-scaling monitoring..."
while true; do
    check_cpu_usage
    sleep 300  # Wait for 5 minutes before next check
done
