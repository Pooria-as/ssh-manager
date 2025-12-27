#!/bin/bash
# 🌈 Print Rainbow ASCII Header
print_rainbow() {
    local text="
███████╗███████╗██╗  ██╗    ███╗   ███╗ █████╗ ███╗   ██╗ █████╗  ██████╗ ███████╗██████╗
██╔════╝██╔════╝██║  ██║    ████╗ ████║██╔══██╗████╗  ██║██╔══██╗██╔════╝ ██╔════╝██╔══██╗
███████╗███████╗███████║    ██╔████╔██║███████║██╔██╗ ██║███████║██║  ███╗█████╗  ██████╔╝
╚════██║╚════██║██╔══██║    ██║╚██╔╝██║██╔══██║██║╚██╗██║██╔══██║██║   ██║██╔══╝  ██╔══██╗
███████║███████║██║  ██║    ██║ ╚═╝ ██║██║  ██║██║ ╚████║██║  ██║╚██████╔╝███████╗██║  ██║
╚══════╝╚══════╝╚═╝  ╚═╝    ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝
"
    local colors=(31 33 32 36 34 35) # red, yellow, green, cyan, blue, magenta

    local i=0
    while IFS= read -r line; do
        # Cycle through colors
        local color="${colors[$(( i % ${#colors[@]} ))]}"
        echo -e "\e[1;${color}m${line}\e[0m"
        ((i++))
    done <<< "$text"
}

# Print rainbow header
print_rainbow
# --- Helper: ask for non‑empty input
ask_nonempty() {
    local prompt="$1"
    local var
    while true; do
        read -p "$prompt: " var
        if [[ -z "$var" ]]; then
            echo " ❌ Cannot be empty!"
        else
            echo "$var"
            return
        fi
    done
}

# --- Helper: ask for numeric port
ask_port() {
    local prompt="$1"
    local port
    while true; do
        read -p "$prompt: " port
        if ! [[ "$port" =~ ^[0-9]+$ ]]; then
            echo " ❌ Must be a number!"
        else
            echo "$port"
            return
        fi
    done
}

# --- Main Loop
while true; do
    echo
    echo "══════════════════════════ MENU ══════════════════════════"
    echo "1)  SSH to a server"
    echo "2)  Generate SSH key"
    echo "3)  Copy key to server"
    echo "4)  SCP file to server"
    echo "5)  SCP file from server"
    echo "6)  Local port forward (ssh -L)"
    echo "7)  Reverse port forward (ssh -R)"
    echo "0)  Exit"
    echo "════════════════════════════════════════════════════════="
    read -p "Choose option: " OPTION

    case $OPTION in

        1)
            TARGET=$(ask_nonempty " ➤ Target IP/Domain")
            USER=$(ask_nonempty   " ➤ Username")
            PORT=$(ask_port       " ➤ SSH Port")

            echo
            echo "🔗 Connecting to $USER@$TARGET on port $PORT..."
            ssh -p "$PORT" "$USER@$TARGET"
            ;;

        2)
            if [[ ! -f ~/.ssh/id_rsa ]]; then
                echo "🔑 Generating RSA key..."
                ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "auto-key"
            else
                echo "⚠ SSH key already exists."
            fi
            ;;

        3)
            TARGET=$(ask_nonempty " ➤ Target IP/Domain")
            USERNAME=$(ask_nonempty " ➤ Username")
            PORT=$(ask_port       " ➤ SSH Port")

            echo "📤 Copying SSH key to $USERNAME@$TARGET on port $PORT..."
            ssh-copy-id -i ~/.ssh/id_rsa.pub -p "$PORT" "$USERNAME@$TARGET"
            ;;

        4)
            while true; do
                read -p " ➤ Local file path to send: " SRC
                [[ -f "$SRC" ]] && break
                echo " ❌ File not found!"
            done
            TARGET=$(ask_nonempty   " ➤ Target IP/Domain")
            DEST=$(ask_nonempty     " ➤ Remote destination path")
            USERNAME=$(ask_nonempty " ➤ Username")
            PORT=$(ask_port         " ➤ SSH Port")

            echo "📤 Sending $SRC..."
            scp -P "$PORT" "$SRC" "$USERNAME@$TARGET:$DEST"
            ;;

        5)
            REMOTE_FILE=$(ask_nonempty " ➤ Remote file path to fetch")
            TARGET=$(ask_nonempty      " ➤ Target IP/Domain")
            LOCAL_DEST=$(ask_nonempty  " ➤ Local destination path")
            USERNAME=$(ask_nonempty    " ➤ Username")
            PORT=$(ask_port            " ➤ SSH Port")

            echo "📥 Fetching $REMOTE_FILE..."
            scp -P "$PORT" "$USERNAME@$TARGET:$REMOTE_FILE" "$LOCAL_DEST"
            ;;

        6)
            TARGET=$(ask_nonempty   " ➤ Target IP/Domain")
            USERNAME=$(ask_nonempty " ➤ Username")
            PORT=$(ask_port        " ➤ SSH Port")
            LPORT=$(ask_port       " ➤ Local port to forward")
            RPORT=$(ask_port       " ➤ Remote port to connect to")

            RHOST="localhost"
            echo
            echo "🔁 Starting local port forward"
            ssh -fN -L "$LPORT:$RHOST:$RPORT" -p "$PORT" "$USERNAME@$TARGET"

            read -p "Create systemd service for this tunnel? (y/n): " createSrv
            if [[ "$createSrv" =~ ^[Yy]$ ]]; then
                while true; do
                    SERVICE_NAME=$(ask_nonempty " ➤ Service name (no spaces)")
                    if [[ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]]; then
                        echo " ❌ That service name already exists!"
                    else
                        break
                    fi
                done

                EXISTING=$(grep -R "ssh -N -L \\*:${LPORT}:${RHOST}:${RPORT}" /etc/systemd/system/*.service 2>/dev/null)
                if [[ -n "$EXISTING" ]]; then
                    echo
                    echo "⚠ Similar tunnel exists:"
                    echo "$EXISTING"
                    read -p "Continue anyway? (y/n): " CONT
                    [[ ! "$CONT" =~ ^[Yy]$ ]] && continue
                fi

                SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
                echo "🛠 Creating systemd service: $SERVICE_FILE"

                sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=SSH Tunnel Service: $SERVICE_NAME
After=network.target

[Service]
ExecStart=/usr/bin/ssh -N -L *:${LPORT}:${RHOST}:${RPORT} \
    -o ExitOnForwardFailure=yes \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 ${USERNAME}@${TARGET} -p ${PORT}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

                sudo systemctl daemon-reload
                sudo systemctl enable "$SERVICE_NAME"
                sudo systemctl start "$SERVICE_NAME"
                echo "✔ Service $SERVICE_NAME created & started!"
            fi
            ;;

        7)
            TARGET=$(ask_nonempty   " ➤ Target IP/Domain")
            USERNAME=$(ask_nonempty " ➤ Username")
            PORT=$(ask_port        " ➤ SSH Port")
            RPORT=$(ask_port       " ➤ Remote port to open on target")
            LHOST=$(ask_nonempty   " ➤ Local host to connect to")
            LPORT=$(ask_port       " ➤ Local port")

            echo
            echo "🔁 Starting reverse forward"
            ssh -fN -R "$RPORT:$LHOST:$LPORT" -p "$PORT" "$USERNAME@$TARGET"

            read -p "Create systemd service for this reverse tunnel? (y/n): " createSrv
            if [[ "$createSrv" =~ ^[Yy]$ ]]; then
                while true; do
                    SERVICE_NAME=$(ask_nonempty " ➤ Service name (no spaces)")
                    if [[ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]]; then
                        echo " ❌ That service name already exists!"
                    else
                        break
                    fi
                done

                EXISTING=$(grep -R "ssh -N -R ${RPORT}:${LHOST}:${LPORT}" /etc/systemd/system/*.service 2>/dev/null)
                if [[ -n "$EXISTING" ]]; then
                    echo
                    echo "⚠ Similar reverse tunnel exists:"
                    echo "$EXISTING"
                    read -p "Continue anyway? (y/n): " CONT
                    [[ ! "$CONT" =~ ^[Yy]$ ]] && continue
                fi

                SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
                echo "🛠 Creating reverse tunnel service: $SERVICE_FILE"

                sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=SSH Reverse Tunnel Service: $SERVICE_NAME
After=network.target

[Service]
ExecStart=/usr/bin/ssh -N -R ${RPORT}:${LHOST}:${LPORT} \
    -o ExitOnForwardFailure=yes \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 ${USERNAME}@${TARGET} -p ${PORT}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

                sudo systemctl daemon-reload
                sudo systemctl enable "$SERVICE_NAME"
                sudo systemctl start "$SERVICE_NAME"
                echo "✔ Reverse tunnel service $SERVICE_NAME created!"
            fi
            ;;

        0)
            echo "👋 Goodbye!"
            exit 0
            ;;

        *)
            echo "❌ Invalid option."
            ;;
    esac
done

