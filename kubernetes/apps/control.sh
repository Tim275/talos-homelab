#!/bin/bash

# 🚀 APPLICATION CONTROL SCRIPT
# Super einfach Apps ein/ausschalten!

echo "🚀 Application Service Control"
echo "=============================="

# App Status anzeigen
show_status() {
    echo ""
    echo "📊 Current Application Status:"
    echo ""
    echo "  🎵 Audiobookshelf:"
    echo "     Dev:  $(grep -A2 'audiobookshelf:' APPS.yaml | grep -A1 'dev:' | grep 'enabled:' | head -1 | awk '{print $2}')"
    echo "     Prod: $(grep -A5 'audiobookshelf:' APPS.yaml | grep -A1 'prod:' | grep 'enabled:' | head -1 | awk '{print $2}')"
    echo ""
    echo "  🔧 n8n:"
    echo "     Dev:  $(grep -A2 'n8n:' APPS.yaml | grep -A1 'dev:' | grep 'enabled:' | head -1 | awk '{print $2}')"
    echo "     Prod: $(grep -A5 'n8n:' APPS.yaml | grep -A1 'prod:' | grep 'enabled:' | head -1 | awk '{print $2}')"
    echo ""
    echo "  ☕ Kafka Demo:"
    echo "     Dev:  $(grep -A2 'kafka-demo:' APPS.yaml | grep -A1 'dev:' | grep 'enabled:' | head -1 | awk '{print $2}')"
    echo ""
}

# App ein/ausschalten
toggle_app() {
    APP=$1
    ENV=$2
    STATUS=$3

    FILENAME="${APP}-${ENV}.yaml"

    echo "🔄 Setting $APP ($ENV) to $STATUS..."

    if [ "$STATUS" = "off" ]; then
        # App deaktivieren - Datei umbenennen zu .disabled
        if [ -f "$FILENAME" ]; then
            mv "$FILENAME" "${FILENAME}.disabled"
            echo "   ✅ $APP ($ENV) disabled"

            # Update kustomization.yaml
            sed -i.bak "/$FILENAME/d" kustomization.yaml
        fi
    else
        # App aktivieren - .disabled entfernen
        if [ -f "${FILENAME}.disabled" ]; then
            mv "${FILENAME}.disabled" "$FILENAME"
            echo "   ✅ $APP ($ENV) enabled"

            # Update kustomization.yaml
            echo "  - $FILENAME" >> kustomization.yaml
        fi
    fi
}

# Menu
echo ""
echo "🎮 CONTROL MENU:"
echo "  1) Show app status"
echo "  2) Enable app"
echo "  3) Disable app"
echo "  4) Quick toggles"
echo "  5) Apply changes to cluster"
echo "  6) Exit"
echo ""

read -p "Choose option: " OPTION

case $OPTION in
    1)
        show_status
        ;;
    2)
        echo "Which app to ENABLE?"
        echo "  1) audiobookshelf-dev"
        echo "  2) audiobookshelf-prod"
        echo "  3) n8n-dev"
        echo "  4) n8n-prod"
        echo "  5) kafka-demo-dev"
        read -p "App: " APP_NUM

        case $APP_NUM in
            1) toggle_app "audiobookshelf" "dev" "on";;
            2) toggle_app "audiobookshelf" "prod" "on";;
            3) toggle_app "n8n" "dev" "on";;
            4) toggle_app "n8n" "prod" "on";;
            5) toggle_app "kafka-demo" "dev" "on";;
        esac
        ;;
    3)
        echo "Which app to DISABLE?"
        echo "  1) audiobookshelf-dev"
        echo "  2) audiobookshelf-prod"
        echo "  3) n8n-dev"
        echo "  4) n8n-prod"
        echo "  5) kafka-demo-dev"
        read -p "App: " APP_NUM

        case $APP_NUM in
            1) toggle_app "audiobookshelf" "dev" "off";;
            2) toggle_app "audiobookshelf" "prod" "off";;
            3) toggle_app "n8n" "dev" "off";;
            4) toggle_app "n8n" "prod" "off";;
            5) toggle_app "kafka-demo" "dev" "off";;
        esac
        ;;
    4)
        echo "🚀 QUICK TOGGLES:"
        echo "  1) Disable ALL dev environments"
        echo "  2) Enable ALL dev environments"
        echo "  3) Disable ALL prod environments"
        echo "  4) Enable ALL prod environments"
        read -p "Toggle: " TOGGLE

        case $TOGGLE in
            1)
                toggle_app "audiobookshelf" "dev" "off"
                toggle_app "n8n" "dev" "off"
                toggle_app "kafka-demo" "dev" "off"
                echo "   ✅ All dev environments disabled!"
                ;;
            2)
                toggle_app "audiobookshelf" "dev" "on"
                toggle_app "n8n" "dev" "on"
                toggle_app "kafka-demo" "dev" "on"
                echo "   ✅ All dev environments enabled!"
                ;;
            3)
                toggle_app "audiobookshelf" "prod" "off"
                toggle_app "n8n" "prod" "off"
                echo "   ✅ All prod environments disabled!"
                ;;
            4)
                toggle_app "audiobookshelf" "prod" "on"
                toggle_app "n8n" "prod" "on"
                echo "   ✅ All prod environments enabled!"
                ;;
        esac
        ;;
    5)
        echo "🚀 Applying to cluster..."
        kubectl apply -k .
        echo "   ✅ Changes applied!"
        ;;
    6)
        echo "👋 Bye!"
        exit 0
        ;;
esac

echo ""
echo "✨ Done! Run './control.sh' again for more changes."