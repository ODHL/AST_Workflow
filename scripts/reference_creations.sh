#!/bin/bash

# Define the output file
output_file='241011_kleb.csv'

# Print the header to the output file
echo -e "OHIOID,SPECIES,PROJECTID,WGSID,SRRID" > "$output_file"

# Loop through all reports.csv files in the specified directory structure
for input_file in //LABAUTHDC2/Shared/Micro/WGS/AR\ WGS/projects/*/analysis/reports.csv; do
    if [[ -f "$input_file" ]]; then
        # Use awk to filter the input file and append results to the output file
        awk -F'\t' '/Klebsiella/ {
            # Print the required columns in the desired format
            printf "OHIOID,%s,OH-M5185-231215,%s,%s\n", $10, $2, $3
        }' "$input_file" >> "$output_file"
    else
        echo "No reports.csv found in $input_file"
    fi
done

echo "Filtered results saved to $output_file"
