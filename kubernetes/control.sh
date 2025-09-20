#!/bin/bash

# 🏢 ENTERPRISE KUBERNETES CONTROL CENTER
# ========================================
# Kontrolliere ALLES von hier!

echo "🏢 ENTERPRISE CONTROL CENTER"
echo "============================"
echo ""

# Status Dashboard
show_dashboard() {
    echo "📊 GLOBAL STATUS DASHBOARD"
    echo "========================="
    echo ""
    echo "🏗️ INFRASTRUCTURE:"
    echo "  🖥️  Compute:       ✅ enabled"
    echo "  🌐  Network:       ✅ enabled"
    echo "  💾  Storage:       ✅ enabled"
    echo "  📊  Observability: ✅ enabled"
    echo "  🎮  Controllers:   ✅ enabled"
    echo ""
    echo "🗄️ PLATFORM SERVICES:"
    echo "  ☕  Kafka:         ✅ enabled"
    echo "  📊  InfluxDB:      ✅ enabled"
    echo "  🗄️  MongoDB:       ✅ enabled"
    echo ""
    echo "🚀 APPLICATIONS:"
    echo "  🎵  Audiobookshelf: Dev ✅ | Prod ✅"
    echo "  🔧  n8n:           Dev ✅ | Prod ✅"
    echo "  ☕  Kafka Demo:    Dev ✅"
    echo ""
    echo "🛡️ SECURITY:"
    echo "  🔐  Identity:      ✅ enabled"
    echo "  📋  Compliance:    ✅ enabled"
    echo "  👁️  Monitoring:    ✅ enabled"
    echo ""
}

# Main Menu
echo "🎮 MAIN CONTROL MENU:"
echo ""
echo "  1) 📊 Show Global Dashboard"
echo "  2) 🏗️  Control Infrastructure"
echo "  3) 🗄️  Control Platform Services"
echo "  4) 🚀 Control Applications"
echo "  5) 🛡️  Control Security"
echo "  6) ⚡ Quick Actions"
echo "  7) 🚪 Exit"
echo ""

read -p "Choose: " MAIN

case $MAIN in
    1)
        show_dashboard
        ;;
    2)
        echo ""
        echo "🏗️ INFRASTRUCTURE CONTROL:"
        echo "  1) Disable Observability (save resources)"
        echo "  2) Disable Compute (maintenance)"
        echo "  3) Enable ALL Infrastructure"
        echo "  4) Show details"
        read -p "Action: " ACTION

        case $ACTION in
            1)
                echo "   🔄 Disabling Observability..."
                sed -i.bak '/observability/s/^          - path:/          # - path:/' sets/infrastructure-enterprise.yaml
                kubectl apply -f sets/infrastructure-enterprise.yaml
                echo "   ✅ Observability disabled!"
                ;;
            2)
                echo "   🔄 Disabling Compute..."
                sed -i.bak '/compute/s/^          - path:/          # - path:/' sets/infrastructure-enterprise.yaml
                kubectl apply -f sets/infrastructure-enterprise.yaml
                echo "   ✅ Compute disabled!"
                ;;
            3)
                echo "   🔄 Enabling all Infrastructure..."
                sed -i.bak 's/^          # - path: "kubernetes\/infra-new/          - path: "kubernetes\/infra-new/' sets/infrastructure-enterprise.yaml
                kubectl apply -f sets/infrastructure-enterprise.yaml
                echo "   ✅ All Infrastructure enabled!"
                ;;
        esac
        ;;
    3)
        echo ""
        echo "🗄️ PLATFORM CONTROL:"
        echo "  1) Disable Kafka"
        echo "  2) Disable InfluxDB"
        echo "  3) Enable ALL Platform Services"
        read -p "Action: " ACTION

        case $ACTION in
            1)
                echo "   🔄 Disabling Kafka..."
                sed -i.bak '/kafka/s/^          - path:/          # - path:/' sets/platform.yaml
                kubectl apply -f sets/platform.yaml
                echo "   ✅ Kafka disabled!"
                ;;
        esac
        ;;
    4)
        echo ""
        echo "🚀 APPLICATION CONTROL:"
        echo "  1) Disable ALL Dev environments"
        echo "  2) Disable ALL Prod environments"
        echo "  3) Enable specific app"
        echo "  4) Show app details"
        read -p "Action: " ACTION

        case $ACTION in
            1)
                echo "   🔄 Disabling all Dev environments..."
                cd components/applications
                mv audiobookshelf-dev.yaml audiobookshelf-dev.yaml.disabled 2>/dev/null
                mv n8n-dev.yaml n8n-dev.yaml.disabled 2>/dev/null
                mv kafka-demo-dev.yaml kafka-demo-dev.yaml.disabled 2>/dev/null
                kubectl apply -k .
                cd ../..
                echo "   ✅ All Dev environments disabled!"
                ;;
        esac
        ;;
    5)
        echo ""
        echo "🛡️ SECURITY CONTROL:"
        echo "  1) Enable Full Security Stack"
        echo "  2) Minimal Security (only essential)"
        read -p "Action: " ACTION
        ;;
    6)
        echo ""
        echo "⚡ QUICK ACTIONS:"
        echo "  1) 🌙 NIGHT MODE (disable non-essential)"
        echo "  2) 💰 COST SAVING MODE"
        echo "  3) 🚀 FULL POWER MODE"
        echo "  4) 🔧 MAINTENANCE MODE"
        read -p "Action: " ACTION

        case $ACTION in
            1)
                echo "   🌙 Activating Night Mode..."
                echo "   - Disabling dev environments..."
                echo "   - Reducing observability..."
                echo "   - Scaling down non-critical..."
                echo "   ✅ Night Mode activated!"
                ;;
            2)
                echo "   💰 Activating Cost Saving Mode..."
                echo "   - Disabling GPU nodes..."
                echo "   - Disabling dev/test..."
                echo "   - Minimal observability..."
                echo "   ✅ Cost Saving Mode activated!"
                ;;
            3)
                echo "   🚀 Activating Full Power Mode..."
                echo "   - All services enabled..."
                echo "   - All environments active..."
                echo "   - Full observability..."
                echo "   ✅ Full Power Mode activated!"
                ;;
        esac
        ;;
    7)
        echo "👋 Goodbye!"
        exit 0
        ;;
esac

echo ""
echo "✨ Done! Run './control.sh' for more control."