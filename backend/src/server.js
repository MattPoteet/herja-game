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
const CLAN_CREATE_COST = 10000;
const MAX_CLAN_MEMBERS = 100;
const CLAN_PERKS = new Set(['xp_boost', 'gold_boost', 'hit_bonus', 'defense_bonus', 'boss_hunter']);
const MAX_ACTIVE_WARS = 3;
const BATTLE_PREP_SECONDS = 30 * 60;
const BATTLE_DURATION_SECONDS = 15 * 60;
const BATTLE_POINTS_PER_KILL = 1;
const WINNER_XP_REWARD = 650;
const WINNER_GOLD_REWARD = 300;
const LOSER_XP_REWARD = 250;
const LOSER_GOLD_REWARD = 90;
const SKILL_POINTS_PER_LEVEL = 1;
const SKILL_DEFINITIONS = {
  viking: [
    ['warriors_strength', 2, 3, {}], ['iron_skin', 3, 3, {}], ['battle_hunger', 5, 2, { warriors_strength: 1 }],
    ['axe_mastery', 6, 3, { warriors_strength: 2 }], ['berserker_endurance', 7, 3, { iron_skin: 1 }],
    ['cleave', 4, 2, {}], ['shield_breaker', 8, 2, { cleave: 1 }], ['war_cry', 10, 1, { warriors_strength: 2 }],
    ['berserker_charge', 14, 1, { shield_breaker: 1 }], ['odins_wrath', 18, 1, { berserker_charge: 1 }],
    ['wrath_of_the_north', 25, 1, { odins_wrath: 1, berserker_endurance: 2 }]
  ],
  mage: [
    ['arcane_focus', 2, 3, {}], ['mana_flow', 4, 2, {}], ['elemental_mastery', 6, 3, { arcane_focus: 1 }],
    ['spell_precision', 7, 2, { arcane_focus: 1 }], ['mystic_shielding', 8, 3, {}], ['fireball', 3, 2, {}],
    ['frost_nova', 9, 2, { fireball: 1 }], ['chain_lightning', 12, 2, { elemental_mastery: 1 }],
    ['meteor_strike', 16, 1, { chain_lightning: 1 }], ['blizzard', 20, 1, { frost_nova: 1 }],
    ['archmage_ascension', 25, 1, { meteor_strike: 1, blizzard: 1 }]
  ],
  druid: [
    ['natures_blessing', 2, 3, {}], ['thorn_skin', 4, 3, {}], ['wild_growth', 5, 3, { natures_blessing: 1 }],
    ['spirit_bond', 7, 2, {}], ['herbal_wisdom', 8, 2, { natures_blessing: 1 }], ['root_snare', 3, 2, {}],
    ['healing_bloom', 6, 2, { natures_blessing: 1 }], ['poison_spores', 10, 2, { root_snare: 1 }],
    ['entangling_forest', 15, 1, { poison_spores: 1 }], ['moonwell', 18, 1, { healing_bloom: 2 }],
    ['avatar_of_the_wild', 25, 1, { entangling_forest: 1, moonwell: 1 }]
  ],
  shield_maiden: [
    ['bow_discipline', 2, 3, {}], ['eagle_eye', 4, 3, {}], ['hunters_footwork', 6, 2, { bow_discipline: 1 }],
    ['fletchers_craft', 7, 3, { eagle_eye: 1 }], ['rangers_resolve', 9, 2, { hunters_footwork: 1 }],
    ['quick_shot', 3, 2, {}], ['pinning_arrow', 8, 2, { quick_shot: 1 }],
    ['arrow_volley', 10, 2, { fletchers_craft: 1 }], ['falcon_dive', 15, 1, { pinning_arrow: 1 }],
    ['storm_of_arrows', 18, 1, { arrow_volley: 1 }], ['valkyrie_marksman', 25, 1, { falcon_dive: 1, storm_of_arrows: 1 }]
  ]
};

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

function cleanClanName(rawName) {
  return String(rawName || '').trim().slice(0, 24);
}

function validateClanName(name) {
  if (name.length < 3) return 'Clan name must be at least 3 characters.';
  if (name.length > 24) return 'Clan name must be 24 characters or less.';
  const lowered = name.toLowerCase();
  if (['admin', 'mod', 'owner', 'null', 'test'].some(word => lowered.includes(word))) return 'Choose a different clan name.';
  return '';
}

function validPerkType(perkType) {
  return CLAN_PERKS.has(String(perkType || '')) ? String(perkType) : 'xp_boost';
}

function skillDefinition(classType, skillId) {
  const rows = SKILL_DEFINITIONS[classType] || [];
  const row = rows.find(item => item[0] === skillId);
  if (!row) return null;
  return { id: row[0], requiredLevel: row[1], maxRank: row[2], prerequisites: row[3] || {} };
}

function cleanSkillState(raw) {
  const state = raw && typeof raw === 'object' ? raw : {};
  const unlocked = state.unlocked_skills && typeof state.unlocked_skills === 'object' ? state.unlocked_skills : {};
  return {
    available_skill_points: Math.max(0, Number(state.available_skill_points || 0)),
    total_skill_points_earned: Math.max(0, Number(state.total_skill_points_earned || 0)),
    unlocked_skills: Object.fromEntries(Object.entries(unlocked).map(([key, value]) => [key, Math.max(0, Number(value || 0))]))
  };
}

async function publicClan(clan, role = '') {
  if (!clan) return {};
  const cleanRole = String(role || '').toLowerCase() === 'founder' ? 'Leader' : role;
  const { count } = await supabaseAdmin
    .from('clan_members')
    .select('id', { count: 'exact', head: true })
    .eq('clan_id', clan.id);
  return {
    id: clan.id,
    name: clan.name,
    role: cleanRole,
    leader_id: clan.leader_account_id || clan.founder_account_id,
    perk_type: clan.perk_type || 'xp_boost',
    member_count: count || 0,
    max_members: clan.max_members || MAX_CLAN_MEMBERS,
    wins: clan.wins || 0,
    losses: clan.losses || 0,
    draws: clan.draws || 0,
    reputation: clan.reputation || 0
  };
}

async function clanMembership(accountId) {
  const { data, error } = await supabaseAdmin
    .from('clan_members')
    .select('role, clans(*)')
    .eq('account_id', accountId)
    .maybeSingle();
  if (error || !data?.clans) return { clan: null, role: '' };
  return { clan: data.clans, role: data.role || 'Member' };
}

async function requireClanLeader(user, res) {
  const membership = await clanMembership(user.id);
  if (!membership.clan) {
    res.status(400).json({ error: 'You are not in a clan.' });
    return null;
  }
  if (String(membership.role || '').toLowerCase() !== 'leader') {
    res.status(403).json({ error: 'Only clan leaders can do that.' });
    return null;
  }
  return membership;
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
    skills: row.skills ?? { available_skill_points: 0, total_skill_points_earned: 0, unlocked_skills: {} },
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
    supabaseAdmin.from('clan_members').select('role, clans(*)').eq('account_id', accountId).maybeSingle(),
    supabaseAdmin.from('friend_invites').select('sender_name').eq('receiver_account_id', accountId).eq('status', 'pending'),
    supabaseAdmin.from('friend_invites').select('receiver_name').eq('sender_account_id', accountId).eq('status', 'pending')
  ]);

  const friends = Array.isArray(friendRows) ? friendRows.map(row => row.friend_name).filter(Boolean) : [];
  const friendInvitesReceived = Array.isArray(receivedRows) ? receivedRows.map(row => row.sender_name).filter(Boolean) : [];
  const friendInvitesSent = Array.isArray(sentRows) ? sentRows.map(row => row.receiver_name).filter(Boolean) : [];
  let clan = {};
  if (clanRows?.clans) {
    clan = await publicClan(clanRows.clans, clanRows.role || 'Member');
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
  const { data: existingProfile } = await supabaseAdmin
    .from('game_accounts')
    .select('level, skills')
    .eq('id', user.id)
    .maybeSingle();
  const previousLevel = Number(existingProfile?.level || 1);
  const nextLevel = Number(req.body.level || 1);
  const previousSkills = cleanSkillState(existingProfile?.skills);
  const levelGain = Math.max(0, nextLevel - previousLevel);
  const incomingSkills = cleanSkillState(req.body.skills);
  const spentRanks = Object.values(incomingSkills.unlocked_skills).reduce((sum, rank) => sum + Number(rank || 0), 0);
  const earned = Math.max(previousSkills.total_skill_points_earned + levelGain, Math.max(0, nextLevel - 1) * SKILL_POINTS_PER_LEVEL);
  if (spentRanks > earned) return res.status(400).json({ error: 'Skill state spends more points than this character has earned.' });
  for (const [skillId, rank] of Object.entries(incomingSkills.unlocked_skills)) {
    const skill = skillDefinition(String(req.body.character_id || 'viking'), skillId);
    if (!skill) return res.status(400).json({ error: 'Skill state contains a skill from another class.' });
    if (Number(rank || 0) > skill.maxRank) return res.status(400).json({ error: 'Skill state exceeds a skill max rank.' });
    if (nextLevel < skill.requiredLevel) return res.status(400).json({ error: `Requires level ${skill.requiredLevel}.` });
    for (const [prereqId, requiredRank] of Object.entries(skill.prerequisites)) {
      if (Number(incomingSkills.unlocked_skills[prereqId] || 0) < Number(requiredRank)) {
        return res.status(400).json({ error: `Requires ${prereqId} Rank ${requiredRank}.` });
      }
    }
  }
  const skills = {
    available_skill_points: Math.max(0, earned - spentRanks),
    total_skill_points_earned: earned,
    unlocked_skills: incomingSkills.unlocked_skills
  };

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
    skills,
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

app.post('/skills/unlock', async (req, res) => {
  if (!requireSupabase(res)) return;
  const user = await getUserFromBearer(req);
  if (!user) return res.status(401).json({ error: 'Invalid or missing access token.' });
  const skillId = String(req.body.skill_id || '').trim();
  const { data: profile, error: profileError } = await supabaseAdmin
    .from('game_accounts')
    .select('*')
    .eq('id', user.id)
    .maybeSingle();
  if (profileError) return res.status(500).json({ error: profileError.message });
  if (!profile) return res.status(404).json({ error: 'Account not found.' });
  const classType = String(profile.character_id || 'viking');
  const skill = skillDefinition(classType, skillId);
  if (!skill) return res.status(400).json({ error: 'This skill is not available for your class.' });
  const state = cleanSkillState(profile.skills);
  if (state.available_skill_points < 1) return res.status(400).json({ error: 'Not enough skill points.' });
  if (Number(profile.level || 1) < skill.requiredLevel) return res.status(400).json({ error: `Requires level ${skill.requiredLevel}.` });
  const currentRank = Number(state.unlocked_skills[skillId] || 0);
  if (currentRank >= skill.maxRank) return res.status(400).json({ error: 'Skill is already at max rank.' });
  for (const [prereqId, requiredRank] of Object.entries(skill.prerequisites)) {
    if (Number(state.unlocked_skills[prereqId] || 0) < Number(requiredRank)) {
      return res.status(400).json({ error: `Requires ${prereqId} Rank ${requiredRank}.` });
    }
  }
  state.available_skill_points -= 1;
  state.unlocked_skills[skillId] = currentRank + 1;
  const { data: updated, error: updateError } = await supabaseAdmin
    .from('game_accounts')
    .update({ skills: state, updated_at: new Date().toISOString() })
    .eq('id', user.id)
    .select('*')
    .single();
  if (updateError) return res.status(500).json({ error: updateError.message });
  res.json({ ok: true, skills: state, account: publicAccount(updated) });
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

  if (!clan) return res.status(404).json({ error: 'Clan not found. Use clan creation with the 10,000 gold cost.' });

  const role = (clan.leader_account_id || clan.founder_account_id) === user.id ? 'Leader' : 'Member';
  const { error: memberError } = await supabaseAdmin.from('clan_members').upsert({
    clan_id: clan.id,
    account_id: user.id,
    role
  }, { onConflict: 'clan_id,account_id' });

  if (memberError) return res.status(500).json({ error: memberError.message });
  res.json({ ok: true, clan: { id: clan.id, name: clan.name, role } });
});

app.post('/clans/create', async (req, res) => {
  if (!requireSupabase(res)) return;
  const user = await getUserFromBearer(req);
  if (!user) return res.status(401).json({ error: 'Invalid or missing access token.' });

  const name = cleanClanName(req.body.clan_name);
  const validationError = validateClanName(name);
  if (validationError) return res.status(400).json({ error: validationError });
  const perkType = validPerkType(req.body.perk_type);

  const existingMembership = await clanMembership(user.id);
  if (existingMembership.clan) return res.status(400).json({ error: 'You are already in a clan.' });

  const { data: profile, error: profileError } = await supabaseAdmin
    .from('game_accounts')
    .select('id, player_name, gold')
    .eq('id', user.id)
    .maybeSingle();
  if (profileError) return res.status(500).json({ error: profileError.message });
  if (!profile) return res.status(404).json({ error: 'Account not found.' });
  if (Number(profile.gold || 0) < CLAN_CREATE_COST) return res.status(400).json({ error: 'You need 10,000 gold to create a clan.' });

  const { data: existingClan } = await supabaseAdmin.from('clans').select('id').ilike('name', name).maybeSingle();
  if (existingClan) return res.status(409).json({ error: 'That clan name is already taken.' });

  const { data: clan, error: clanError } = await supabaseAdmin
    .from('clans')
    .insert({
      name,
      founder_account_id: user.id,
      leader_account_id: user.id,
      perk_type: perkType,
      max_members: MAX_CLAN_MEMBERS
    })
    .select('*')
    .single();
  if (clanError) return res.status(500).json({ error: clanError.message });

  const { error: memberError } = await supabaseAdmin.from('clan_members').insert({
    clan_id: clan.id,
    account_id: user.id,
    role: 'Leader'
  });
  if (memberError) return res.status(500).json({ error: memberError.message });

  const newGold = Number(profile.gold || 0) - CLAN_CREATE_COST;
  const { error: goldError } = await supabaseAdmin.from('game_accounts').update({ gold: newGold, updated_at: new Date().toISOString() }).eq('id', user.id);
  if (goldError) return res.status(500).json({ error: goldError.message });

  res.json({ ok: true, clan: await publicClan(clan, 'Leader'), gold: newGold });
});

app.post('/clans/join', async (req, res) => {
  if (!requireSupabase(res)) return;
  const user = await getUserFromBearer(req);
  if (!user) return res.status(401).json({ error: 'Invalid or missing access token.' });
  const name = cleanClanName(req.body.clan_name);
  const validationError = validateClanName(name);
  if (validationError) return res.status(400).json({ error: validationError });

  const existingMembership = await clanMembership(user.id);
  if (existingMembership.clan) return res.status(400).json({ error: 'You are already in a clan.' });

  const { data: clan, error: clanError } = await supabaseAdmin.from('clans').select('*').ilike('name', name).maybeSingle();
  if (clanError) return res.status(500).json({ error: clanError.message });
  if (!clan) return res.status(404).json({ error: 'Clan not found.' });

  const { count } = await supabaseAdmin.from('clan_members').select('id', { count: 'exact', head: true }).eq('clan_id', clan.id);
  if ((count || 0) >= (clan.max_members || MAX_CLAN_MEMBERS)) return res.status(400).json({ error: 'This clan is full.' });

  const { error: memberError } = await supabaseAdmin.from('clan_members').insert({
    clan_id: clan.id,
    account_id: user.id,
    role: 'Member'
  });
  if (memberError) return res.status(500).json({ error: memberError.message });
  res.json({ ok: true, clan: await publicClan(clan, 'Member') });
});

app.post('/clans/leave', async (req, res) => {
  if (!requireSupabase(res)) return;
  const user = await getUserFromBearer(req);
  if (!user) return res.status(401).json({ error: 'Invalid or missing access token.' });
  const membership = await clanMembership(user.id);
  if (!membership.clan) return res.status(400).json({ error: 'You are not in a clan.' });
  if (String(membership.role || '').toLowerCase() === 'leader') return res.status(400).json({ error: 'Leaders must transfer leadership or disband the clan first.' });
  const { error } = await supabaseAdmin.from('clan_members').delete().eq('account_id', user.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

app.post('/clans/disband', async (req, res) => {
  if (!requireSupabase(res)) return;
  const user = await getUserFromBearer(req);
  if (!user) return res.status(401).json({ error: 'Invalid or missing access token.' });
  const membership = await requireClanLeader(user, res);
  if (!membership) return;
  const { error } = await supabaseAdmin.from('clans').delete().eq('id', membership.clan.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

app.post('/clans/war/challenge', async (req, res) => {
  if (!requireSupabase(res)) return;
  const user = await getUserFromBearer(req);
  if (!user) return res.status(401).json({ error: 'Invalid or missing access token.' });
  const membership = await requireClanLeader(user, res);
  if (!membership) return;
  const targetName = cleanClanName(req.body.clan_name);
  const { data: targetClan } = await supabaseAdmin.from('clans').select('*').ilike('name', targetName).maybeSingle();
  if (!targetClan) return res.status(404).json({ error: 'Clan not found.' });
  if (targetClan.id === membership.clan.id) return res.status(400).json({ error: 'A clan cannot wage war against itself.' });
  const { count } = await supabaseAdmin
    .from('clan_wars')
    .select('id', { count: 'exact', head: true })
    .or(`attacking_clan_id.eq.${membership.clan.id},defending_clan_id.eq.${membership.clan.id}`)
    .in('status', ['pending', 'accepted', 'active']);
  if ((count || 0) >= MAX_ACTIVE_WARS) return res.status(400).json({ error: 'This clan has too many active wars.' });
  const { data: war, error } = await supabaseAdmin.from('clan_wars').insert({
    attacking_clan_id: membership.clan.id,
    defending_clan_id: targetClan.id,
    status: 'pending'
  }).select('*').single();
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true, war });
});

app.post('/clans/war/respond', async (req, res) => {
  if (!requireSupabase(res)) return;
  const user = await getUserFromBearer(req);
  if (!user) return res.status(401).json({ error: 'Invalid or missing access token.' });
  const membership = await requireClanLeader(user, res);
  if (!membership) return;
  const warId = String(req.body.war_id || '');
  const accepted = Boolean(req.body.accepted);
  const { data: war } = await supabaseAdmin.from('clan_wars').select('*').eq('id', warId).eq('defending_clan_id', membership.clan.id).maybeSingle();
  if (!war) return res.status(404).json({ error: 'War challenge not found.' });
  const status = accepted ? 'accepted' : 'cancelled';
  const { data: updated, error } = await supabaseAdmin.from('clan_wars').update({
    status,
    accepted_at: accepted ? new Date().toISOString() : null
  }).eq('id', war.id).select('*').single();
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true, war: updated });
});

app.post('/clans/battles/schedule', async (req, res) => {
  if (!requireSupabase(res)) return;
  const user = await getUserFromBearer(req);
  if (!user) return res.status(401).json({ error: 'Invalid or missing access token.' });
  const membership = await requireClanLeader(user, res);
  if (!membership) return;
  const warId = String(req.body.war_id || '');
  const start = new Date(String(req.body.scheduled_start_time || ''));
  if (Number.isNaN(start.getTime())) return res.status(400).json({ error: 'Valid battle time is required.' });
  if (start.getTime() < Date.now() + BATTLE_PREP_SECONDS * 1000) return res.status(400).json({ error: 'Battle must be scheduled at least 30 minutes in the future.' });
  const { data: war } = await supabaseAdmin.from('clan_wars').select('*').eq('id', warId).eq('status', 'accepted').maybeSingle();
  if (!war) return res.status(404).json({ error: 'Accepted war not found.' });
  if (![war.attacking_clan_id, war.defending_clan_id].includes(membership.clan.id)) return res.status(403).json({ error: 'Your clan is not in this war.' });
  const end = new Date(start.getTime() + BATTLE_DURATION_SECONDS * 1000);
  const { data: battle, error } = await supabaseAdmin.from('clan_battles').insert({
    war_id: war.id,
    clan_a_id: war.attacking_clan_id,
    clan_b_id: war.defending_clan_id,
    scheduled_start_time: start.toISOString(),
    end_time: end.toISOString(),
    created_by_leader_id: user.id
  }).select('*').single();
  if (error) return res.status(500).json({ error: error.message });
  await supabaseAdmin.from('clan_wars').update({ scheduled_battle_id: battle.id }).eq('id', war.id);
  res.json({ ok: true, battle });
});

app.post('/clans/battles/join', async (req, res) => {
  if (!requireSupabase(res)) return;
  const user = await getUserFromBearer(req);
  if (!user) return res.status(401).json({ error: 'Invalid or missing access token.' });
  const battleId = String(req.body.battle_id || '');
  const membership = await clanMembership(user.id);
  if (!membership.clan) return res.status(400).json({ error: 'You are not in a clan.' });
  const { data: battle } = await supabaseAdmin.from('clan_battles').select('*').eq('id', battleId).maybeSingle();
  if (!battle) return res.status(404).json({ error: 'Battle not found.' });
  if (![battle.clan_a_id, battle.clan_b_id].includes(membership.clan.id)) return res.status(403).json({ error: 'Only members of the battling clans can join.' });
  const { data: participant, error } = await supabaseAdmin.from('clan_battle_participants').upsert({
    battle_id: battle.id,
    account_id: user.id,
    clan_id: membership.clan.id
  }, { onConflict: 'battle_id,account_id' }).select('*').single();
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true, participant });
});

app.post('/clans/battles/record-kill', async (req, res) => {
  if (!requireSupabase(res)) return;
  const user = await getUserFromBearer(req);
  if (!user) return res.status(401).json({ error: 'Invalid or missing access token.' });
  const battleId = String(req.body.battle_id || '');
  const defeatedAccountId = String(req.body.defeated_account_id || '');
  const { data: killer } = await supabaseAdmin.from('clan_battle_participants').select('*').eq('battle_id', battleId).eq('account_id', user.id).maybeSingle();
  const { data: defeated } = await supabaseAdmin.from('clan_battle_participants').select('*').eq('battle_id', battleId).eq('account_id', defeatedAccountId).maybeSingle();
  if (!killer || !defeated) return res.status(400).json({ error: 'Both players must be battle participants.' });
  if (killer.clan_id === defeated.clan_id) return res.status(400).json({ error: 'Friendly kills do not score.' });
  const { data: battle } = await supabaseAdmin.from('clan_battles').select('*').eq('id', battleId).maybeSingle();
  if (!battle) return res.status(404).json({ error: 'Battle not found.' });
  await Promise.all([
    supabaseAdmin.from('clan_battle_participants').update({ kills: Number(killer.kills || 0) + 1 }).eq('id', killer.id),
    supabaseAdmin.from('clan_battle_participants').update({ deaths: Number(defeated.deaths || 0) + 1 }).eq('id', defeated.id)
  ]);
  const scoreColumn = killer.clan_id === battle.clan_a_id ? 'clan_a_score' : 'clan_b_score';
  const newScore = Number(battle[scoreColumn] || 0) + BATTLE_POINTS_PER_KILL;
  const { data: updated, error } = await supabaseAdmin.from('clan_battles').update({ [scoreColumn]: newScore }).eq('id', battle.id).select('*').single();
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true, battle: updated });
});

app.post('/clans/battles/complete', async (req, res) => {
  if (!requireSupabase(res)) return;
  const user = await getUserFromBearer(req);
  if (!user) return res.status(401).json({ error: 'Invalid or missing access token.' });
  const battleId = String(req.body.battle_id || '');
  const { data: battle } = await supabaseAdmin.from('clan_battles').select('*').eq('id', battleId).maybeSingle();
  if (!battle) return res.status(404).json({ error: 'Battle not found.' });
  const membership = await requireClanLeader(user, res);
  if (!membership) return;
  if (![battle.clan_a_id, battle.clan_b_id].includes(membership.clan.id)) return res.status(403).json({ error: 'Your clan is not in this battle.' });
  let winningClanId = null;
  if (Number(battle.clan_a_score || 0) > Number(battle.clan_b_score || 0)) winningClanId = battle.clan_a_id;
  if (Number(battle.clan_b_score || 0) > Number(battle.clan_a_score || 0)) winningClanId = battle.clan_b_id;
  const { data: updated, error } = await supabaseAdmin.from('clan_battles').update({
    status: 'completed',
    end_time: new Date().toISOString(),
    winning_clan_id: winningClanId
  }).eq('id', battle.id).select('*').single();
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true, battle: updated });
});

app.post('/clans/battles/claim-reward', async (req, res) => {
  if (!requireSupabase(res)) return;
  const user = await getUserFromBearer(req);
  if (!user) return res.status(401).json({ error: 'Invalid or missing access token.' });
  const battleId = String(req.body.battle_id || '');
  const [{ data: battle }, { data: participant }, { data: profile }] = await Promise.all([
    supabaseAdmin.from('clan_battles').select('*').eq('id', battleId).eq('status', 'completed').maybeSingle(),
    supabaseAdmin.from('clan_battle_participants').select('*').eq('battle_id', battleId).eq('account_id', user.id).maybeSingle(),
    supabaseAdmin.from('game_accounts').select('*').eq('id', user.id).maybeSingle()
  ]);
  if (!battle) return res.status(400).json({ error: 'Battle is not complete.' });
  if (!participant) return res.status(403).json({ error: 'Only participants can claim battle rewards.' });
  if (participant.reward_claimed) return res.status(400).json({ error: 'Battle reward already claimed.' });
  const won = participant.clan_id === battle.winning_clan_id;
  const xp = won ? WINNER_XP_REWARD : LOSER_XP_REWARD;
  const gold = won ? WINNER_GOLD_REWARD : LOSER_GOLD_REWARD;
  const { data: updatedProfile, error: rewardError } = await supabaseAdmin.from('game_accounts').update({
    xp: Number(profile?.xp || 0) + xp,
    gold: Number(profile?.gold || 0) + gold,
    updated_at: new Date().toISOString()
  }).eq('id', user.id).select('*').single();
  if (rewardError) return res.status(500).json({ error: rewardError.message });
  await supabaseAdmin.from('clan_battle_participants').update({ reward_claimed: true }).eq('id', participant.id);
  res.json({ ok: true, xp, gold, account: publicAccount(updatedProfile) });
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
