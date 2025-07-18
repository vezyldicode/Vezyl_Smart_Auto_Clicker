import requests
import os
import webbrowser
import tkinter as tk
from tkinter import messagebox

def get_local_version():
    try:
        with open(os.path.join('resources', 'version'), 'r', encoding='utf-8') as f:
            return f.read().strip()
    except Exception:
        return None

def get_github_version():
    url = 'https://raw.githubusercontent.com/vezyldicode/Vezyl_Smart_Auto_Clicker/main/resources/version'
    try:
        resp = requests.get(url, timeout=5)
        if resp.status_code == 200:
            return resp.text.strip()
    except Exception:
        pass
    return None

def main():
    local_version = get_local_version()
    github_version = get_github_version()
    if not local_version or not github_version:
        return
    if local_version != github_version:
        root = tk.Tk()
        root.withdraw()
        answer = messagebox.askyesno(
            'Update Available',
            f'A new version ({github_version}) is available!\nCurrent version: {local_version}\nDo you want to open the repository to update?'
        )
        if answer:
            webbrowser.open('https://github.com/vezyldicode/Vezyl_Smart_Auto_Clicker')
        root.destroy()

if __name__ == '__main__':
    main()
