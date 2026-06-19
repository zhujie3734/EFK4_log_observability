#!/bin/bash
cat > /etc/fluent-bit/scripts/container_map.lua.tmp <<'EOF'
return {
EOF

docker ps --no-trunc --format '{{.ID}}|{{.Names}}|{{.Image}}' | while IFS='|' read -r id name image; do
  safe_name=$(echo "$name" | sed 's/[^a-zA-Z0-9_.-]/_/g')
  safe_image=$(echo "$image" | sed 's/["\\]/_/g')
  echo "  [\"$id\"] = { container_name = \"$safe_name\", service_name = \"$safe_name\", image_name = \"$safe_image\", env = \"prod\" }," >> /etc/fluent-bit/scripts/container_map.lua.tmp
done

cat >> /etc/fluent-bit/scripts/container_map.lua.tmp <<'EOF'
}
EOF

mv /etc/fluent-bit/scripts/container_map.lua.tmp /etc/fluent-bit/scripts/container_map.lua