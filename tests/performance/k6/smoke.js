// Smoke test: verify all endpoints respond under minimal load
import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { BASE_URL, headers, TEST_DATA } from './config.js';

export const options = {
  vus: 1,
  iterations: 1,
  thresholds: {
    http_req_failed: ['rate==0'],
    http_req_duration: ['p(95)<5000'],
  },
};

const T = TEST_DATA;

const endpoints = [
  // accounts
  { name: 'get_acc_op_types', params: { 'account-name': 'dantheman' } },
  { name: 'get_ops_by_account', params: { 'account-name': 'dantheman' } },
  // blocks
  { name: 'get_block_header', params: { 'block-num': T.blockNum } },
  { name: 'get_block_range', params: { 'from-block': T.blockRangeFrom, 'to-block': T.blockRangeTo } },
  { name: 'get_block', params: { 'block-num': T.blockNum } },
  { name: 'get_ops_by_block_paging', params: { 'block-num': T.blockNum } },
  // operation types
  { name: 'get_op_types', params: { 'partial-operation-name': 'author' } },
  { name: 'get_operation_keys', params: { 'type-id': 1 } },
  // operations
  { name: 'get_operation', params: { 'operation-id': T.operationId } },
  { name: 'get_operations', params: { 'from-block': T.blockRangeFrom, 'to-block': T.blockRangeTo } },
  // market history
  { name: 'get_recent_trades', params: { 'result-limit': 100 } },
  { name: 'get_trade_history', params: { 'from-block': T.tradeRangeFrom, 'to-block': T.tradeRangeTo, 'result-limit': 100 } },
  // other
  { name: 'get_global_state', params: { 'block-num': T.blockNum } },
  { name: 'get_version', params: {} },
  { name: 'get_head_block_num', params: {} },
  // transactions
  { name: 'get_transaction', params: { 'transaction-id': T.transactionId } },
];

export default function () {
  for (const ep of endpoints) {
    const body = Object.entries(ep.params)
      .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
      .join('&');

    const res = http.post(`${BASE_URL}/rpc/${ep.name}`, body || null,
      Object.keys(ep.params).length > 0 ? { headers } : {});

    check(res, {
      [`${ep.name} returns 200`]: (r) => r.status === 200,
      [`${ep.name} returns data`]: (r) => r.body.length > 0,
    });
    sleep(0.1);
  }
}
