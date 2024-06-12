from flask import Flask, request, jsonify
from pathlib import Path
import subprocess
import yaml
import os 


# Load the YAML project config file
current_dir = Path(__file__).resolve().parent
config_file = current_dir / 'server_settings.yml'

with config_file.open('r') as file:
    config = yaml.safe_load(file)

WEBHOOK_HOST = config.get('webhook_host', '0.0.0.0')
WEBHOOK_PORT = config.get('webhook_port', 5000)

app = Flask(__name__)

repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
deploy_script_path = os.path.join(repo_root, 'server', 'deploy.sh')

@app.route('/webhook', methods=['POST'])
def webhook():
    data = request.json
    if data['ref'].startswith('refs/heads/'):
        branch = data['ref'].split('/')[-1]
        subprocess.Popen(['/bin/bash', deploy_script_path, branch], cwd=repo_root)
    return jsonify(success=True), 200
    
if __name__ == '__main__':
    app.run(host=WEBHOOK_HOST, port=WEBHOOK_PORT)