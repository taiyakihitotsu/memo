#!/bin/bash

transform_file() {
    local input_file="$1"
    
    awk '
    BEGIN { 
        state = 0; 
        code_buffer = ""; 
    }
    
    # Start point of JSDoc
    /\/\*\*/ {
        if (state == 0 && code_buffer != "") {
            print "```typescript\n" code_buffer "```\n" ;
            code_buffer = "";
        }
        state = 1;
        # Remove the start mark /**
        sub(/.*\/\*\*/, "");
    }
    
    # End point of JSDoc
    /\*\// {
        if (state == 1) {
            # Remove the end mark */
            sub(/\*\/.*/, "");
            print $0 "\n";
            state = 0;
            next;
        }
    }
    
    # Each lines
    {
        if (state == 1) {
            print $0;
        } else {
            code_buffer = code_buffer $0 "\n";
        }
    }
    
    END {
        if (code_buffer != "") {
            print "```typescript\n" code_buffer "```";
        }
    }
    ' "$input_file"
}

generate_front_matter() {
    local input_file="$1"
    local filename=$(basename "$input_file")
    local title="${filename%.ts}"
    local current_date=$(date +"%Y-%m-%d %H:%M:%S")

    cat <<EOF
---
title: '${title}'
date: '${current_date}'
tags: '[typescript]'
author: 'taiyakihitotsu'
---
[Source]( https://github.com/taiyakihitotsu/memo/blob/main/src/${title}.ts )
EOF
}

process_directory() {
    local src_root="$1"
    local docs_root="$2"

    if [ ! -d "$src_root" ]; then
        echo "Error: Source directory '$src_root' not found."
        return 1
    fi

    find "$src_root" -type f -name "*.ts" | while read -r src_file; do
        relative_path="${src_file#$src_root/}"
        dest_file="$docs_root/${relative_path%.ts}.md"
        dest_dir=$(dirname "$dest_file")

        mkdir -p "$dest_dir"

        temp_file=$(mktemp)
        
        {
            generate_front_matter "$src_file"
            transform_file "$src_file"
            # echo -e "\n---\n[Source]( https://github.com/taiyakihitotsu/memo/blob/main/$src_file )"
        } > "$temp_file"

        if [ -f "$dest_file" ]; then
            if cmp -s <(tail -n +7 "$temp_file") <(tail -n +7 "$dest_file"); then
                echo "Skipped (no change): $src_file"
                rm "$temp_file"
                continue
            fi
        fi

        mv "$temp_file" "$dest_file"
        echo "Converted: $src_file -> $dest_file"
    done
}

SRC="src"
DOCS="docs"

process_directory "$SRC" "$DOCS"
