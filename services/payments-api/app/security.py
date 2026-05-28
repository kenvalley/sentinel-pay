import ipaddress
import socket
from urllib.parse import urlparse

ALLOWED_SCHEMES = {"https"}

BLOCKED_CIDRS = [
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16"),
    ipaddress.ip_network("169.254.0.0/16"),  # IMDS / link-local
    ipaddress.ip_network("127.0.0.0/8"),      # loopback
    ipaddress.ip_network("::1/128"),           # IPv6 loopback
    ipaddress.ip_network("fd00::/8"),          # IPv6 ULA
]


def validate_callback_url(url: str) -> str:
    """
    Validate a merchant-supplied URL against an allowlist.
    Raises ValueError if the URL fails any check.
    """
    parsed = urlparse(url)

    if parsed.scheme not in ALLOWED_SCHEMES:
        raise ValueError(f"Scheme '{parsed.scheme}' is not permitted. Use https.")

    hostname = parsed.hostname
    if not hostname:
        raise ValueError("URL has no hostname.")

    # Resolve hostname and re-validate resolved IP (DNS rebinding defence)
    try:
        resolved_ip = ipaddress.ip_address(socket.gethostbyname(hostname))
    except socket.gaierror:
        raise ValueError(f"Hostname '{hostname}' does not resolve.")

    for blocked in BLOCKED_CIDRS:
        if resolved_ip in blocked:
            raise ValueError(f"Destination {resolved_ip} is not a permitted address.")

    return url