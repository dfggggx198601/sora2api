"""Application launcher script"""
import uvicorn
from src.core.config import config

import os

if __name__ == "__main__":
    # Cloud Run requires listening on 0.0.0.0 and specific PORT
    host = os.environ.get("HOST", "0.0.0.0")
    port = int(os.environ.get("PORT", config.server_port))
    
    uvicorn.run(
        "src.main:app",
        host=host,
        port=port,
        reload=False
    )

