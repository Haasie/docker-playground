from setuptools import setup, find_packages

setup(
    name="challenge-cli",
    version="0.1.0",
    packages=find_packages(),
    install_requires=[
        "requests>=2.25.0",
        "click>=8.0.0",
        "colorama>=0.4.4",
        "tabulate>=0.8.9"
    ],
    entry_points={
        "console_scripts": [
            "challenge-cli=challenge_cli.cli:main",
        ],
    },
)
