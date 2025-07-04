#!/bin/bash

# Set the StatefulSet name
statefulset_name="redis-local-redis-cluster"

# Log status
echo "Starting node sync for StatefulSet $statefulset_name"

# Get the number of pods in the StatefulSet
num_pods=$(kubectl get statefulset "$statefulset_name" -o jsonpath='{.status.replicas}')

# Log pods count
echo "StatefulSet $statefulset_name has $num_pods pods"

# Define the starting pod index
start_index=0

# Define the increment for pod indices
increment=6

# Calculate the pod indices to execute the action on
while [ "$start_index" -lt "$num_pods" ]
do
    # Define the ending pod index for the current batch
    end_index=$((start_index + 2))

    # Calculate the pod indices to execute the action on
    pod_indices=()
    for index in $(seq "$start_index" "$end_index"); do
        pod_indices+=("$index")
    done

    # Execute the action on the specified pods
    for index in "$${pod_indices[@]}"
    do
        # Calculate the pod name
        pod_name="$${statefulset_name}-$${index}"

        echo "Connecting to pod $pod_name"
        kubectl exec "$pod_name" -- /bin/bash -c '/scripts/failover.sh replica'
    done

    # Increment the starting index to skip the next 3 pods
    start_index=$((start_index + increment))
done

# Log success
echo "Nodes sync for StatefulSet $statefulset_name completed successfully"
