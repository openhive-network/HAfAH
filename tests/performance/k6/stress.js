// Stress test: push the API beyond normal load to find breaking points
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';
import { BASE_URL, headers, TEST_DATA } from './config.js';

const errorRate = new Rate('errors');
const MAX_VUS = parseInt(__ENV.MAX_VUS || '100');

export const options = {
  stages: [
    { duration: '30s', target: Math.floor(MAX_VUS * 0.25) },
    { duration: '1m', target: Math.floor(MAX_VUS * 0.5) },
    { duration: '2m', target: MAX_VUS },
    { duration: '2m', target: MAX_VUS },
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<10000'],
    errors: ['rate<0.10'],
  },
};

const T = TEST_DATA;

function randomItem(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function post(endpoint, params) {
  const body = Object.entries(params)
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
    .join('&');
  return http.post(`${BASE_URL}/rpc/${endpoint}`, body || null,
    Object.keys(params).length > 0 ? { headers } : {});
}

// Weighted endpoint selection simulating realistic traffic
const ENDPOINTS = [
  { weight: 25, fn: () => post('get_ops_by_account', { 'account-name': randomItem(T.accounts) }) },
  { weight: 20, fn: () => post('get_block', { 'block-num': T.blockNum }) },
  { weight: 15, fn: () => post('get_acc_op_types', { 'account-name': randomItem(T.accounts) }) },
  { weight: 10, fn: () => post('get_operations', { 'from-block': T.blockRangeFrom, 'to-block': T.blockRangeTo }) },
  { weight: 10, fn: () => post('get_block_header', { 'block-num': T.blockNum }) },
  { weight: 5, fn: () => post('get_operation', { 'operation-id': T.operationId }) },
  { weight: 5, fn: () => post('get_transaction', { 'transaction-id': T.transactionId }) },
  { weight: 5, fn: () => post('get_global_state', { 'block-num': T.blockNum }) },
  { weight: 5, fn: () => post('get_version', {}) },
];

const WEIGHTED = [];
for (const ep of ENDPOINTS) {
  for (let i = 0; i < ep.weight; i++) WEIGHTED.push(ep.fn);
}

export default function () {
  const fn = WEIGHTED[Math.floor(Math.random() * WEIGHTED.length)];
  const res = fn();
  check(res, { 'not server error': (r) => r.status < 500 });
  errorRate.add(res.status >= 500);
  sleep(0.1 + Math.random() * 0.3);
}
