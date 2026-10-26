import 'reflect-metadata';
import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { io, Socket } from 'socket.io-client';
import { loadConfig } from '../src/config';
import { createApp } from '../src/main';

// Parcours complet de la v0.1, avec SQLite en mémoire et le moteur de traduction factice.

let app: INestApplication;
let baseUrl: string;
const http = () => request(app.getHttpServer());

async function signUp(phone: string) {
  const req = await http().post('/auth/otp/request').send({ phone }).expect(200);
  assert.match(req.body.devCode, /^\d{6}$/);
  const res = await http().post('/auth/otp/verify').send({ phone, code: req.body.devCode }).expect(200);
  return { token: res.body.token as string, id: res.body.user.id as string, isNew: res.body.isNew as boolean };
}

const auth = (token: string) => ({ Authorization: `Bearer ${token}` });

function connect(token: string): Promise<Socket> {
  return new Promise((resolve, reject) => {
    const s = io(baseUrl, { auth: { token }, transports: ['websocket'], forceNew: true });
    s.once('ready', () => resolve(s));
    s.once('connect_error', reject);
  });
}

describe('Lango v0.1', () => {
  let awa: { token: string; id: string };
  let chen: { token: string; id: string };
  let kofi: { token: string; id: string };
  const sockets: Socket[] = [];

  before(async () => {
    app = await createApp(
      loadConfig({ sqlitePath: ':memory:', translationProvider: 'mock', devOtp: true, dailyContactRequestLimit: 3 }),
    );
    app.useLogger(false);
    await app.listen(0);
    baseUrl = await app.getUrl();
  });

  after(async () => {
    sockets.forEach((s) => s.disconnect());
    await app.close();
  });

  it('expose la santé du service et les 22 langues', async () => {
    const health = await http().get('/health').expect(200);
    assert.equal(health.body.status, 'ok');
    const langs = await http().get('/languages').expect(200);
    assert.equal(langs.body.length, 22);
    assert.ok(langs.body.some((l: { code: string }) => l.code === 'mos'));
  });

  it('refuse un numéro mal formé et un mauvais code', async () => {
    await http().post('/auth/otp/request').send({ phone: '70000000' }).expect(400);
    await http().post('/auth/otp/request').send({ phone: '+22670000099' }).expect(200);
    await http().post('/auth/otp/verify').send({ phone: '+22670000099', code: '000000' }).expect((r) => {
      assert.ok([400, 401].includes(r.status));
    });
  });

  it('inscrit trois personnes et complète leurs profils', async () => {
    awa = await signUp('+22670000001');
    chen = await signUp('+8613800000002');
    kofi = await signUp('+233200000003');
    assert.notEqual(awa.id, chen.id);

    await http().patch('/me').set(auth(awa.token)).send({
      name: 'Awa', language: 'fr', country: 'BF', profession: 'Commerçante', interests: ['agriculture'], purposes: ['commerce'],
      visibility: 'everyone',
    }).expect(200);
    await http().patch('/me').set(auth(chen.token)).send({
      name: 'Chen', language: 'zh', country: 'CN', profession: 'Cultivateur de riz', interests: ['agriculture', 'irrigation'],
      bio: '我种水稻', purposes: ['savoir', 'commerce'], visibility: 'everyone',
    }).expect(200);
    await http().patch('/me').set(auth(kofi.token)).send({ name: 'Kofi', language: 'en', visibility: 'hidden' }).expect(200);

    // Langue inconnue refusée
    await http().patch('/me').set(auth(awa.token)).send({ language: 'xx' }).expect(400);
    // Le téléphone ne peut pas être modifié par le profil
    await http().patch('/me').set(auth(awa.token)).send({ phone: '+1000' }).expect(400);
  });

  it("protège l'espace rencontres des mineurs", async () => {
    const year = new Date().getFullYear();
    await http().patch('/me').set(auth(kofi.token)).send({ birthYear: year - 15, datingEnabled: true }).expect(403);
    await http().get('/discover?purpose=rencontre').set(auth(awa.token)).expect(403);
  });

  it('découvre des personnes par intérêt, avec la présentation traduite', async () => {
    const res = await http().get('/discover?interest=agriculture').set(auth(awa.token)).expect(200);
    assert.equal(res.body.length, 1);
    assert.equal(res.body[0].name, 'Chen');
    assert.equal(res.body[0].bioTranslated, '[fr] 我种水稻');
    assert.equal(res.body[0].phone, undefined, 'le numéro ne doit jamais être exposé');

    // Kofi a un profil caché : invisible
    const hidden = await http().get('/discover?q=kofi').set(auth(awa.token)).expect(200);
    assert.equal(hidden.body.length, 0);
    await http().get(`/users/${kofi.id}`).set(auth(awa.token)).expect(404);
  });

  it("n'autorise pas les messages sans demande de contact acceptée", async () => {
    await http().post(`/conversations/${chen.id}/messages`).set(auth(awa.token)).send({ text: 'Bonjour' }).expect(403);
  });

  it('envoie, reçoit et accepte une demande de contact', async () => {
    const created = await http()
      .post('/contacts/requests')
      .set(auth(awa.token))
      .send({ toUserId: chen.id, intro: 'Je cherche des techniques de riziculture' })
      .expect(201);
    await http().post('/contacts/requests').set(auth(awa.token)).send({ toUserId: chen.id }).expect(409);

    const incoming = await http().get('/contacts/requests').set(auth(chen.token)).expect(200);
    assert.equal(incoming.body.length, 1);
    assert.equal(incoming.body[0].introTranslated, '[zh] Je cherche des techniques de riziculture');

    await http().post(`/contacts/requests/${created.body.id}/accept`).set(auth(chen.token)).expect(200);
    const contacts = await http().get('/contacts').set(auth(awa.token)).expect(200);
    assert.deepEqual(contacts.body.map((c: { name: string }) => c.name), ['Chen']);
  });

  it('traduit les messages en temps réel dans la langue de chacun', async () => {
    const sa = await connect(awa.token);
    const sc = await connect(chen.token);
    sockets.push(sa, sc);

    const received = new Promise<any>((resolve) => sc.once('message:new', resolve));
    const ack = await sa.timeout(5000).emitWithAck('message:send', { to: chen.id, text: 'Bonjour Chen !' });
    assert.equal(ack.ok, true);
    assert.equal(ack.message.text, 'Bonjour Chen !');

    const msg = await received;
    assert.equal(msg.text, '[zh] Bonjour Chen !');
    assert.equal(msg.originalText, 'Bonjour Chen !');
    assert.equal(msg.translated, true);

    const back = new Promise<any>((resolve) => sa.once('message:new', resolve));
    await sc.timeout(5000).emitWithAck('message:send', { to: awa.id, text: '你好 Awa' });
    assert.equal((await back).text, '[fr] 你好 Awa');
  });

  it('refuse les envois temps réel invalides ou non autorisés', async () => {
    const sk = await connect(kofi.token);
    sockets.push(sk);
    const res = await sk.timeout(5000).emitWithAck('message:send', { to: awa.id, text: 'Hello' });
    assert.equal(res.ok, false);
  });

  it("rejette une connexion temps réel sans jeton valide", async () => {
    await assert.rejects(
      new Promise((resolve, reject) => {
        const s = io(baseUrl, { auth: { token: 'faux' }, transports: ['websocket'], forceNew: true });
        s.once('ready', () => resolve(s));
        s.once('disconnect', () => reject(new Error('déconnecté')));
        setTimeout(() => reject(new Error('délai')), 3000);
      }),
    );
  });

  it("signale les messages qui ressemblent à une arnaque, au destinataire seulement", async () => {
    const sent = await http()
      .post(`/conversations/${awa.id}/messages`)
      .set(auth(chen.token))
      .send({ text: 'Envoie moi de l argent par Western Union pour les frais de douane' })
      .expect(201);
    assert.equal(sent.body.warning, null);

    const history = await http().get(`/conversations/${chen.id}/messages`).set(auth(awa.token)).expect(200);
    const last = history.body.at(-1);
    assert.equal(last.warning, 'possible_scam');
  });

  it('liste les conversations avec les non-lus, puis les marque comme lus', async () => {
    const convs = await http().get('/conversations').set(auth(awa.token)).expect(200);
    assert.equal(convs.body.length, 1);
    assert.equal(convs.body[0].with.name, 'Chen');
    assert.equal(convs.body[0].unread, 2);

    const read = await http().post(`/conversations/${chen.id}/read`).set(auth(awa.token)).expect(200);
    assert.equal(read.body.updated, 2);
    const after = await http().get('/conversations').set(auth(awa.token)).expect(200);
    assert.equal(after.body[0].unread, 0);
  });

  it('retraduit l’historique si la personne change de langue', async () => {
    await http().patch('/me').set(auth(awa.token)).send({ language: 'en' }).expect(200);
    const history = await http().get(`/conversations/${chen.id}/messages`).set(auth(awa.token)).expect(200);
    const fromChen = history.body.find((m: any) => m.senderId === chen.id);
    assert.equal(fromChen.text, '[en] 你好 Awa');
  });

  it('bloque une personne : plus aucun message possible', async () => {
    await http().post(`/contacts/block/${awa.id}`).set(auth(chen.token)).expect(204);
    await http().post(`/conversations/${chen.id}/messages`).set(auth(awa.token)).send({ text: 'Hello?' }).expect(403);
    await http().get(`/users/${chen.id}`).set(auth(awa.token)).expect(404);
  });

  it('limite le nombre de demandes de contact par jour', async () => {
    const extra = [];
    for (let i = 0; i < 4; i++) {
      const u = await signUp(`+2547000000${10 + i}`);
      await http().patch('/me').set(auth(u.token)).send({ name: `Test${i}`, visibility: 'everyone' }).expect(200);
      extra.push(u);
    }
    // Kofi a déjà 0 demande ; la limite de test est 3
    for (let i = 0; i < 3; i++) {
      await http().post('/contacts/requests').set(auth(kofi.token)).send({ toUserId: extra[i].id }).expect(201);
    }
    await http().post('/contacts/requests').set(auth(kofi.token)).send({ toUserId: extra[3].id }).expect(429);
  });
});
