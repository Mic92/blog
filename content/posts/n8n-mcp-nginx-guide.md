+++
title = "Configuring Nginx for n8n MCP Servers with Claude Code"
date = "2025-11-12"
slug = "2025/11/12/n8n-mcp-nginx-claude-code"
Categories = [ "n8n", "nginx", "mcp", "claude", "ai" ]
author = "Jörg Thalheim"
+++

## Background

The [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) is an open standard that enables AI assistants like Claude to securely connect to external data sources and tools. [n8n](https://n8n.io/) recently added support for creating MCP servers through their "MCP Server Trigger" node, allowing you to expose workflows as tools that AI assistants can use.

However, when running n8n behind an nginx reverse proxy, the default configuration won't work for MCP servers. This guide explains the technical challenges and provides a complete working nginx configuration.

## The Challenge

n8n's MCP Server Trigger uses [Server-Sent Events (SSE)](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events) for communication, which requires special nginx configuration. Additionally, n8n's implementation has specific header requirements that aren't immediately obvious.

### What We Learned the Hard Way

1. **SSE requires specific proxy settings** - Standard nginx proxy configuration buffers responses, which breaks SSE streaming
2. **n8n MCP requires dual content type acceptance** - Requests must accept both `application/json` and `text/event-stream`
3. **Connection header must be empty** - Unlike WebSocket proxying which sets `Connection: Upgrade`, SSE needs an empty Connection header

## The Solution

Here's a complete working nginx configuration for n8n MCP servers:

```nginx
server {
    listen 443 ssl http2;
    server_name n8n.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # MCP Server Trigger endpoints - requires SSE support
    location ~ ^/mcp/ {
        proxy_pass http://127.0.0.1:5678;

        # Essential SSE configuration
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_set_header Connection "";
        chunked_transfer_encoding off;

        # n8n MCP specific: Accept header requirement
        proxy_set_header Accept "application/json, text/event-stream";

        # Increase timeouts for long-lived SSE connections (24 hours)
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;

        # Standard proxy headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Regular n8n endpoints (webhooks, UI, API)
    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_http_version 1.1;

        # WebSocket support for UI
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;

        # Standard proxy headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Required for WebSocket connection upgrade
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}
```

### NixOS Configuration Example

If you're using NixOS, here's the equivalent configuration:

```nix
services.nginx.virtualHosts."n8n.example.com" = {
  forceSSL = true;
  useACMEHost = "example.com";

  # MCP Server Trigger endpoints with SSE support
  locations."~ ^/mcp/" = {
    proxyPass = "http://127.0.0.1:5678";
    extraConfig = ''
      # n8n MCP requires this Accept header for both GET and POST requests
      proxy_set_header Accept "application/json, text/event-stream";

      # SSE (Server-Sent Events) configuration for MCP endpoints
      proxy_http_version 1.1;
      proxy_buffering off;
      proxy_set_header Connection "";
      chunked_transfer_encoding off;

      # Increase timeouts for long-lived SSE connections
      proxy_read_timeout 86400s;
      proxy_send_timeout 86400s;
    '';
  };

  # All other endpoints
  locations."/" = {
    proxyPass = "http://127.0.0.1:5678";
    proxyWebsockets = true;
  };
};
```

## Understanding the Configuration

Let's break down the critical parts:

### SSE Configuration

```nginx
proxy_http_version 1.1;
proxy_buffering off;
proxy_set_header Connection "";
chunked_transfer_encoding off;
```

- **`proxy_http_version 1.1`**: SSE requires HTTP/1.1 for persistent connections
- **`proxy_buffering off`**: Critical - nginx must not buffer SSE streams
- **`proxy_set_header Connection ""`**: SSE needs an empty Connection header (not `Upgrade` like WebSockets)
- **`chunked_transfer_encoding off`**: Prevents chunking issues with SSE streams

### n8n-Specific Requirements

```nginx
proxy_set_header Accept "application/json, text/event-stream";
```

n8n's MCP implementation validates the Accept header and rejects requests that don't include both content types. The error message you'll see without this header is:

```
Not Acceptable: Client must accept both application/json and text/event-stream
```

### Timeouts

```nginx
proxy_read_timeout 86400s;
proxy_send_timeout 86400s;
```

MCP connections can be long-lived. Setting 24-hour timeouts ensures the connection doesn't get terminated prematurely. Adjust based on your needs.

## Testing Your Configuration

### 1. Test SSE Connection

```bash
curl -H "Accept: text/event-stream" \
     -H "Authorization: Bearer YOUR_TOKEN" \
     https://n8n.example.com/mcp/YOUR_WORKFLOW_ID
```

You should see a `Content-Type: text/event-stream` header in the response.

### 2. Test JSON-RPC

```bash
curl -X POST \
     -H "Content-Type: application/json" \
     -H "Accept: application/json, text/event-stream" \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -d '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}' \
     https://n8n.example.com/mcp/YOUR_WORKFLOW_ID
```

### 3. Test with Claude Code

Add the MCP server to Claude Code:

```bash
claude mcp add -t sse n8n https://n8n.example.com/mcp/YOUR_WORKFLOW_ID
```

Then manually add authentication headers to `~/.claude.json`:

```json
{
  "projects": {
    "/path/to/project": {
      "mcpServers": {
        "n8n": {
          "type": "sse",
          "url": "https://n8n.example.com/mcp/YOUR_WORKFLOW_ID",
          "headers": {
            "Authorization": "Bearer YOUR_TOKEN"
          }
        }
      }
    }
  }
}
```

## Common Pitfalls

### 1. Missing Accept Header

Without the dual Accept header, you'll see:
```
Error: Unexpected token '<', "<!DOCTYPE "... is not valid JSON
```

This happens because n8n returns an HTML error page that gets parsed as JSON.

### 2. Proxy Buffering Enabled

If buffering is enabled, the SSE connection will appear to hang or timeout. Always set `proxy_buffering off` for SSE endpoints.

### 3. Short Timeouts

Default nginx timeouts (60s) will kill long-lived MCP connections. Always increase read/send timeouts for SSE endpoints.

## Troubleshooting

### SSE Not Working

Test directly without nginx:

```bash
curl -H "Accept: text/event-stream" http://127.0.0.1:5678/mcp/YOUR_WORKFLOW_ID
```

If this works but nginx doesn't, check your SSE configuration.

### Workflow Not Active

n8n's MCP endpoints only work when the workflow is active. Check in the n8n UI that your workflow with the MCP Server Trigger is activated (toggle in top-right corner).

## Performance Tuning

For production deployments with many concurrent MCP connections:

```nginx
# Increase worker connections
events {
    worker_connections 4096;
}

# Optimize file descriptor limits
worker_rlimit_nofile 8192;

# Enable keepalive to upstream
upstream n8n {
    server 127.0.0.1:5678;
    keepalive 32;
}

server {
    # Use upstream instead of direct proxy_pass
    location ~ ^/mcp/ {
        proxy_pass http://n8n;
        # ... rest of config
    }
}
```

## Conclusion

Setting up n8n MCP servers behind nginx requires understanding both SSE protocol requirements and n8n's specific implementation details. The key takeaways:

1. SSE needs `proxy_buffering off`, HTTP/1.1, and an empty Connection header
2. n8n MCP requires the Accept header to include both `application/json` and `text/event-stream`
3. Long timeouts are essential for persistent MCP connections
4. Separate MCP endpoints from regular n8n traffic for better control

With this configuration, you can safely expose n8n workflows as MCP tools that AI assistants like Claude Code can discover and use.

## References

- [Model Context Protocol Specification](https://spec.modelcontextprotocol.io/)
- [n8n MCP Server Trigger Documentation](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-langchain.mcptrigger/)
- [Nginx SSE Configuration](https://www.nginx.com/blog/event-driven-data-management-nginx/)
- [Server-Sent Events on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events)
