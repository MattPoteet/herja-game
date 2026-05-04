import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { WebSocketServer } from 'ws';
import { createClient } from '@supabase/supabase-js';

const PORT = Number(process.env.PORT || 8787);
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const OWNER_ADMIN_EMAILS = ['matthewpoteet1@gmail.com'];
const ADMIN_EMAILS = Array.from(new Set([
  ...String(process.env.ADMIN_EMAILS || '')
    .split(',')
    .map(email => email.trim().toLowerCase())
    .filter(Boolean),
  ...OWNER_ADMIN_EMAILS
]));

const app = express();
app.use(cors());
app.use(express.json({ limit: '1mb' }));

const supabaseAdmin = SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY
  ? createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } })
  : null;

const supabaseAuth = SUPABASE_URL && SUPABASE_ANON_KEY
  ? createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { auth: { persistSession: false } })
  : null;

const players = new Map();
const CHAT_MESSAGE_MAX_LENGTH = 180;

function requireSupabase(res) {
  if (!supabaseAdmin || !supabaseAuth) {
    res.status(501).json({ error: 'Supabase is not configured. Set SUPABASE_URL, SUPABASE_ANON_KEY, and SUPABASE_SERVICE_ROLE_KEY in backend/.env.' });
    return false;
  }
  return true;
}

function isAdminEmail(email) {
  return ADMIN_EMAILS.includes(String(email || '').trim().toLowerCase());
}

function publicAccount(row, session = null, friends = [], clan = {}, friendInvitesReceived = [], friendInvitesSent = []) {
  return {
    id: row.id,
    email: row.email,
    username: row.email,
    is_admin: isAdminEmail(row.email),
    player_name: row.player_name,
    character_id: row.character_id || 'viking',
    level: row.level ?? 1,
    xp: row.xp ?? 0,
    hp: row.hp ?? 100,
    max_hp: row.max_hp ?? 100,
    attack: row.attack ?? 12,
    gold: row.gold ?? 0,
    inventory: row.inventory ?? [],
    last_position: row.last_position ?? {},
    last_latitude: row.last_latitude ?? null,
    last_longitude: row.last_longitude ?? null,
    friends,
    friend_invites_received: friendInvitesReceived,
    friend_invites_sent: friendInvitesSent,
    notifications: [],
    clan,
    created_at: row.created_at,
    updated_at: row.updated_at,
    session
  };
}

async function getUserFromBearer(req) {
  const header = String(req.headers.authorization || '');
  const token = header.startsWith('Bearer ') ? header.slice('Bearer '.length) : '';
  if (!token || !supabaseAdmin) return null;
  const { data, error } = await supabaseAdmin.auth.getUser(token);
  if (error || !data?.user) return null;
  return data.user;
}

async function getSocial(accountId) {
  const [{ data: friendRows }, { data: clanRows }, { data: receivedRows }, { data: sentRows }] = await Promise.all([
    supabaseAdmin.from('friendships').select('friend_name').eq('account_id', accountId).eq('status', 'accepted'),
    supabaseAdmin.from('clan_members').select('role, clans(id, name)').eq('account_id', accountId).maybeSingle(),
    supabaseAdmin.from('friend_invites').select('sender_name').eq('receiver_account_id', accountId).eq('status', 'pending'),
    supabaseAdmin.from('friend_invites').select('receiver_name').eq('sender_account_id', accountId).eq('status', 'pending')
  ]);

  const friends = Array.isArray(friendRows) ? friendRows.map(row => row.friend_name).filter(Boolean) : [];
  const friendInvitesReceived = Array.isArray(receivedRows) ? receivedRows.map(row => row.sender_name).filter(Boolean) : [];
  const friendInvitesSent = Array.isArray(sentRows) ? sentRows.map(row => row.receiver_name).filter(Boolean) : [];
  let clan = {};
  if (clanRows?.clans) {
    clan = { id: clanRows.clans.id, name: clanRows.clans.name, role: clanRows.role || 'Member' };
  }
  return { friends, clan, friendInvitesReceived, friendInvitesSent };
}

app.get('/health', (_req, res) => {
  res.json({
    ok: true,
    app: 'Herja',
    onlinePlayers: players.size,
    supabaseConfigured: Boolean(supabaseAdmin && supabaseAuth),
    adminConfigured: ADMIN_EMAILS.length > 0
  });
});

app.post('/auth/signup', async (req, res) => {
  if (!requireSupabase(res)) return;

  const email = String(req.body.email || '').trim().toLowerCase();
  const password = String(req.body.password || '');
  const playerName = String(req.body.player_name || 'Viking').trim().slice(0, 24);
  const characterId = String(req.body.character_id || 'viking');

  if (!email.includes('@') || !email.includes('.')) return res.status(400).json({ error: 'Valid email is required.' });
  if (password.length < 6) return res.status(400).json({ error: 'Password must be at least 6 characters.' });
  if (playerName.length < 2) return res.status(400).json({ error: 'Player name must be at least 2 characters.' });

  const { data: created, error: createError } = await supabaseAdmin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      player_name: playerName,
      character_id: characterId
    }
  });

  if (createError) return res.status(400).json({ error: createError.message });

  const userId = created.user.id;
  const { data: profile, error: profileError } = await supabaseAdmin
    .from('game_accounts')
    .upsert({
      id: userId,
      email,
      player_name: playerName,
      character_id: characterId,
      inventory: ["Wood", "Wood", "Wood", "Wood", "Wood", "Stone", "Stone", "Stone", "Herb", "Herb", "Mushroom", "Crystal Vial"],
      updated_at: new Date().toISOString()
    }, { onConflict: 'id' })
    .select('*')
    .single();

  if (profileError) return res.status(500).json({ error: profileError.message });

  const { data: signedIn, error: signInError } = await supabaseAuth.auth.signInWithPassword({ email, password });
  if (signInError) return res.status(400).json({ error: signInError.message });

  res.json({ ok: true, account: publicAccount(profile), session: signedIn.session });
});

app.post('/auth/login', async (req, res) => {
  if (!requireSupabase(res)) return;

  const email = String(req.body.email || '').trim().toLowerCase();
  const password = String(req.body.password || '');

  const { data: signedIn, error: signInError } = await supabaseAuth.auth.signInWithPassword({ email, password });
  if (signInError) return res.status(401).json({ error: signInError.message });

  const user = signedIn.user;
  let { data: profile, error: profileError } = await supabaseAdmin
    .from('game_accounts')
    .select('*')
    .eq('id', user.id)
    .maybeSingle();

  if (profileError) return res.status(500).json({ error: profileError.message });

  if (!profile) {
    const { data: inserted, error: insertError } = await supabaseAdmin
      .from('game_accounts')
      .insert({
        id: user.id,
        email,
        player_name: user.user_metadata?.player_name || 'Viking',
        character_id: user.user_metadata?.character_id || 'viking'
      })
      .select('*')
      .single();
    if (insertError) return res.status(500).json({ error: insertError.message });
    profile = inserted;
  }

  const social = await getSocial(user.id);
  res.json({
    ok: true,
    account: publicAccount(profile, null, social.friends, social.clan, social.friendInvitesReceived, social.friendInvitesSent),
    session: signedIn.session
  });
});

app.post('/progress/save', async (req, res) => {
  if (!requireSupabase(res)) return;
  const user = await getUserFromBearer(req);
  if (!user) return res.status(401).json({ error: 'Invalid or missing access token.' });

  const payload = {
    id: user.id,
    email: user.email,
    player_name: String(req.body.player_name || 'Viking').slice(0, 24),
    character_id: String(req.body.character_id || 'viking'),
    level: Number(req.body.level || 1),
    xp: Number(req.body.xp || 0),
    hp: Number(req.body.hp || 100),
    max_hp: Number(req.body.max_hp || 100),
    attack: Number(req.body.attack || 12),
    gold: Number(req.body.gold || 0),
    inventory: Array.isArray(req.body.inventory) ? req.body.inventory : [],
    last_position: req.body.last_position || {},
    last_latitude: req.body.last_latitude ?? null,
    last_longitude: req.body.last_longitude ?? null,
    updated_at: new Date().toISOString()
  };

  const { data, error } = await supabaseAdmin
    .from('game_accounts')
    .upsert(payload, { onConflict: 'id' })
    .select('*')
    .single();

  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true, account: publicAccount(data) });
});

app.post('/friends/add', async (req, res) => {
  if (!requireSupabase(res)) return;
  const user = await getUserFromBearer(req);
  if (!user) return res.status(401).json({ error: 'Invalid or missing access token.' });

  const friendName = String(req.body.friend_name || '').trim();
  if (friendName.length < 2) return res.status(400).json({ error: 'Friend name is required.' });

  const { data: friend } = await supabaseAdmin
    .from('game_accounts')
    .select('id, player_name, email')
    .or(`email.eq.${friendName.toLowerCase()},player_name.eq.${friendName}`)
    .maybeSingle();

  const { error } = await supabaseAdmin.from('friendships').upsert({
    account_id: user.id,
    friend_account_id: friend?.id ?? null,
    friend_name: friend?.player_name ?? friendName,
    status: 'accepted'
  }, { onConflict: 'account_id,friend_name' });

  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

app.post('/friends/invite', async (req, res) => {
  if (!requireSupabase(res)) return;
  const user = await getUserFromBearer(req);
  if (!user) return res.status(401).json({ error: 'Invalid or missing access token.' });

  const friendName = String(req.body.friend_name || '').trim();
  if (friendName.length < 2) return res.status(400).json({ error: 'Friend name is required.' });

  const [{ data: sender }, { data: receiver }] = await Promise.all([
    supabaseAdmin.from('game_accounts').select('id, player_name, email').eq('id', user.id).maybeSingle(),
    supabaseAdmin
      .from('game_accounts')
      .select('id, player_name, email')
      .or(`email.eq.${friendName.toLowerCase()},player_name.eq.${friendName}`)
      .maybeSingle()
  ]);

  const senderName = sender?.player_name || user.email || 'Player';
  if (receiver?.id === user.id) return res.status(400).json({ error: 'You cannot invite yourself.' });

  const { error } = await supabaseAdmin.from('friend_invites').upsert({
    sender_account_id: user.id,
    receiver_account_id: receiver?.id ?? null,
    receiver_name: receiver?.player_name ?? friendName,
    sender_name: senderName,
    status: 'pending',
    responded_at: null
  }, { onConflict: 'sender_account_id,receiver_name' });

  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true, receiver_name: receiver?.player_name ?? friendName });
});

app.post('/friends/invite/respond', async (req, res) => {
  if (!requireSupabase(res)) return;
  const user = await getUserFromBearer(req);
  if (!user) return res.status(401).json({ error: 'Invalid or missing access token.' });

  const friendName = String(req.body.friend_name || '').trim();
  const action = String(req.body.action || '').trim().toLowerCase();
  if (friendName.length < 2) return res.status(400).json({ error: 'Friend name is required.' });
  if (!['accept', 'decline'].includes(action)) return res.status(400).json({ error: 'Action must be accept or decline.' });

  const { data: invite, error: inviteError } = await supabaseAdmin
    .from('friend_invites')
    .select('*')
    .eq('receiver_account_id', user.id)
    .eq('sender_name', friendName)
    .eq('status', 'pending')
    .maybeSingle();

  if (inviteError) return res.status(500).json({ error: inviteError.message });
  if (!invite) return res.status(404).json({ error: 'Friend invite not found.' });

  const status = action === 'accept' ? 'accepted' : 'declined';
  const { error: updateError } = await supabaseAdmin
    .from('friend_invites')
    .update({ status, responded_at: new Date().toISOString() })
    .eq('id', invite.id);

  if (updateError) return res.status(500).json({ error: updateError.message });

  if (action === 'accept') {
    const { data: receiverProfile } = await supabaseAdmin
      .from('game_accounts')
      .select('id, player_name')
      .eq('id', user.id)
      .maybeSingle();
    const receiverName = receiverProfile?.player_name || user.email || 'Player';

    const friendshipRows = [
      {
        account_id: user.id,
        friend_account_id: invite.sender_account_id,
        friend_name: invite.sender_name,
        status: 'accepted'
      },
      {
        account_id: invite.sender_account_id,
        friend_account_id: user.id,
        friend_name: receiverName,
        status: 'accepted'
      }
    ];

    const { error: friendError } = await supabaseAdmin
      .from('friendships')
      .upsert(friendshipRows, { onConflict: 'account_id,friend_name' });

    if (friendError) return res.status(500).json({ error: friendError.message });
  }

  res.json({ ok: true, status });
});

app.post('/clans/create-or-join', async (req, res) => {
  if (!requireSupabase(res)) return;
  const user = await getUserFromBearer(req);
  if (!user) return res.status(401).json({ error: 'Invalid or missing access token.' });

  const name = String(req.body.clan_name || '').trim().slice(0, 32);
  if (name.length < 2) return res.status(400).json({ error: 'Clan name is required.' });

  let { data: clan, error: clanError } = await supabaseAdmin
    .from('clans')
    .select('*')
    .eq('name', name)
    .maybeSingle();

  if (clanError) return res.status(500).json({ error: clanError.message });

  if (!clan) {
    const { data: inserted, error: insertError } = await supabaseAdmin
      .from('clans')
      .insert({ name, founder_account_id: user.id })
      .select('*')
      .single();
    if (insertError) return res.status(500).json({ error: insertError.message });
    clan = inserted;
  }

  const role = clan.founder_account_id === user.id ? 'Founder' : 'Member';
  const { error: memberError } = await supabaseAdmin.from('clan_members').upsert({
    clan_id: clan.id,
    account_id: user.id,
    role
  }, { onConflict: 'clan_id,account_id' });

  if (memberError) return res.status(500).json({ error: memberError.message });
  res.json({ ok: true, clan: { id: clan.id, name: clan.name, role } });
});

const server = app.listen(PORT, () => {
  console.log(`Herja backend running on http://127.0.0.1:${PORT}`);
});

const wss = new WebSocketServer({ server });

function broadcastPresence() {
  const snapshot = {
    type: 'presence_snapshot',
    players: Object.fromEntries(players.entries())
  };
  const raw = JSON.stringify(snapshot);
  for (const client of wss.clients) {
    if (client.readyState === 1) client.send(raw);
  }
}

wss.on('connection', (socket) => {
  socket.on('message', (buffer) => {
    try {
      const msg = JSON.parse(buffer.toString());
      if (msg.type === 'player_state' && msg.id) {
        socket.playerId = String(msg.id);
        players.set(msg.id, {
          id: msg.id,
          x: Number(msg.x || 0),
          y: Number(msg.y || 0),
          name: String(msg.name || 'Player'),
          username: String(msg.username || ''),
          level: Number(msg.level || 1),
          characterId: String(msg.character_id || 'viking'),
          clan: String(msg.clan || ''),
          updatedAt: Date.now()
        });
      } else if (msg.type === 'chat_message' && msg.id) {
        const text = String(msg.message || '').trim().slice(0, CHAT_MESSAGE_MAX_LENGTH);
        if (!text) return;
        const player = players.get(msg.id) || {};
        const chat = {
          type: 'chat_message',
          id: String(msg.id),
          name: String(player.name || msg.name || 'Player'),
          clan: String(player.clan || msg.clan || ''),
          message: text,
          createdAt: Date.now()
        };
        const raw = JSON.stringify(chat);
        for (const client of wss.clients) {
          if (client.readyState === 1) client.send(raw);
        }
      }
    } catch (error) {
      console.warn('Bad websocket packet', error.message);
    }
  });

  socket.on('close', () => {
    if (socket.playerId) players.delete(socket.playerId);
  });
});

setInterval(() => {
  const now = Date.now();
  for (const [id, player] of players.entries()) {
    if (now - player.updatedAt > 10_000) players.delete(id);
  }
  broadcastPresence();
}, 1000);
