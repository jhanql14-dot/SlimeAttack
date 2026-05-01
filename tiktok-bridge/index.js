const { WebcastPushConnection } = require('tiktok-live-connector');
const WebSocket = require('ws');

// Crear servidor WebSocket para el juego
const wss = new WebSocket.Server({ port: 8080 });
let gameSocket = null;

wss.on('connection', (ws) => {
    gameSocket = ws;
    console.log("¡Juego conectado!");
});

// Conectar a TikTok (reemplaza con tu usuario cuando estés en vivo)
let tiktokUsername = "cuongcotruon9";
let tiktokLiveConnection = new WebcastPushConnection(tiktokUsername);

tiktokLiveConnection.connect().then(state => {
    console.info(`Conectado al Live de ${state.roomId}`);
}).catch(err => {
    console.error('Error al conectar', err);
});

// --- ESCUCHAR REGALOS (Rosas, etc.) ---
tiktokLiveConnection.on('gift', (data) => {
    console.log(`🎁 Regalo: ${data.giftName} x${data.repeatCount}`);
    if (gameSocket) {
        gameSocket.send(JSON.stringify({
            type: 'donacion',
            nombre: data.giftName,
            cantidad: data.repeatCount,
            usuario: data.uniqueId
        }));
    }
});

// --- ESCUCHAR TAP TAPS (Likes) ---
tiktokLiveConnection.on('like', (data) => {
    console.log(`❤️ Taps recibidos: ${data.likeCount}`);
    if (gameSocket) {
        gameSocket.send(JSON.stringify({
            type: 'taptap',
            cantidad: data.likeCount
        }));
    }
});

// --- ESCUCHAR CUANDO ALGUIEN SE UNE AL LIVE ---
tiktokLiveConnection.on('member', (data) => {
    console.log(`👋 Se unió: ${data.uniqueId}`);
    if (gameSocket) {
        // Enviar evento 'join' → Godot hará caer un slime
        gameSocket.send(JSON.stringify({
            type: 'join',
            usuario: data.uniqueId
        }));
    }
});

// Escuchar Chat
tiktokLiveConnection.on('chat', (data) => {
    if (gameSocket) {
        gameSocket.send(JSON.stringify({ type: 'chat', user: data.uniqueId, text: data.comment }));
    }
});

// Simular regalo presionando ENTER en la terminal
process.stdin.on('data', (data) => {
    const input = data.toString().trim();
    if (gameSocket) {
        console.log("Enviando regalo de prueba a Godot...");
        gameSocket.send(JSON.stringify({
            type: 'donacion',
            nombre: 'Rosa',
            cantidad: 1,
            usuario: 'Bot_' + Math.floor(Math.random() * 1000)
        }));
    } else {
        console.log("Godot aún no está conectado por WebSocket");
    }
});