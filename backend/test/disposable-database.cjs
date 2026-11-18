const {strict: assert} = require('node:assert');

const url = process.env.TRAGO_TEST_DATABASE_URL ?? '';
assert(process.env.NODE_ENV === 'test' &&
  /^postgresql:\/\/trago_test:[a-f0-9]{48}@127\.0\.0\.1:\d+\/trago_test_[a-f0-9]{16}$/.test(url),
  'Run npm test to provision a disposable PostgreSQL database');
process.env.DATABASE_URL = url;
