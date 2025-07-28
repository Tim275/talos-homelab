#!/bin/bash

echo "🚨 Talos Homelab Alert Testing Script"
echo "======================================"

# Funktion zum Warten
wait_for_alert() {
    echo "⏳ Waiting 3 minutes for alert to trigger..."
    sleep 180
}

# Test 1: Memory Stress Test (für HighMemoryUsage Alert)
test_memory_alert() {
    echo "🧠 Test 1: Memory Stress Test"
    echo "Creating memory-hungry pod to trigger HighMemoryUsage alert..."
    
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: memory-stress-test
  namespace: default
spec:
  containers:
  - name: stress
    image: polinux/stress
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "1G", "--timeout", "300s"]
    resources:
      requests:
        memory: "100Mi"
      limits:
        memory: "1Gi"
  restartPolicy: Never
EOF
    
    wait_for_alert
    echo "✅ Memory stress test deployed. Check for HighMemoryUsage alert in 5 minutes."
    echo "🧹 Cleanup: kubectl delete pod memory-stress-test"
}

# Test 2: CPU Stress Test (für HighCPUUsage Alert)
test_cpu_alert() {
    echo "🔥 Test 2: CPU Stress Test"
    echo "Creating CPU-hungry pod to trigger HighCPUUsage alert..."
    
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: cpu-stress-test
  namespace: default
spec:
  containers:
  - name: stress
    image: polinux/stress
    command: ["stress"]
    args: ["--cpu", "2", "--timeout", "300s"]
    resources:
      requests:
        cpu: "100m"
      limits:
        cpu: "1000m"
  restartPolicy: Never
EOF
    
    wait_for_alert
    echo "✅ CPU stress test deployed. Check for HighCPUUsage alert in 10 minutes."
    echo "🧹 Cleanup: kubectl delete pod cpu-stress-test"
}

# Test 3: Crash Loop Test (für PodCrashLooping Alert)
test_crash_loop_alert() {
    echo "💥 Test 3: Pod Crash Loop Test"
    echo "Creating pod that will crash loop to trigger PodCrashLooping alert..."
    
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: crash-loop-test
  namespace: default
spec:
  containers:
  - name: crash
    image: busybox
    command: ["sh", "-c", "echo 'Starting...' && sleep 10 && echo 'Crashing!' && exit 1"]
  restartPolicy: Always
EOF
    
    wait_for_alert
    echo "✅ Crash loop test deployed. Check for PodCrashLooping alert in 5 minutes."
    echo "🧹 Cleanup: kubectl delete pod crash-loop-test"
}

# Test 4: Test Alert (sollte sofort feuern)
test_always_firing_alert() {
    echo "🚨 Test 4: Always Firing Test Alert"
    echo "This alert should fire immediately and send email to timour.miagol@outlook.de"
    echo "Check your email inbox in 2-3 minutes!"
}

# Test 5: Error Log Generation (für HighErrorLogRate Alert)
test_error_log_alert() {
    echo "📝 Test 5: Error Log Generation Test"
    echo "Creating pod that generates error logs..."
    
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: error-log-test
  namespace: default
spec:
  containers:
  - name: error-generator
    image: busybox
    command: ["sh", "-c"]
    args:
    - |
      while true; do
        echo "ERROR: This is a test error message"
        echo "CRITICAL: This is a test critical message"
        echo "EXCEPTION: Test exception occurred"
        echo "FAILED: Operation failed"
        sleep 5
      done
  restartPolicy: Never
EOF
    
    wait_for_alert
    echo "✅ Error log test deployed. Check for HighErrorLogRate alert."
    echo "🧹 Cleanup: kubectl delete pod error-log-test"
}

# Cleanup Function
cleanup_all_tests() {
    echo "🧹 Cleaning up all test pods..."
    kubectl delete pod memory-stress-test --ignore-not-found=true
    kubectl delete pod cpu-stress-test --ignore-not-found=true
    kubectl delete pod crash-loop-test --ignore-not-found=true
    kubectl delete pod error-log-test --ignore-not-found=true
    echo "✅ Cleanup completed!"
}

# Menu
echo ""
echo "Available Tests:"
echo "1) Memory Stress Test (triggers HighMemoryUsage)"
echo "2) CPU Stress Test (triggers HighCPUUsage)"
echo "3) Crash Loop Test (triggers PodCrashLooping)"
echo "4) Always Firing Test (triggers TestAlertAlwaysFiring)"
echo "5) Error Log Test (triggers HighErrorLogRate)"
echo "6) Run All Tests"
echo "7) Cleanup All Test Pods"
echo "0) Exit"

read -p "Select test (0-7): " choice

case $choice in
    1) test_memory_alert ;;
    2) test_cpu_alert ;;
    3) test_crash_loop_alert ;;
    4) test_always_firing_alert ;;
    5) test_error_log_alert ;;
    6) 
        test_always_firing_alert
        echo ""
        test_memory_alert
        echo ""
        test_cpu_alert
        echo ""
        test_crash_loop_alert
        echo ""
        test_error_log_alert
        ;;
    7) cleanup_all_tests ;;
    0) echo "Goodbye!" ;;
    *) echo "Invalid choice!" ;;
esac

echo ""
echo "📧 Don't forget to:"
echo "1. Set up Outlook App Password in alertmanager-config.yaml"
echo "2. Deploy the alert rules with: kubectl apply -k kubernetes/infra/monitoring/alert-rules-grafana/"
echo "3. Check email: timour.miagol@outlook.de"
echo "4. Monitor alerts in Grafana: http://grafana.homelab.local/alerting"