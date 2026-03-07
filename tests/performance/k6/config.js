// Shared configuration for k6 performance tests

export const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

export const DEFAULT_THRESHOLDS = {
  http_req_duration: ['p(95)<2000', 'p(99)<5000'],
  http_req_failed: ['rate<0.01'],
};

export const headers = { 'Content-Type': 'application/x-www-form-urlencoded' };

// Test data matching the 5M block CI dataset
export const TEST_DATA = {
  accounts: ['dantheman', 'ned', 'blocktrades', 'steemit'],
  blockNum: 3000000,
  blockRangeFrom: 3000000,
  blockRangeTo: 3000100,
  tradeRangeFrom: 4900000,
  tradeRangeTo: 5000000,
  operationId: '3448858738752',
  transactionId: '954f6de36e6715d128fa8eb5a053fc254b05ded0',
};
