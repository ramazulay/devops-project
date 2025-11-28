#!/usr/bin/env python3
"""
Health check endpoint for the SQS processor.
Simple HTTP server that returns health status.
"""

import json
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading
import logging

logger = logging.getLogger(__name__)

# Import health_status from processor
import sys
sys.path.append('/app')


class HealthCheckHandler(BaseHTTPRequestHandler):
    """HTTP handler for health check endpoint."""
    
    def do_GET(self):
        """Handle GET requests."""
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            try:
                from processor import health_status
                response = {
                    'status': health_status.get('status', 'unknown'),
                    'last_poll': health_status.get('last_poll'),
                    'messages_processed': health_status.get('messages_processed', 0)
                }
                self.wfile.write(json.dumps(response).encode())
            except Exception as e:
                self.wfile.write(json.dumps({'status': 'error', 'message': str(e)}).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        """Suppress default logging."""
        pass


def start_health_server(port=8080):
    """Start the health check HTTP server in a separate thread."""
    server = HTTPServer(('', port), HealthCheckHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    logger.info(f"Health check server started on port {port}")
    return server
