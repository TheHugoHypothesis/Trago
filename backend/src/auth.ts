import {createHmac, randomBytes, randomUUID} from 'node:crypto';
import * as argon2 from 'argon2';
import jwt, {JwtPayload} from 'jsonwebtoken';
import {PoolClient} from 'pg';
import {Database} from './database';
import {ApiError, invalid, validate} from './validation';

export const JWT_ISSUER = 'trago-api';
export const JWT_AUDIENCE = 'trago-client';
interface AuthConfiguration {secret: string; ttlSeconds: number}
interface Credentials {email: string; password: string}
interface Registration extends Credentials {displayName: string}
interface UserRow {id: string; email: string; display_name: string; created_at: Date}
const passwordOptions = {type: argon2.argon2id, memoryCost: 65536, timeCost: 3, parallelism: 1} as const;
const unauthenticated = () => new ApiError(401, 'UNAUTHENTICATED', 'Sessão inválida ou expirada.');
const publicUser = (row: UserRow) => ({
  id: row.id, email: row.email, displayName: row.display_name, createdAt: row.created_at.toISOString(),
});

export function loadAuthConfiguration(env: NodeJS.ProcessEnv = process.env): AuthConfiguration {
  const secret = env.AUTH_JWT_SECRET;
  if (!secret || Buffer.byteLength(secret, 'utf8') < 32 || secret.trim() !== secret) {
    throw new Error('AUTH_JWT_SECRET must contain at least 32 bytes; generate a random secret');
  }
  const rawTtl = env.AUTH_TOKEN_TTL_SECONDS ?? '900';
  const ttlSeconds = Number(rawTtl);
  if (!/^\d+$/.test(rawTtl) || !Number.isSafeInteger(ttlSeconds) || ttlSeconds < 60 || ttlSeconds > 86400) {
    throw new Error('AUTH_TOKEN_TTL_SECONDS must be an integer between 60 and 86400');
  }
  return {secret, ttlSeconds};
}

export class AuthService {
  private dummyHash = '';
  constructor(private readonly db: Database, private readonly config: AuthConfiguration) {}

  async initialize() {
    // Unknown email still performs the same password verification work.
    this.dummyHash = await argon2.hash(randomBytes(32), passwordOptions);
  }

  private async throttle(scope: string, value: string, limit: number) {
    const key = createHmac('sha256', this.config.secret).update(`${scope}\0${value}`).digest('hex');
    await this.db.pool.query("DELETE FROM auth_rate_limits WHERE window_started_at < now() - interval '1 day'");
    const result = await this.db.pool.query(`
      INSERT INTO auth_rate_limits(key, attempts) VALUES($1, 1)
      ON CONFLICT (key) DO UPDATE SET
        attempts = CASE WHEN auth_rate_limits.window_started_at <= now() - interval '15 minutes'
          THEN 1 ELSE auth_rate_limits.attempts + 1 END,
        window_started_at = CASE WHEN auth_rate_limits.window_started_at <= now() - interval '15 minutes'
          THEN now() ELSE auth_rate_limits.window_started_at END
      RETURNING attempts`, [key]);
    if (result.rows[0].attempts > limit) {
      throw new ApiError(429, 'TOO_MANY_ATTEMPTS', 'Muitas tentativas. Aguarde até 15 minutos e tente novamente.');
    }
  }

  async register(input: unknown, ip: string) {
    await this.throttle('register:ip', ip, 10);
    validate('RegisterInput', input);
    const data = input as Registration;
    const displayName = data.displayName.trim();
    if (!displayName) invalid();
    const passwordHash = await argon2.hash(data.password, passwordOptions);
    try {
      return await this.db.transaction(async client => {
        const result = await client.query<UserRow>(`
          INSERT INTO users(id, email, display_name, password_hash) VALUES($1, $2, $3, $4)
          RETURNING id, email, display_name, created_at`,
        [randomUUID(), data.email.toLowerCase(), displayName, passwordHash]);
        const user = result.rows[0];
        const accountId = `personal-${user.id}`;
        await client.query(`
          INSERT INTO accounts(id, owner_user_id, data) VALUES($1, $2, $3)`, [accountId, user.id, {
          id: accountId, type: 'PERSONAL', displayName: `Conta pessoal de ${user.display_name}`,
        }]);
        return this.issueSession(client, user);
      });
    } catch (error) {
      if ((error as {code?: string; constraint?: string}).code === '23505' &&
          (error as {constraint?: string}).constraint === 'users_email_key') {
        throw new ApiError(409, 'REGISTRATION_UNAVAILABLE', 'Não foi possível cadastrar com os dados informados.');
      }
      throw error;
    }
  }

  async login(input: unknown, ip: string) {
    await this.throttle('login:ip', ip, 30);
    validate('LoginInput', input);
    const data = input as Credentials;
    const email = data.email.toLowerCase();
    await this.throttle('login:email', email, 10);
    const result = await this.db.pool.query<UserRow & {password_hash: string}>(
      'SELECT id, email, display_name, password_hash, created_at FROM users WHERE email=$1', [email]);
    const user = result.rows[0];
    const valid = await argon2.verify(user?.password_hash ?? this.dummyHash, data.password);
    if (!user || !valid) throw new ApiError(401, 'INVALID_CREDENTIALS', 'Email ou senha inválidos.');
    return this.db.transaction(client => this.issueSession(client, user));
  }

  private async issueSession(client: PoolClient, user: UserRow) {
    const sessionId = randomUUID();
    const issuedAt = Math.floor(Date.now() / 1000);
    const accessToken = jwt.sign({iat: issuedAt}, this.config.secret, {
      algorithm: 'HS256', subject: user.id, jwtid: sessionId,
      issuer: JWT_ISSUER, audience: JWT_AUDIENCE, expiresIn: this.config.ttlSeconds,
    });
    await client.query('INSERT INTO auth_sessions(id, user_id, expires_at) VALUES($1, $2, $3)',
      [sessionId, user.id, new Date((issuedAt + this.config.ttlSeconds) * 1000)]);
    return {accessToken, tokenType: 'Bearer', expiresIn: this.config.ttlSeconds, user: publicUser(user)};
  }

  async session(authorization: string | string[] | undefined) {
    if (typeof authorization !== 'string' || authorization.length > 4096 || !authorization.startsWith('Bearer ')) {
      throw unauthenticated();
    }
    let payload: JwtPayload;
    try {
      const verified = jwt.verify(authorization.slice(7), this.config.secret, {
        algorithms: ['HS256'], issuer: JWT_ISSUER, audience: JWT_AUDIENCE,
      });
      if (typeof verified === 'string' || typeof verified.exp !== 'number' || typeof verified.iat !== 'number' ||
          !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(verified.sub ?? '') ||
          !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(verified.jti ?? '')) {
        throw unauthenticated();
      }
      payload = verified;
    } catch {
      throw unauthenticated();
    }
    const result = await this.db.pool.query<UserRow>(`
      SELECT u.id, u.email, u.display_name, u.created_at FROM users u
      JOIN auth_sessions s ON s.user_id=u.id
      WHERE s.id=$1 AND u.id=$2 AND s.revoked_at IS NULL AND s.expires_at > now()`,
    [payload.jti, payload.sub]);
    if (!result.rowCount) throw unauthenticated();
    return {user: publicUser(result.rows[0]), sessionId: payload.jti!};
  }

  async logout(authorization: string | string[] | undefined) {
    const {sessionId} = await this.session(authorization);
    await this.db.pool.query('UPDATE auth_sessions SET revoked_at=now() WHERE id=$1 AND revoked_at IS NULL', [sessionId]);
  }
}
