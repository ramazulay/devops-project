#!/usr/bin/env python3
"""
Main entry point that starts both the health check server and the processor.
"""

import logging
from health import start_health_server
from processor import main

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

if __name__ == '__main__':
    # Start health check server
    start_health_server(port=8080)
    logger.info("Health check endpoint available at http://localhost:8080/health")
    
    # Start the main processor
    main()
