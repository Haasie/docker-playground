#!/usr/bin/env python3

import os
import sys
import click
import requests
import json
from colorama import init, Fore, Style
from tabulate import tabulate

# Initialize colorama
init(autoreset=True)

# API endpoint
API_HOST = os.environ.get('ACHIEVEMENT_API_HOST', 'http://localhost:5050')


def get_username():
    """Get the current username"""
    if os.environ.get('USERNAME'):
        return os.environ.get('USERNAME')
    return os.environ.get('USER', 'unknown')


@click.group()
def cli():
    """Docker Challenge CLI - Unlock and manage your achievement badges"""
    pass


@cli.command('unlock-badge')
@click.argument('badge_name')
@click.argument('challenge_id')
def unlock_badge(badge_name, challenge_id):
    """Unlock a new badge for completing a challenge"""
    username = get_username()
    
    try:
        response = requests.post(
            f"{API_HOST}/api/badges",
            json={
                "username": username,
                "badge_name": badge_name,
                "challenge_id": challenge_id
            }
        )
        
        if response.status_code == 201:
            click.echo(f"\n{Fore.GREEN}🏆 Congratulations! Badge '{badge_name}' unlocked!{Style.RESET_ALL}")
            click.echo(f"\nYou can view all your badges with: {Fore.CYAN}challenge-cli list-badges{Style.RESET_ALL}")
        elif response.status_code == 200:
            click.echo(f"\n{Fore.YELLOW}You already have the '{badge_name}' badge.{Style.RESET_ALL}")
        else:
            click.echo(f"\n{Fore.RED}Error: {response.json().get('message', 'Unknown error')}{Style.RESET_ALL}")
    
    except requests.RequestException as e:
        click.echo(f"\n{Fore.RED}Error connecting to achievement API: {str(e)}{Style.RESET_ALL}")
        click.echo(f"\nMake sure the achievement API is running at {API_HOST}")


@cli.command('list-badges')
def list_badges():
    """List all badges you have earned"""
    username = get_username()
    
    try:
        response = requests.get(f"{API_HOST}/api/badges/{username}")
        
        if response.status_code == 200:
            badges = response.json()
            
            if not badges:
                click.echo(f"\n{Fore.YELLOW}You haven't earned any badges yet.{Style.RESET_ALL}")
                click.echo("\nComplete challenges to earn badges!")
                return
            
            # Prepare table data
            table_data = []
            for badge in badges:
                earned_date = badge.get('earned_date', 'Unknown')
                table_data.append([badge['badge_name'], badge['challenge_id'], earned_date])
            
            # Print table
            click.echo(f"\n{Fore.CYAN}Badges earned by {username}:{Style.RESET_ALL}\n")
            click.echo(tabulate(table_data, headers=["Badge", "Challenge", "Earned Date"], tablefmt="grid"))
        else:
            click.echo(f"\n{Fore.RED}Error: {response.json().get('message', 'Unknown error')}{Style.RESET_ALL}")
    
    except requests.RequestException as e:
        click.echo(f"\n{Fore.RED}Error connecting to achievement API: {str(e)}{Style.RESET_ALL}")
        click.echo(f"\nMake sure the achievement API is running at {API_HOST}")


@cli.command('status')
def status():
    """Check the status of the achievement system"""
    try:
        response = requests.get(f"{API_HOST}/api/status")
        
        if response.status_code == 200:
            status_data = response.json()
            click.echo(f"\n{Fore.GREEN}Achievement API Status:{Style.RESET_ALL}")
            click.echo(f"  Status: {Fore.GREEN}Online{Style.RESET_ALL}")
            click.echo(f"  Version: {status_data.get('version', 'Unknown')}")
            click.echo(f"  Total Badges: {status_data.get('total_badges', 0)}")
            click.echo(f"  Total Users: {status_data.get('total_users', 0)}")
        else:
            click.echo(f"\n{Fore.RED}Error: {response.json().get('message', 'Unknown error')}{Style.RESET_ALL}")
    
    except requests.RequestException as e:
        click.echo(f"\n{Fore.RED}Error connecting to achievement API: {str(e)}{Style.RESET_ALL}")
        click.echo(f"\nMake sure the achievement API is running at {API_HOST}")


def main():
    try:
        cli()
    except Exception as e:
        click.echo(f"\n{Fore.RED}Error: {str(e)}{Style.RESET_ALL}")
        sys.exit(1)


if __name__ == '__main__':
    main()
