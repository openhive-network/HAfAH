// Load test: sustained traffic across all endpoints
import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { BASE_URL, DEFAULT_THRESHOLDS, headers, TEST_DATA } from './config.js';

const DURATION = __ENV.DURATION || '2m';
const VUS = parseInt(__ENV.VUS || '10');

export const options = {
  stages: [
    { duration: '30s', target: VUS },
    { duration: DURATION, target: VUS },
    { duration: '15s', target: 0 },
  ],
  thresholds: DEFAULT_THRESHOLDS,
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

export default function () {
  group('accounts', () => {
    const account = randomItem(T.accounts);
    post('get_acc_op_types', { 'account-name': account });
    post('get_ops_by_account', { 'account-name': account });
  });

  group('blocks', () => {
    post('get_block_header', { 'block-num': T.blockNum });
    post('get_block', { 'block-num': T.blockNum });
    post('get_ops_by_block_paging', { 'block-num': T.blockNum });
  });

  group('operations', () => {
    post('get_operation', { 'operation-id': T.operationId });
    post('get_operations', { 'from-block': T.blockRangeFrom, 'to-block': T.blockRangeTo });
  });

  group('other', () => {
    post('get_version', {});
    post('get_head_block_num', {});
    const res = post('get_global_state', { 'block-num': T.blockNum });
    check(res, { 'status 200': (r) => r.status === 200 });
  });

  sleep(0.5);
}
