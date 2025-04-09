# high-response-time-ts
Script to reproduce and troubleshoot high response time from an endpoint

## Usage

```bash
sudo chmod +x ./test.sh
sudo ./test.sh
```
The script will make a request every few seconds and produce a tcpdump file (pcap) in the `packet_captures` directory. 

If the response time is greater than the `WARNING_THRESHOLD` specified in the script, the pcap file is kept. If not, it is being deleted.

You can then run this command to get the output of the tcpdump file:

```bash
tcpdump -r packet_captures/<Capture_File>.pcap
```
