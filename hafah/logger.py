import os
import sys
import logging

LOG_LEVEL = logging.DEBUG if 'DEBUG' in os.environ else logging.INFO
LOG_FORMAT = "%(asctime)-15s - %(name)s - %(levelname)s - %(message)s"
MAIN_LOG_PATH = "ah.log"

def get_logger(*, module_name : str) -> logging.Logger:
    logger = logging.getLogger(module_name)
    logger.setLevel(LOG_LEVEL)

    ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(LOG_LEVEL)
    ch.setFormatter(logging.Formatter(LOG_FORMAT))

    fh = logging.FileHandler(MAIN_LOG_PATH)
    fh.setLevel(LOG_LEVEL)
    fh.setFormatter(logging.Formatter(LOG_FORMAT))

    if not logger.hasHandlers():
        logger.addHandler(ch)
        logger.addHandler(fh)

    return logger
