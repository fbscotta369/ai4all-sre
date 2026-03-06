#!/usr/bin/env python3
import subprocess
import yaml
import sys
import os

def get_conda_dependencies():
    """Exports the current conda environment and returns dependencies."""
    try:
        result = subprocess.run(['conda', 'env', 'export'], capture_output=True, text=True, check=True)
        return yaml.safe_load(result.stdout)
    except Exception as e:
        print(f"Error exporting conda environment: {e}")
        # Fallback to environment.yml if it exists
        if os.path.exists('environment.yml'):
            with open('environment.yml', 'r') as f:
                return yaml.safe_load(f)
        return None

def generate_markdown_table(data):
    """Converts conda dependency data into a Markdown table."""
    if not data or 'dependencies' not in data:
        return "No dependencies found."

    table = "| Package | Version | Channel |\n"
    table += "|---------|---------|---------|\n"

    for dep in data['dependencies']:
        if isinstance(dep, str):
            # Format: package=version or just package
            parts = dep.split('=')
            name = parts[0]
            version = parts[1] if len(parts) > 1 else "latest"
            channel = "conda-forge" if "conda-forge" in data.get('channels', []) else "default"
            table += f"| {name} | {version} | {channel} |\n"
        elif isinstance(dep, dict) and 'pip' in dep:
            for pip_dep in dep['pip']:
                parts = pip_dep.split('==')
                name = parts[0]
                version = parts[1] if len(parts) > 1 else "latest"
                table += f"| {name} | {version} | pip |\n"
    
    return table

def main():
    data = get_conda_dependencies()
    if data:
        table = generate_markdown_table(data)
        output_path = 'docs/reference/dependencies.md'
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        with open(output_path, 'w') as f:
            f.write("# Environment Dependencies\n\n")
            f.write("This table is automatically generated from the Conda environment used for training and development.\n\n")
            f.write(table)
        print(f"Successfully generated {output_path}")
    else:
        print("Failed to generate dependency table.")

if __name__ == "__main__":
    main()
