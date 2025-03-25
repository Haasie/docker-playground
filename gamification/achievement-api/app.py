from flask import Flask, request, jsonify
import os
import json
import uuid
from datetime import datetime
from azure.data.tables import TableServiceClient, UpdateMode
from azure.core.exceptions import ResourceExistsError

app = Flask(__name__)

# Configuration
STORAGE_CONNECTION_STRING = os.environ.get('AZURE_STORAGE_CONNECTION_STRING')
TABLE_NAME = os.environ.get('ACHIEVEMENT_TABLE_NAME', 'achievements')

# Use local storage if no Azure connection string is provided
USE_LOCAL_STORAGE = not STORAGE_CONNECTION_STRING
LOCAL_STORAGE_FILE = 'achievements.json'

# Initialize local storage if needed
if USE_LOCAL_STORAGE and not os.path.exists(LOCAL_STORAGE_FILE):
    with open(LOCAL_STORAGE_FILE, 'w') as f:
        json.dump([], f)


def get_table_client():
    """Get Azure Table Storage client"""
    if USE_LOCAL_STORAGE:
        return None
        
    table_service = TableServiceClient.from_connection_string(STORAGE_CONNECTION_STRING)
    
    # Create table if it doesn't exist
    try:
        table_service.create_table(TABLE_NAME)
    except ResourceExistsError:
        pass
    
    return table_service.get_table_client(table_name=TABLE_NAME)


def save_badge_local(username, badge_name, challenge_id):
    """Save badge to local storage"""
    with open(LOCAL_STORAGE_FILE, 'r') as f:
        badges = json.load(f)
    
    # Check if badge already exists
    for badge in badges:
        if badge['username'] == username and badge['badge_name'] == badge_name:
            return False
    
    # Add new badge
    badges.append({
        'id': str(uuid.uuid4()),
        'username': username,
        'badge_name': badge_name,
        'challenge_id': challenge_id,
        'earned_date': datetime.now().isoformat()
    })
    
    with open(LOCAL_STORAGE_FILE, 'w') as f:
        json.dump(badges, f, indent=2)
    
    return True


def get_badges_local(username):
    """Get badges from local storage"""
    with open(LOCAL_STORAGE_FILE, 'r') as f:
        badges = json.load(f)
    
    return [badge for badge in badges if badge['username'] == username]


def get_stats_local():
    """Get stats from local storage"""
    with open(LOCAL_STORAGE_FILE, 'r') as f:
        badges = json.load(f)
    
    unique_users = set(badge['username'] for badge in badges)
    
    return {
        'total_badges': len(badges),
        'total_users': len(unique_users)
    }


@app.route('/api/badges', methods=['POST'])
def create_badge():
    """Create a new badge for a user"""
    data = request.json
    
    if not data or not all(k in data for k in ['username', 'badge_name', 'challenge_id']):
        return jsonify({'message': 'Missing required fields'}), 400
    
    username = data['username']
    badge_name = data['badge_name']
    challenge_id = data['challenge_id']
    
    if USE_LOCAL_STORAGE:
        is_new = save_badge_local(username, badge_name, challenge_id)
        if is_new:
            return jsonify({'message': 'Badge created successfully'}), 201
        else:
            return jsonify({'message': 'Badge already exists'}), 200
    
    # Azure Table Storage implementation
    table_client = get_table_client()
    
    # Check if badge already exists
    filter_query = f"PartitionKey eq '{username}' and BadgeName eq '{badge_name}'"
    existing_badges = list(table_client.query_entities(filter_query))
    
    if existing_badges:
        return jsonify({'message': 'Badge already exists'}), 200
    
    # Create new badge entity
    entity = {
        'PartitionKey': username,
        'RowKey': str(uuid.uuid4()),
        'BadgeName': badge_name,
        'ChallengeId': challenge_id,
        'EarnedDate': datetime.now().isoformat()
    }
    
    table_client.create_entity(entity)
    
    return jsonify({'message': 'Badge created successfully'}), 201


@app.route('/api/badges/<username>', methods=['GET'])
def get_badges(username):
    """Get all badges for a user"""
    if USE_LOCAL_STORAGE:
        badges = get_badges_local(username)
        return jsonify(badges), 200
    
    # Azure Table Storage implementation
    table_client = get_table_client()
    
    filter_query = f"PartitionKey eq '{username}'"
    entities = table_client.query_entities(filter_query)
    
    badges = []
    for entity in entities:
        badges.append({
            'id': entity['RowKey'],
            'username': entity['PartitionKey'],
            'badge_name': entity['BadgeName'],
            'challenge_id': entity['ChallengeId'],
            'earned_date': entity['EarnedDate']
        })
    
    return jsonify(badges), 200


@app.route('/api/status', methods=['GET'])
def get_status():
    """Get system status"""
    if USE_LOCAL_STORAGE:
        stats = get_stats_local()
        return jsonify({
            'status': 'online',
            'version': '1.0.0',
            'storage': 'local',
            'total_badges': stats['total_badges'],
            'total_users': stats['total_users']
        }), 200
    
    # Azure Table Storage implementation
    table_client = get_table_client()
    
    # Count total badges
    all_entities = list(table_client.query_entities(''))
    unique_users = set(entity['PartitionKey'] for entity in all_entities)
    
    return jsonify({
        'status': 'online',
        'version': '1.0.0',
        'storage': 'azure',
        'total_badges': len(all_entities),
        'total_users': len(unique_users)
    }), 200


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5050))
    app.run(host='0.0.0.0', port=port)
