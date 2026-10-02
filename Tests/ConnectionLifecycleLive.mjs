import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';

// Only the local stack is allowed. Credentials stay in memory and are never logged.
const config = JSON.parse(execFileSync('supabase', ['status', '-o', 'json'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }));
const url = config.API_URL;
assert(['127.0.0.1', 'localhost'].includes(new URL(url).hostname));
const anon = config.ANON_KEY;
const admin = config.SERVICE_ROLE_KEY;
const users = [];
const sockets = [];
async function request(path, token, method = 'GET', body) {
  const response = await fetch(`${url}${path}`, {
    method, headers: { apikey: anon, Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body), signal: AbortSignal.timeout(10000)
  });
  const data = await response.json();
  if (!response.ok) throw new Error(`${method} ${path}: ${response.status} ${data.message ?? data.msg ?? ''}`);
  return data;
}
async function createUser() {
  const email = `connection-test-${randomUUID()}@example.invalid`;
  const password = randomUUID() + '!Aa1';
  const user = await request('/auth/v1/admin/users', admin, 'POST', { email, password, email_confirm: true, user_metadata: { real_name: 'Connection Lifecycle Test' } });
  users.push(user.id);
  const session = await request('/auth/v1/token?grant_type=password', anon, 'POST', { email, password });
  return { id: user.id, token: session.access_token };
}
const transition = (me, other, action) => request('/rest/v1/rpc/transition_connection', me.token, 'POST', { p_other: other.id, p_action: action });
const edges = me => request(`/rest/v1/follows?select=follower_id,followee_id,status&or=(follower_id.eq.${me.id},followee_id.eq.${me.id})`, me.token);
async function watch(me, column) {
  const socket = new WebSocket(`${url.replace('http', 'ws')}/realtime/v1/websocket?apikey=${encodeURIComponent(anon)}&vsn=1.0.0`);
  sockets.push(socket);
  const events = [];
  const topic = `realtime:connection-test-${randomUUID()}`;
  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error('Realtime join timeout')), 10000);
    socket.addEventListener('error', () => { clearTimeout(timeout); reject(new Error('Realtime socket failed')); });
    socket.addEventListener('open', () => socket.send(JSON.stringify({ topic, event: 'phx_join', ref: '1', payload: {
      access_token: me.token,
      config: { broadcast: { self: false }, presence: { key: '' }, postgres_changes: [{ event: '*', schema: 'public', table: 'follows', filter: `${column}=eq.${me.id}` }] }
    } })));
    socket.addEventListener('message', ({ data }) => {
      const message = JSON.parse(data);
      if (message.event === 'phx_reply' && message.ref === '1' && message.payload.status !== 'ok') {
        clearTimeout(timeout);
        reject(new Error('Realtime join rejected'));
      }
      if (message.event === 'system') {
        console.log(`Realtime subscription: ${message.payload.status} ${message.payload.message ?? ''}`);
        if (message.payload.status === 'ok') { clearTimeout(timeout); resolve(); }
      }
      if (message.event === 'postgres_changes') events.push(message.payload.data);
    });
  });
  return events;
}
async function waitFor(events, type) {
  const start = Date.now();
  while (!events.some(event => event.type === type)) {
    if (Date.now() - start > 5000) throw new Error(`Realtime ${type} not received within 5 seconds`);
    await new Promise(resolve => setTimeout(resolve, 25));
  }
}

try {
  const a = await createUser();
  const b = await createUser();
  const incoming = await watch(b, 'followee_id');
  const outgoing = await watch(a, 'follower_id');
  const start = Date.now();
  assert.equal(await transition(a, b, 'request'), 'requestSent');
  await waitFor(incoming, 'INSERT');
  console.log(`Receiver realtime INSERT: ${Date.now() - start} ms`);
  assert.equal((await edges(b)).filter(edge => edge.status === 'pending').length, 1);
  assert.equal(await transition(b, a, 'accept'), 'connected');
  await waitFor(outgoing, 'UPDATE');
  for (let i = 0; i < 5; i++) {
    const received = await edges(b);
    assert.equal(received.filter(edge => edge.status === 'pending').length, 0);
    assert.equal(received.filter(edge => edge.status === 'accepted').length, 1);
  }
  assert.equal(await transition(a, b, 'cancel'), 'connected');
  assert.equal(await transition(b, a, 'decline'), 'connected');
  await transition(a, b, 'disconnect');
  incoming.length = 0;
  await transition(a, b, 'request');
  await waitFor(incoming, 'INSERT');
  incoming.length = 0;
  await transition(a, b, 'cancel');
  await waitFor(incoming, 'DELETE');
  console.log('Receiver realtime DELETE received after sender cancellation');
  const crossed = await Promise.all([transition(a, b, 'request'), transition(b, a, 'request')]);
  assert.deepEqual(crossed.slice().sort(), ['requestReceived', 'requestSent']);
  assert.equal((await edges(a)).length, 1);
  const sender = crossed[0] === 'requestSent' ? a : b;
  const receiver = sender === a ? b : a;
  assert.equal(await transition(receiver, sender, 'decline'), 'none');
  assert.equal(await transition(sender, receiver, 'request'), 'requestSent');
  assert.equal(await transition(sender, receiver, 'cancel'), 'none');
  await assert.rejects(transition(receiver, sender, 'accept'));
  assert.equal((await edges(receiver)).length, 0);
  console.log('PASS: send, receive, realtime, accept, repeated refresh, protected cancel/decline, simultaneous requests, decline/resend, cancel-before-accept');
} finally {
  for (const socket of sockets) socket.close();
  for (const id of users) await request(`/auth/v1/admin/users/${id}`, admin, 'DELETE');
  console.log(`Removed ${users.length} temporary local test accounts`);
}
