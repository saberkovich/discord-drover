# Discord Drover

Discord Drover is a program that forces the Discord application for Windows to use a specified proxy server (HTTPS or SOCKS5) for TCP connections (chat, updates). This may be necessary because the original Discord application lacks proxy settings, and the global system proxy is also not used. Additionally, the program slightly interferes with Discord's outgoing UDP traffic, which helps bypass some local restrictions on voice chats.

The program works locally at the specific process level (without drivers) and does not affect the operating system globally. This approach serves as an alternative to using a global VPN (such as TUN interfaces and others).

## Installation

To use Discord Drover, copy the `version.dll` and `drover.ini` files into the folder containing the `Discord.exe` file (not `Update.exe`). The proxy itself is specified in the `drover.ini` file under the `proxy` parameter.

### Example `drover.ini` Configuration:

```
[drover]
proxy = 127.0.0.1:1080
;use-nekobox-proxy = 1
;nekobox-proxy = 127.0.0.1:2080
```

- **proxy**: Defines the main proxy server to use for Discord.
- **use-nekobox-proxy**: Enables the feature to detect if NekoBox is running and use a different proxy if found.
- **nekobox-proxy**: The proxy used when NekoBox is detected, typically `127.0.0.1:2080`.

## Features

- Forces Discord to use a specified proxy for TCP connections.
- Slight interference with UDP traffic for bypassing voice chat restrictions.
- No drivers or system-level modifications are required.
- Works locally at the process level, offering an alternative to global VPN solutions.
