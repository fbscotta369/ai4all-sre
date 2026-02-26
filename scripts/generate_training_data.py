#!/usr/bin/env python3
import os
import json
import re

# Paths
POST_MORTEMS_DIR = "post-mortems"
OUTPUT_FILE = "ai-lab/fine-tuning/dataset_generated.jsonl"

def extract_qa_from_markdown(content):
    """
    Heuristic: Extract Analysis (Input) and RCA (Output) from our markdown template.
    """
    input_text = ""
    output_text = ""
    
    # Extract "Evidence / Context" or "Alert Details"
    context_match = re.search(r"## (Alert Details|Evidence / Context)\n(.*?)\n##", content, re.DOTALL)
    if context_match:
        input_text = context_match.group(2).strip()
    
    # Extract "RCA" or "Analysis"
    rca_match = re.search(r"## (AI Analysis & RCA|Root Cause Analysis)\n(.*?)\n##", content, re.DOTALL)
    if rca_match:
        output_text = rca_match.group(2).strip()
    
    return input_text, output_text

def main():
    print(f"[*] Generating training dataset from {POST_MORTEMS_DIR}...")
    dataset = []
    
    if not os.path.exists(POST_MORTEMS_DIR):
        print(f"⚠️ Warning: {POST_MORTEMS_DIR} not found. Using defaults.")
        return

    for filename in os.listdir(POST_MORTEMS_DIR):
        if filename.endswith(".md"):
            with open(os.path.join(POST_MORTEMS_DIR, filename), "r") as f:
                content = f.read()
                inp, outp = extract_qa_from_markdown(content)
                if inp and outp:
                    dataset.append({"input": inp[:1000], "output": outp[:1000]})
    
    if dataset:
        with open(OUTPUT_FILE, "w") as f:
            for entry in dataset:
                f.write(json.dumps(entry) + "\n")
        print(f"✅ Generated {len(dataset)} training examples in {OUTPUT_FILE}")
    else:
        print("❌ No valid training pairs found in post-mortems.")

if __name__ == "__main__":
    main()
