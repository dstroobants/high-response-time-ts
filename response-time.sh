URL="<Endpoint_To_Test>"
LOG_FILE="response-time.log"
PCAP_DIR="packet_captures"
WARNING_THRESHOLD=3  # seconds

# Check if running as root
if [ "$(id -u)" != "0" ]; then
    echo "Error: This script must be run as root (sudo) to capture network traffic"
    echo "Please run with: sudo $0"
    exit 1
fi

# Create log file and pcap directory if they don't exist
touch "$LOG_FILE"
mkdir -p "$PCAP_DIR"

# Function to start packet capture
start_packet_capture() {
    timestamp=$(date '+%Y%m%d_%H%M%S')
    pcap_file="$PCAP_DIR/capture_${timestamp}.pcap"
    tcpdump -i any -w "$pcap_file" "host $(echo $URL | sed -E 's|https?://([^/]+).*|\1|')" &
    echo $! > /tmp/tcpdump_pid
    echo "$pcap_file" > /tmp/current_pcap_file
    echo "Started packet capture: $pcap_file"
    # Give tcpdump a moment to start up
    sleep 1
}

# Function to stop packet capture
stop_packet_capture() {
    if [ -f /tmp/tcpdump_pid ]; then
        pid=$(cat /tmp/tcpdump_pid)
        # Give tcpdump time to finish writing
        sleep 2
        # Send SIGTERM to allow tcpdump to flush its buffer
        kill -TERM $pid
        # Wait for the process to finish
        wait $pid 2>/dev/null
        rm /tmp/tcpdump_pid
        echo "Stopped packet capture"
        
        # If a pcap file path is provided, delete it
        if [ -n "$1" ] && [ -f "$1" ]; then
            rm "$1"
            echo "Deleted pcap file: $1"
        fi
    fi
}

# Cleanup function
cleanup() {
    stop_packet_capture
    rm -f /tmp/current_pcap_file
    exit 0
}

# Set up trap for cleanup
trap cleanup SIGINT SIGTERM

while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Start packet capture before making the request
    start_packet_capture
    
    # Make the request and get response time
    response_time=$(curl -o /dev/null -s -w "%{time_total}" "$URL")
    echo "DEBUG: Request completed with response time: ${response_time}s"

    # Format the log entry
    log_entry="[$timestamp] Response time: ${response_time}s"
    
    # Check if response time is over threshold
    if (( $(echo "$response_time > $WARNING_THRESHOLD" | bc -l) )); then
        log_entry="$log_entry [WARNING: High response time detected!] - [Capture File: $pcap_file]"
        echo "Keeping packet capture for analysis: $pcap_file"
        # Stop capture but keep the file
        stop_packet_capture
    else
        # Stop packet capture and delete the file for normal response times
        stop_packet_capture "$pcap_file"
        echo "DEBUG: Deleting File"
    fi
    
    # Output to console and append to log file
    echo "$log_entry" | tee -a "$LOG_FILE"
    
    sleep 3
done