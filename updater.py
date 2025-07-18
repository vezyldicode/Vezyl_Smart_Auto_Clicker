import requests
import os
import webbrowser

# Bọc import tkinter vào try/except
try:
    import tkinter as tk
    from tkinter import messagebox
    from tkinter import simpledialog
    from tkinter import ttk
    TKINTER_AVAILABLE = True
except ImportError:
    TKINTER_AVAILABLE = False
import ctypes
import winreg

DEFAULT_REPO = 'vezyldicode/Vezyl_Smart_Auto_Clicker'  # Thay đổi repo mặc định tại đây nếu cần

APP_NAME = 'Smart_Auto_Clicker'
DEV_PASSWORD = 'vezyl2025'  # Đổi mật khẩu tại đây nếu muốn
REGISTRY_PATH = 'VEZYL_SOFTWARE'
TMP_UPDATE_DIR = 'tmp_update'
UPDATER_EXE_NAME = 'updater.exe'
ZIP_CHUNK_SIZE = 8192
LOCAL_VERSION_PATH = os.path.join('resources', 'version')

# Dictionary for all messagebox texts
MSG = {
    'saved': 'Config updated!\nRegistry: Software\\{reg_path}\\{app_name}',
    'registry_error': 'Could not save to registry: {error}',
    'wrong_password': 'Wrong password!',
    'no_repo': 'không tìm thấy bản cập nhật',
    'no_version': 'Không tìm thấy phiên bản hiện tại',
    'update_available': 'A new version ({github_version}) is available!\nCurrent version: {local_version}\nDo you want to download and update automatically?',
    'no_zip': 'No .zip file found in latest release.',
    'update_done': 'Update completed!',
    'extract_error': 'Extracted folder not found: {src_dir}',
    'update_failed': 'Update failed: {error}'
}

def get_repo_from_registry():
    try:
        reg_key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, f'Software\\{REGISTRY_PATH}')
        repo_url, _ = winreg.QueryValueEx(reg_key, APP_NAME)
        winreg.CloseKey(reg_key)
        return repo_url
    except Exception:
        # Nếu không tìm thấy registry, dùng giá trị hardcode
        hardcoded_repo = DEFAULT_REPO  # Thay đổi repo mặc định tại đây nếu cần
        try:
            reg_key = winreg.CreateKey(winreg.HKEY_CURRENT_USER, f'Software\\{REGISTRY_PATH}')
            winreg.SetValueEx(reg_key, APP_NAME, 0, winreg.REG_SZ, hardcoded_repo)
            winreg.CloseKey(reg_key)
        except Exception:
            pass
        return hardcoded_repo


def get_local_version():
    try:
        with open(LOCAL_VERSION_PATH, 'r', encoding='utf-8') as f:
            return f.read().strip()
    except Exception:
        return None

def get_github_version(repo_url):
    try:
        version_url = f'https://raw.githubusercontent.com/{repo_url}/refs/heads/main/resources/version'
        resp = requests.get(version_url, timeout=5)
        if resp.status_code == 200:
            return resp.text.strip()
    except Exception:
        pass
    return None

def main():
    # Kiểm tra quyền admin
    is_admin = False
    try:
        is_admin = ctypes.windll.shell32.IsUserAnAdmin()
    except Exception:
        pass

    if is_admin:
        if not TKINTER_AVAILABLE:
            print('Dev mode yêu cầu Tkinter. Vui lòng cài đặt Tkinter hoặc dùng Python đầy đủ.')
            return
        # Dev mode: nhập mật khẩu
        root = tk.Tk()
        root.withdraw()
        repo_url = get_repo_from_registry()
        pwd = simpledialog.askstring('Dev Mode', 'Enter developer password:', show='*')
        if pwd == DEV_PASSWORD:
            # Hiển thị GUI chỉnh sửa app name và github repo
            dev_win = tk.Toplevel()
            dev_win.title('Dev Mode - Edit Config')
            tk.Label(dev_win, text='App Name:').grid(row=0, column=0, padx=10, pady=5)
            app_name_var = tk.StringVar(value=APP_NAME)
            tk.Entry(dev_win, textvariable=app_name_var, width=40).grid(row=0, column=1, padx=10, pady=5)
            tk.Label(dev_win, text='GitHub Repo URL:').grid(row=1, column=0, padx=10, pady=5)
            repo_var = tk.StringVar(value=repo_url if repo_url else '')
            tk.Entry(dev_win, textvariable=repo_var, width=40).grid(row=1, column=1, padx=10, pady=5)
            def save_config():
                global APP_NAME
                APP_NAME = app_name_var.get()
                new_repo = repo_var.get()
                # Lưu vào Windows Registry
                try:
                    reg_key = winreg.CreateKey(winreg.HKEY_CURRENT_USER, f'Software\\{REGISTRY_PATH}')
                    winreg.SetValueEx(reg_key, APP_NAME, 0, winreg.REG_SZ, new_repo)
                    winreg.CloseKey(reg_key)
                    messagebox.showinfo('Saved', MSG['saved'].format(reg_path=REGISTRY_PATH, app_name=APP_NAME))
                except Exception as e:
                    messagebox.showerror('Registry Error', MSG['registry_error'].format(error=e))
            tk.Button(dev_win, text='Save', command=save_config).grid(row=2, column=0, columnspan=2, pady=10)
            dev_win.mainloop()
        else:
            messagebox.showerror('Error', MSG['wrong_password'])
        root.destroy()
        return

    repo_url = get_repo_from_registry()
    if not repo_url:
        if TKINTER_AVAILABLE:
            root = tk.Tk()
            root.withdraw()
            messagebox.showerror('Error', MSG['no_repo'].format(reg_path=REGISTRY_PATH, app_name=APP_NAME))
            root.destroy()
        else:
            print(MSG['no_repo'].format(reg_path=REGISTRY_PATH, app_name=APP_NAME))
        return
    local_version = get_local_version()
    github_version = get_github_version(repo_url)
    if not local_version or not github_version:
        if TKINTER_AVAILABLE:
            root = tk.Tk()
            root.withdraw()
            messagebox.showerror('Error', MSG['no_version'])
            root.destroy()
        else:
            print(MSG['no_version'])
        return
    if local_version != github_version:
        if TKINTER_AVAILABLE:
            root = tk.Tk()
            root.withdraw()
            answer = messagebox.askyesno(
                APP_NAME + ' Update Available',
                MSG['update_available'].format(github_version=github_version, local_version=local_version)
            )
        else:
            print(MSG['update_available'].format(github_version=github_version, local_version=local_version))
            # Không có console, tự động cập nhật luôn
            answer = True
        if answer:
            # Đóng app_name.exe nếu đang chạy
            def kill_app_exe(app_name):
                import psutil
                exe_name = app_name + '.exe'
                for proc in psutil.process_iter(['name']):
                    try:
                        if proc.info['name'] and proc.info['name'].lower() == exe_name.lower():
                            proc.kill()
                    except Exception:
                        pass

            try:
                import psutil
            except ImportError:
                import subprocess
                subprocess.check_call(["pip", "install", "psutil"])
                import psutil

            kill_app_exe(APP_NAME)

            if TKINTER_AVAILABLE:
                # Tạo cửa sổ loading
                loading_win = tk.Toplevel()
                loading_win.title('Updating...')
                loading_win.geometry('350x80')
                tk.Label(loading_win, text='Đang cập nhật, vui lòng chờ...').pack(pady=10)
                progress = tk.IntVar(value=0)
                progress_bar = tk.ttk.Progressbar(loading_win, orient='horizontal', length=300, mode='indeterminate')
                progress_bar.pack(pady=10)
                progress_bar.start(10)
                loading_win.update()
            try:
                release_api = f'https://api.github.com/repos/{repo_url}/releases/latest'
                resp = requests.get(release_api, timeout=10)
                data = resp.json()
                zip_url = None
                zip_name = None
                for asset in data.get('assets', []):
                    if asset['name'].endswith('.zip'):
                        zip_url = asset['browser_download_url']
                        zip_name = asset['name']
                        break
                if not zip_url or not zip_name:
                    if TKINTER_AVAILABLE:
                        progress_bar.stop()
                        loading_win.destroy()
                        messagebox.showerror('Error', MSG['no_zip'])
                        root.destroy()
                    else:
                        print(MSG['no_zip'])
                    return
                # Tải về thư mục tmp_update
                os.makedirs(TMP_UPDATE_DIR, exist_ok=True)
                zip_path = os.path.join(TMP_UPDATE_DIR, zip_name)
                with requests.get(zip_url, stream=True) as r:
                    r.raise_for_status()
                    with open(zip_path, 'wb') as f:
                        for chunk in r.iter_content(chunk_size=ZIP_CHUNK_SIZE):
                            f.write(chunk)
                # Giải nén
                import zipfile
                with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                    zip_ref.extractall(TMP_UPDATE_DIR)
                # Xóa updater.exe nếu có
                updater_exe = os.path.join(TMP_UPDATE_DIR, UPDATER_EXE_NAME)
                if os.path.exists(updater_exe):
                    try:
                        os.remove(updater_exe)
                    except Exception:
                        pass
                # Copy toàn bộ file và thư mục con bên trong thư mục con (tên file zip) ra thư mục gốc, ghi đè
                import shutil
                zip_folder_name = os.path.splitext(zip_name)[0]
                src_dir = os.path.join(TMP_UPDATE_DIR, zip_folder_name)
                dst_dir = os.getcwd()
                if os.path.isdir(src_dir):
                    for item in os.listdir(src_dir):
                        s = os.path.join(src_dir, item)
                        d = os.path.join(dst_dir, item)
                        if os.path.isdir(s):
                            shutil.copytree(s, d, dirs_exist_ok=True)
                        else:
                            shutil.copy2(s, d)
                    # Xóa toàn bộ thư mục tmp_update sau khi update xong
                    try:
                        shutil.rmtree(TMP_UPDATE_DIR)
                    except Exception:
                        pass
                    if TKINTER_AVAILABLE:
                        progress_bar.stop()
                        loading_win.destroy()
                        # Hiển thị thông báo thành công trong 3 giây, sau đó chạy app và đóng updater
                        success_win = tk.Toplevel()
                        success_win.title('Update')
                        success_win.geometry('350x80')
                        tk.Label(success_win, text=MSG['update_done']).pack(pady=20)
                        success_win.update()
                        def run_and_exit():
                            success_win.destroy()
                            launch_app_and_exit()
                        success_win.after(3000, run_and_exit)
                        success_win.mainloop()
                    else:
                        print(MSG['update_done'])
                        launch_app_and_exit()
                else:
                    if TKINTER_AVAILABLE:
                        progress_bar.stop()
                        loading_win.destroy()
                        messagebox.showerror('Error', MSG['extract_error'].format(src_dir=src_dir))
                    else:
                        print(MSG['extract_error'].format(src_dir=src_dir))
            except Exception as e:
                if TKINTER_AVAILABLE:
                    progress_bar.stop()
                    loading_win.destroy()
                    messagebox.showerror('Error', MSG['update_failed'].format(error=e))
                else:
                    print(MSG['update_failed'].format(error=e))
        if TKINTER_AVAILABLE:
            root.destroy()

def launch_app_and_exit():
    import subprocess
    import sys
    exe_name = APP_NAME + '.exe'
    exe_path = os.path.join(os.getcwd(), exe_name)
    try:
        subprocess.Popen([exe_path])
    except Exception:
        pass
    sys.exit(0)

if __name__ == '__main__':
    main()
