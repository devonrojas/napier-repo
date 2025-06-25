################################################################################
### Authors: Devon Rojas, Christina Mazilu, Katelyn Nutley, Aliah Zewail, Tod Van Gunten
### Date created: Jun 4, 2025
### Project: Highland Clearances
################################################################################

import os
from dotenv import load_dotenv
load_dotenv()

# Make file directories if doesn't exist
if os.path.exists(os.getenv("DATA_DIR")): os.makedirs(os.getenv("DATA_DIR"), exist_ok=True)
if os.path.exists(os.getenv("RAW_DATA_DIR")): os.makedirs(os.getenv("RAW_DATA_DIR"), exist_ok=True)
if os.path.exists(os.getenv("OUTPUT_DATA_DIR")): os.makedirs(os.getenv("OUTPUT_DATA_DIR"), exist_ok=True)
if os.path.exists(os.getenv("INPUT_DATA_DIR")): os.makedirs(os.getenv("INPUT_DATA_DIR"), exist_ok=True)
if os.path.exists(os.getenv("FIGURES_DIR")): os.makedirs(os.getenv("FIGURES_DIR"), exist_ok=True)