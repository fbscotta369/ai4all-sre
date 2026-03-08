#!/bin/bash

# ============================================================
#  DEPRECATION NOTICE
#  cleanup.sh has been deprecated to prevent accidental 
#  unprompted destruction of the laboratory.
#  
#  Redirecting to the safer destroy.sh script...
# ============================================================

echo -e "\033[1;33m⚠️  cleanup.sh is deprecated. Transferring to destroy.sh...\033[0m"
sleep 2

./destroy.sh "$@"
