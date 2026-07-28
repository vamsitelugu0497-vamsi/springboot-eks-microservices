#!/usr/bin/env bash
#
# load-test.sh - Simple HTTP load test against the microservices, using k6 if
# available, falling back to Apache Bench (ab).
#
# Usage:
#   ./load-test.sh [BASE_URL] [DURATION] [VUS]
#
#   BASE_URL  Base URL of the ingress (default: http://localhost:8080)
#   DURATION  Test duration, e.g. 30s, 2m (default: 60s)
#   VUS       Virtual users / concurrency (default: 20)

set -euo pipefail

BASE_URL="${1:-http://localhost:8080}"
DURATION="${2:-60s}"
VUS="${3:-20}"

echo "=== Load testing ${BASE_URL} for ${DURATION} with ${VUS} VUs ==="

if command -v k6 >/dev/null 2>&1; then
  cat > /tmp/load-test.js <<K6EOF
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: ${VUS},
  duration: '${DURATION}',
  thresholds: {
    http_req_duration: ['p(95)<800'],
    http_req_failed: ['rate<0.01'],
  },
};

const BASE_URL = '${BASE_URL}';

export default function () {
  const endpoints = [
    '/api/v1/users',
    '/api/v1/products',
    '/api/v1/orders',
  ];
  const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];

  const res = http.get(\`\${BASE_URL}\${endpoint}\`);
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 1s': (r) => r.timings.duration < 1000,
  });

  sleep(1);
}
K6EOF
  k6 run /tmp/load-test.js
else
  echo "k6 not found, falling back to Apache Bench (ab)."
  if ! command -v ab >/dev/null 2>&1; then
    echo "Neither k6 nor ab is installed. Install one of them and retry." >&2
    echo "  k6:  https://k6.io/docs/get-started/installation/" >&2
    echo "  ab:  apt-get install apache2-utils" >&2
    exit 1
  fi

  REQUESTS=$(( VUS * 100 ))
  for path in /api/v1/users /api/v1/products /api/v1/orders; do
    echo "--- ${path} ---"
    ab -n "${REQUESTS}" -c "${VUS}" "${BASE_URL}${path}"
  done
fi

echo "=== Load test complete ==="
