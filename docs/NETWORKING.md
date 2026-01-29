# Terraria Steam Deck Server - Networking Guide

This guide covers network configuration for hosting your Terraria server, including port requirements, firewall configuration, and port forwarding for remote access.

## Table of Contents

- [Port Requirements](#port-requirements)
- [Local Network Access](#local-network-access)
- [Firewall Configuration](#firewall-configuration)
- [Port Forwarding for Remote Access](#port-forwarding-for-remote-access)
- [Finding Your IP Addresses](#finding-your-ip-addresses)
- [Testing Connectivity](#testing-connectivity)
- [Security Considerations](#security-considerations)
- [Troubleshooting Connectivity](#troubleshooting-connectivity)

---

## Port Requirements

The Terraria Steam Deck Server uses two ports:

| Port | Protocol | Service | Required For |
|------|----------|---------|--------------|
| **7777** | TCP | Terraria Game Server | Players connecting to play |
| **8080** | TCP | Web Management Interface | Admin access via browser |

### Port Summary

```
┌─────────────────────────────────────────────────────────────┐
│                     Steam Deck                               │
│                                                              │
│  ┌─────────────────────┐    ┌─────────────────────┐        │
│  │   Terraria Server   │    │   Web Interface     │        │
│  │     Port 7777       │    │     Port 8080       │        │
│  │   (Game Traffic)    │    │   (Admin Panel)     │        │
│  └─────────────────────┘    └─────────────────────┘        │
│            ↕                          ↕                     │
└────────────┼──────────────────────────┼─────────────────────┘
             │                          │
             ▼                          ▼
      Players connect            Admin connects
      to play Terraria          to manage server
```

---

## Local Network Access

For players on the same local network (home network, LAN party):

### Step 1: Find Your Steam Deck's IP Address

```bash
# Run on Steam Deck
ip addr show | grep "inet " | grep -v 127.0.0.1
```

Look for an address like `192.168.1.x` or `10.0.0.x`.

### Step 2: Connect from Terraria

On any device on the same network:

1. Open Terraria
2. Select **Multiplayer**
3. Select **Join via IP**
4. Enter: `192.168.1.x:7777` (replace with your Steam Deck's IP)
5. Enter server password if configured

### Web Interface Access

From any device on the same network, open a browser and go to:

```
http://192.168.1.x:8080
```

Replace `192.168.1.x` with your Steam Deck's IP address.

---

## Firewall Configuration

### Steam Deck (SteamOS)

SteamOS typically doesn't have a firewall enabled by default. If you've enabled one:

```bash
# Allow Terraria server port
sudo iptables -A INPUT -p tcp --dport 7777 -j ACCEPT

# Allow web interface port
sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT

# Save rules (if using persistent iptables)
sudo iptables-save > /etc/iptables/rules.v4
```

### Using firewalld (if installed)

```bash
# Allow Terraria port
sudo firewall-cmd --permanent --add-port=7777/tcp

# Allow web interface port (optional, local access)
sudo firewall-cmd --permanent --add-port=8080/tcp

# Reload firewall
sudo firewall-cmd --reload
```

### Using ufw (if installed)

```bash
# Allow Terraria port
sudo ufw allow 7777/tcp

# Allow web interface port (optional)
sudo ufw allow 8080/tcp

# Enable firewall
sudo ufw enable
```

---

## Port Forwarding for Remote Access

To allow players from outside your local network (internet) to connect, you need to configure port forwarding on your router.

### Understanding Port Forwarding

```
Internet                    Your Router                Steam Deck
─────────                   ───────────                ──────────
                                 │
Player ──────────────────────────┼─────────────────────────────────
                                 │
   Connects to:          Forwards to:          Terraria Server
   YourPublicIP:7777  →  SteamDeckIP:7777  →   Running here
```

### General Steps (Varies by Router)

1. **Access your router's admin panel**
   - Usually at `http://192.168.1.1` or `http://192.168.0.1`
   - Login with your router's admin credentials

2. **Find Port Forwarding settings**
   - Look under: Advanced → Port Forwarding
   - Or: NAT → Virtual Server
   - Or: Firewall → Port Forward
   - Or: Games & Applications

3. **Create a new port forwarding rule**

   | Setting | Value |
   |---------|-------|
   | Service Name | Terraria |
   | External Port | 7777 |
   | Internal Port | 7777 |
   | Internal IP | Your Steam Deck's IP |
   | Protocol | TCP |

4. **Save and apply** the configuration

### Common Router Interfaces

Due to the wide variety of routers, please consult your specific router's documentation. Here are some common brands:

| Router Brand | Common Admin URL | Documentation |
|--------------|------------------|---------------|
| Netgear | routerlogin.net | [Netgear Support](https://www.netgear.com/support/) |
| Linksys | 192.168.1.1 | [Linksys Support](https://www.linksys.com/support) |
| ASUS | router.asus.com | [ASUS Support](https://www.asus.com/support/) |
| TP-Link | 192.168.0.1 | [TP-Link Support](https://www.tp-link.com/support/) |
| D-Link | 192.168.0.1 | [D-Link Support](https://www.dlink.com/support) |

**Helpful Resource:** [portforward.com](https://portforward.com/) has router-specific guides.

### Static IP Address (Recommended)

Port forwarding requires a consistent internal IP. Configure your Steam Deck with a static IP or create a DHCP reservation in your router.

#### DHCP Reservation (Preferred)

1. Find your Steam Deck's MAC address:
   ```bash
   ip link show | grep ether
   ```

2. In your router's DHCP settings, reserve an IP for that MAC address

#### Static IP on Steam Deck

Edit network settings in Desktop Mode:
1. Right-click the network icon in the system tray
2. Select your connection → Settings
3. IPv4 → Method: Manual
4. Set your IP, netmask (usually 255.255.255.0), and gateway

---

## Finding Your IP Addresses

### Local (Private) IP Address

This is for local network access:

```bash
# On Steam Deck
ip addr show | grep "inet " | grep -v 127.0.0.1

# Example output: 192.168.1.50
```

### Public IP Address

This is what remote players use:

```bash
# On Steam Deck (requires network access)
curl -s ifconfig.me

# Or visit in a browser
# https://whatismyip.com
```

### Docker Container IP

For debugging container networking:

```bash
docker inspect terraria-server | grep IPAddress
```

---

## Testing Connectivity

### Test Local Access

From another device on your network:

```bash
# Test Terraria port
nc -zv <steam-deck-ip> 7777

# Test web interface
curl http://<steam-deck-ip>:8080/api/status
```

### Test Remote Access

Use an online port checker:

1. Visit [canyouseeme.org](https://canyouseeme.org/)
2. Enter port 7777
3. Click "Check Port"

If the check fails:
- Verify port forwarding is configured correctly
- Check if your ISP blocks the port
- Ensure the Terraria server is running

### Test from Remote Player

Have a friend outside your network try to connect:

1. Give them your public IP: `curl -s ifconfig.me`
2. They connect to: `<your-public-ip>:7777`

---

## Security Considerations

### Web Interface (Port 8080)

**Do NOT forward port 8080 to the internet** unless absolutely necessary.

The web interface provides full server control. Exposing it publicly:
- Allows brute-force password attacks
- Risks server compromise if password is weak
- Could allow attackers to delete worlds/backups

**Safer alternatives for remote admin:**
- Use a VPN to access your home network
- Use SSH tunneling
- Only access when on local network

### Game Server (Port 7777)

Port 7777 is generally safe to forward:
- Terraria's protocol is relatively simple
- Set a server password for additional protection
- Enable anti-cheat (`SECURE=1`)

### Firewall Best Practices

```bash
# Only allow necessary ports
# Block everything else by default
# Regularly check for open ports
```

### VPN for Remote Access

For secure remote administration, consider:
- **Tailscale** - Easy to set up, works on Steam Deck
- **WireGuard** - Modern, fast VPN
- **OpenVPN** - Widely supported

With a VPN, you can access the web interface without port forwarding.

---

## Troubleshooting Connectivity

### Players Can't Connect

1. **Verify server is running:**
   ```bash
   make health
   ```

2. **Check if port is listening:**
   ```bash
   ss -tlnp | grep 7777
   ```

3. **Test local connectivity first:**
   ```bash
   nc -zv localhost 7777
   ```

4. **Check firewall:**
   ```bash
   sudo iptables -L -n | grep 7777
   ```

5. **Verify Docker port mapping:**
   ```bash
   docker port terraria-server
   ```

### Remote Players Can't Connect

1. **Confirm local access works** (troubleshoot local first)

2. **Verify public IP:**
   ```bash
   curl -s ifconfig.me
   ```

3. **Check port forwarding:**
   - Use online port checker
   - Verify router configuration

4. **Check for double NAT:**
   - If your ISP uses CGNAT, port forwarding won't work
   - Contact ISP or use a VPN service

5. **Test with different port:**
   - Some ISPs block port 7777
   - Try port 17777 if available

### Web Interface Not Accessible

1. **Check if API is running:**
   ```bash
   make status
   ```

2. **Test locally:**
   ```bash
   curl http://localhost:8080/api/status
   ```

3. **Check for port conflicts:**
   ```bash
   ss -tlnp | grep 8080
   ```

### Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| "Connection refused" | Port not listening | Check server is running |
| "Connection timed out" | Firewall/routing issue | Check firewall, port forwarding |
| "No route to host" | Network unreachable | Check network configuration |
| "Host unreachable" | Can't reach destination | Verify IP address is correct |

---

## Network Performance Tips

### Reduce Latency

- Use wired Ethernet instead of Wi-Fi when possible
- Steam Deck has USB-C dock support for Ethernet
- Prioritize gaming traffic in router QoS settings

### Bandwidth Requirements

| Players | Upload Bandwidth Needed |
|---------|------------------------|
| 1-4 | 1-2 Mbps |
| 5-8 | 2-5 Mbps |
| 9-16 | 5-10 Mbps |

### Wi-Fi Recommendations

If using Wi-Fi:
- Use 5GHz band for less interference
- Position Steam Deck near the router
- Avoid interference from other devices

---

## Quick Reference

### Port Forward Checklist

- [ ] Steam Deck has consistent IP (static or DHCP reservation)
- [ ] Port 7777/TCP forwarded to Steam Deck IP
- [ ] Firewall allows port 7777
- [ ] Server is running (`make status`)
- [ ] Online port check shows port open

### Connection Information to Share

When inviting players:

```
Server: <your-public-ip>:7777
Password: <if set>
```

For local players:
```
Server: <steam-deck-local-ip>:7777
Password: <if set>
```

---

*For setup instructions, see [SETUP.md](SETUP.md)*
*For troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)*
