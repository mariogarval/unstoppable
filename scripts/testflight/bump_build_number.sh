#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT_FILE="${PROJECT_FILE:-$ROOT_DIR/Unstoppable.xcodeproj/project.pbxproj}"
APP_STORE_CONNECT_APP_ID="${APP_STORE_CONNECT_APP_ID:-6759273918}"
API_KEY_ID="${APP_STORE_CONNECT_API_KEY_ID:-}"
API_ISSUER_ID="${APP_STORE_CONNECT_API_ISSUER_ID:-}"
API_KEY_PATH="${APP_STORE_CONNECT_API_KEY_PATH:-}"

current_build="$(grep -Eo 'CURRENT_PROJECT_VERSION = [0-9]+' "$PROJECT_FILE" | head -n 1 | awk '{print $3}')"

if [[ -z "${current_build:-}" ]]; then
  echo "Could not determine CURRENT_PROJECT_VERSION from $PROJECT_FILE" >&2
  exit 1
fi

if [[ -z "$API_KEY_ID" ]]; then
  echo "Missing APP_STORE_CONNECT_API_KEY_ID" >&2
  exit 1
fi

if [[ -z "$API_ISSUER_ID" ]]; then
  echo "Missing APP_STORE_CONNECT_API_ISSUER_ID" >&2
  exit 1
fi

if [[ -z "$API_KEY_PATH" ]]; then
  API_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${API_KEY_ID}.p8"
fi

if [[ ! -f "$API_KEY_PATH" ]]; then
  echo "API key file not found at $API_KEY_PATH" >&2
  exit 1
fi

export APP_STORE_CONNECT_APP_ID
export APP_STORE_CONNECT_API_KEY_ID="$API_KEY_ID"
export APP_STORE_CONNECT_API_ISSUER_ID="$API_ISSUER_ID"
export APP_STORE_CONNECT_API_KEY_PATH="$API_KEY_PATH"

# Query App Store Connect so the next uploaded build always follows the highest
# numeric build Apple has indexed, rather than the local project file.
latest_uploaded_build="$(
  ruby -ropenssl -rbase64 -rjson -rnet/http -ruri -e '
def b64(value)
  Base64.urlsafe_encode64(value, padding: false)
end

key_id = ENV.fetch("APP_STORE_CONNECT_API_KEY_ID")
issuer_id = ENV.fetch("APP_STORE_CONNECT_API_ISSUER_ID")
key_path = ENV.fetch("APP_STORE_CONNECT_API_KEY_PATH")
app_id = ENV.fetch("APP_STORE_CONNECT_APP_ID")

key = OpenSSL::PKey.read(File.read(key_path))
header_json = JSON.generate({ alg: "ES256", kid: key_id, typ: "JWT" })
now = Time.now.to_i
payload_json = JSON.generate({ iss: issuer_id, iat: now, exp: now + 1200, aud: "appstoreconnect-v1" })
signing_input = "#{b64(header_json)}.#{b64(payload_json)}"

der_signature = key.sign("SHA256", signing_input)
sequence = OpenSSL::ASN1.decode(der_signature)
r = sequence.value[0].value.to_s(2).rjust(32, "\x00")
s = sequence.value[1].value.to_s(2).rjust(32, "\x00")
jwt = "#{signing_input}.#{b64(r + s)}"

http = Net::HTTP.new("api.appstoreconnect.apple.com", 443)
http.use_ssl = true

next_url = URI("https://api.appstoreconnect.apple.com/v1/builds?" + URI.encode_www_form(
  "filter[app]" => app_id,
  "sort" => "-uploadedDate",
  "limit" => "200",
  "fields[builds]" => "version,uploadedDate,processingState"
))
highest_version = 0

while next_url
  request = Net::HTTP::Get.new(next_url)
  request["Authorization"] = "Bearer #{jwt}"
  response = http.request(request)

  unless response.is_a?(Net::HTTPSuccess)
    warn "App Store Connect build lookup failed: HTTP #{response.code}"
    warn response.body
    exit 1
  end

  payload = JSON.parse(response.body)
  builds = payload.fetch("data")

  builds.each do |build|
    version = build.fetch("attributes").fetch("version")
    unless version.match?(/\A\d+\z/)
      warn "Encountered non-numeric App Store Connect build version: #{version}"
      exit 1
    end

    version_number = version.to_i
    highest_version = version_number if version_number > highest_version
  end

  next_link = payload.fetch("links", {}).fetch("next", nil)
  next_url = next_link.nil? || next_link.empty? ? nil : URI(next_link)
end

puts highest_version
'
)"

next_build=$((latest_uploaded_build + 1))

perl -0pi -e "s/CURRENT_PROJECT_VERSION = ${current_build};/CURRENT_PROJECT_VERSION = ${next_build};/g" "$PROJECT_FILE"

echo "Build number bumped from local ${current_build} to ${next_build} using App Store Connect latest ${latest_uploaded_build}"
