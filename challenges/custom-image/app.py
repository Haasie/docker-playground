from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/')
def home():
    # Read the build info file to get the username
    username = "unknown"
    if os.path.exists("/app/build_info.txt"):
        with open("/app/build_info.txt", "r") as f:
            build_info = f.read().strip()
            username = build_info.replace("Built by: ", "")
    
    return jsonify({
        "message": "Hello from custom image!",
        "status": "success",
        "built_by": username
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
