const {execFileSync, spawn} = require('node:child_process');
const {randomBytes} = require('node:crypto');
const {setTimeout: delay} = require('node:timers/promises');
const {readdirSync} = require('node:fs');
const path = require('node:path');
const {Client} = require('pg');

const engine = process.env.TRAGO_TEST_CONTAINER_ENGINE ?? 'docker';
if (!['docker', 'podman'].includes(engine)) throw new Error('Select docker or podman for tests');
const suffix = randomBytes(8).toString('hex');
const name = `trago-test-${suffix}`;
const database = `trago_test_${suffix}`;
const password = randomBytes(24).toString('hex');
const cloudPassword = randomBytes(24).toString('hex');
const image = 'docker.io/library/postgres:17-bookworm';
const container = (...args) => execFileSync(engine, args, {encoding:'utf8', timeout:120000,
  stdio:['ignore', 'pipe', 'inherit']}).trim();
const env = Object.fromEntries(Object.entries(process.env).filter(([key]) =>
  !/^(PG|DATABASE_|TRAGO_TEST_|AUTH_|NODE_OPTIONS$|NODE_TLS_REJECT_UNAUTHORIZED$|NODE_EXTRA_CA_CERTS$|RENDER$|TRAGO_DEMO_AUTH$|TRUST_PROXY_HOPS$|CONTRACT_PATH$|FIXTURE_PATH$)/i.test(key)));

async function prepare(connectionString) {
  for (let attempt = 0; attempt < 40; attempt++) {
    const client = new Client({connectionString, connectionTimeoutMillis:1000});
    try {
      await client.connect();
      await client.query(`CREATE ROLE trago_app LOGIN PASSWORD '${cloudPassword}'`);
      await client.query('CREATE SCHEMA trago AUTHORIZATION trago_app');
      return;
    } catch (error) {
      const starting = ['ECONNREFUSED','ECONNRESET','57P03'].includes(error.code) ||
        ['Connection terminated unexpectedly', 'timeout expired'].includes(error.message);
      if (attempt === 39 || !starting) throw error;
    } finally {
      await client.end();
    }
    await delay(500);
  }
}

async function run() {
  let started = false;
  try {
    console.log('Starting a disposable PostgreSQL 17 test container');
    container('run', '--detach', '--rm', '--name', name, '--publish', '127.0.0.1::5432',
      '-e', 'POSTGRES_USER=trago_test', '-e', `POSTGRES_PASSWORD=${password}`,
      '-e', `POSTGRES_DB=${database}`, image, 'bash', '-ec', [
        'umask 077',
        'openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=localhost -addext subjectAltName=DNS:localhost,IP:127.0.0.1 -keyout /tmp/test-key.pem -out /tmp/test-cert.pem >/dev/null 2>&1',
        'chown postgres:postgres /tmp/test-key.pem /tmp/test-cert.pem',
        'exec docker-entrypoint.sh postgres -c ssl=on -c ssl_key_file=/tmp/test-key.pem -c ssl_cert_file=/tmp/test-cert.pem',
      ].join('\n'));
    started = true;
    const port = /^127\.0\.0\.1:(\d+)$/.exec(container('port', name, '5432/tcp'))?.[1];
    if (!port) throw new Error('PostgreSQL test port is not bound to loopback');
    const connectionString = `postgresql://trago_test:${password}@127.0.0.1:${port}/${database}`;
    await prepare(connectionString);
    const files = readdirSync(__dirname).filter(file => file.endsWith('.test.cjs'));
    const tests = spawn(process.execPath, ['--test', ...files.map(file => path.join(__dirname, file))], {
      stdio:'inherit',
      env:{...env, NODE_ENV:'test', TRAGO_TEST_DATABASE_URL:connectionString,
        TRAGO_TEST_CLOUD_URL:`postgresql://trago_app:${cloudPassword}@127.0.0.1:${port}/${database}`,
        TRAGO_TEST_TLS_CA:container('exec', name, 'cat', '/tmp/test-cert.pem')},
    });
    const interrupt = () => tests.kill();
    process.once('SIGINT', interrupt);
    process.once('SIGTERM', interrupt);
    try {
      process.exitCode = await new Promise((resolve, reject) => {
        tests.once('error', reject);
        tests.once('exit', code => resolve(code ?? 1));
      });
    } finally {
      process.removeListener('SIGINT', interrupt);
      process.removeListener('SIGTERM', interrupt);
    }
  } catch (error) {
    if (started) container('logs', '--tail', '25', name);
    throw error;
  } finally {
    if (started) container('stop', '--time', '1', name);
  }
}

run().catch(error => {
  console.error('Disposable PostgreSQL test run failed.', error.code ?? error.message);
  process.exitCode = 1;
});
