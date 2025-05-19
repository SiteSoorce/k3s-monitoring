#!/bin/bash
for file in $(find . -type f); do
  echo "📄 $file"
  echo "-------------------------"
  cat "$file"
  printf "\n\n"
done
