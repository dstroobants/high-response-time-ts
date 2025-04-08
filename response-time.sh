URL="<Endpoint_To_Test>"
LOG_FILE="curl_monitor.log"
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
    echo "Started packet capture: $pcap_file"
}

# Function to stop packet capture
stop_packet_capture() {
    if [ -f /tmp/tcpdump_pid ]; then
        kill $(cat /tmp/tcpdump_pid)
        rm /tmp/tcpdump_pid
        echo "Stopped packet capture"
    fi
}

# Cleanup function
cleanup() {
    stop_packet_capture
    exit 0
}

# Set up trap for cleanup
trap cleanup SIGINT SIGTERM

while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Start packet capture before making the request
    start_packet_capture
    
    # Get start time in seconds since epoch
    start_time=$(date +%s.%N)
    
    # Make the request
    response_time=$(curl -o /dev/null -s -w "%{time_total}" "$URL")
    
    # Get end time
    end_time=$(date +%s.%N)
    
    # Calculate actual elapsed time
    elapsed_time=$(echo "$end_time - $start_time" | bc)
    
    # Format the log entry
    log_entry="[$timestamp] Response time: ${response_time}s (Actual elapsed: ${elapsed_time}s)"
    
    # Check if response time is over threshold
    if (( $(echo "$elapsed_time > $WARNING_THRESHOLD" | bc -l) )); then
        log_entry="$log_entry [WARNING: High response time detected!]"
        echo "Keeping packet capture for analysis"
    else
        # Stop packet capture if response time is normal
        stop_packet_capture
    fi
    
    # Output to console and append to log file
    echo "$log_entry" | tee -a "$LOG_FILE"
    
    sleep 1
done