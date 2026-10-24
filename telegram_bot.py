#!/usr/bin/env python3
import os
import sys

project_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "restaurant_system")
os.chdir(project_dir)
sys.path.insert(0, project_dir)

import telegram_bot

if __name__ == '__main__':
    telegram_bot.main()
